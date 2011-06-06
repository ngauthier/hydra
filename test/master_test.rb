require File.join(File.dirname(__FILE__), 'test_helper')
require File.join(File.dirname(__FILE__), 'fixtures', 'runner_listeners')
require File.join(File.dirname(__FILE__), 'fixtures', 'master_listeners')

class MasterTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      # avoid having other tests interfering with us
      sleep(0.2)
      FileUtils.rm_f(target_file)
    end

    teardown do
      FileUtils.rm_f(target_file)
    end

    should "run a test" do
      Hydra::Master.new(
        :files => [test_file]
      )
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end

    # this test simulates what happens when we have 2 tests with the same
    # class name but with different parent classes.  This can happen when 
    # we have a functional and an integration test class with the same name.
    should "run even with a test that will not require" do
      class FileOutputListener < Hydra::Listener::Abstract
        attr_accessor :output
        def initialize(&block)
          self.output = {}
        end

        def file_end(file, output)
          self.output[file] = output
        end
      end

      listener =  FileOutputListener.new
      sync_test = File.join(File.dirname(__FILE__), 'fixtures', 'sync_test.rb')
      Hydra::Master.new(
        # we want the actual test to run last to make sure the runner can still run tests
        :files => [sync_test, conflicting_test_file, test_file],
        :autosort => false,
        :listeners => [listener]
      )
      assert_match /superclass mismatch for class SyncTest/, listener.output[conflicting_test_file]
      assert_match conflicting_test_file, listener.output[conflicting_test_file]
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end

    should "run a spec with pending examples" do
      progress_bar = Hydra::Listener::ProgressBar.new(StringIO.new)
      Hydra::Master.new(
        :files => [rspec_file_with_pending],
        :listeners => [progress_bar]
      )
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
      assert_equal false, progress_bar.instance_variable_get('@errors')
    end

    should "generate a report" do
      Hydra::Master.new(:files => [test_file])
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
      report_file = File.join(Dir.consistent_tmpdir, 'hydra_heuristics.yml')
      assert File.exists?(report_file)
      assert report = YAML.load_file(report_file)
      assert_not_nil report[test_file]
    end

    should "run a test 6 times on 1 worker with 2 runners" do
      Hydra::Master.new(
        :files => [test_file]*6,
        :workers => [ { :type => :local, :runners => 2 } ]
      )
      assert File.exists?(target_file)
      assert_equal "HYDRA"*6, File.read(target_file)
    end

    # The test being run sleeps for 5 seconds. So, if this was run in
    # series, it would take at least 50 seconds. This test ensures that
    # in runs in less than that amount of time. Since there are 10
    # runners to run the file 10 times, it should only take 5-10 seconds
    # based on overhead.
    should "run a slow test 10 times on 1 worker with 10 runners quickly" do
      start = Time.now
      Hydra::Master.new(
        :files => [File.join(File.dirname(__FILE__), 'fixtures', 'slow.rb')]*10,
        :workers => [
          { :type => :local, :runners => 10 }
        ]
      )
      finish = Time.now
      assert (finish-start) < 30, "took #{finish-start} seconds"
    end

    should "run a slow test 10 times on 2 workers with 5 runners each quickly" do
      start = Time.now
      Hydra::Master.new(
        :files => [File.join(File.dirname(__FILE__), 'fixtures', 'slow.rb')]*10,
        :workers => [
          { :type => :local, :runners => 5 },
          { :type => :local, :runners => 5 }
        ]
      )
      finish = Time.now
      assert (finish-start) < 15, "took #{finish-start} seconds"
    end

    should "run a test via ssh" do
      Hydra::Master.new(
        :files => [test_file],
        :workers => [{
          :type => :ssh,
          :connect => 'localhost',
          :directory => remote_dir_path,
          :runners => 1
        }]
      )
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end

    should "run a test with config from a yaml file" do
      Hydra::Master.new(
        :files => [test_file],
        :config => File.join(File.dirname(__FILE__), 'fixtures', 'config.yml')
      )
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end

    should "synchronize a test file over ssh with rsync" do
      local = File.join(Dir.consistent_tmpdir, 'hydra', 'local')
      remote = File.join(Dir.consistent_tmpdir, 'hydra', 'remote')
      sync_test = File.join(File.dirname(__FILE__), 'fixtures', 'sync_test.rb')
      [local, remote].each{|f| FileUtils.rm_rf f; FileUtils.mkdir_p f}

      # setup the folders:
      # local:
      #   - test_a
      #   - test_c
      # remote:
      #   - test_b
      #
      # add test_c to exludes
      FileUtils.cp(sync_test, File.join(local, 'test_a.rb'))
      FileUtils.cp(sync_test, File.join(local, 'test_c.rb'))
      FileUtils.cp(sync_test, File.join(remote, 'test_b.rb'))

      # ensure a is not on remote
      assert !File.exists?(File.join(remote, 'test_a.rb')), "A should not be on remote"
      # ensure c is not on remote
      assert !File.exists?(File.join(remote, 'test_c.rb')), "C should not be on remote"
      # ensure b is on remote
      assert File.exists?(File.join(remote, 'test_b.rb')),  "B should be on remote"

      Hydra::Master.new(
        :files => ['test_a.rb'],
        :workers => [{
          :type => :ssh,
          :connect => 'localhost',
          :directory => remote,
          :runners => 1
        }],
        :sync => {
          :directory => local,
          :exclude => ['test_c.rb']
        }
      )
      # ensure a is copied
      assert File.exists?(File.join(remote, 'test_a.rb')), "A was not copied"
      # ensure c is not copied
      assert !File.exists?(File.join(remote, 'test_c.rb')), "C was copied, should be excluded"
      # ensure b is deleted
      assert !File.exists?(File.join(remote, 'test_b.rb')), "B was not deleted"
    end
  end

  context "with a runner_end event" do
    setup do
      # avoid having other tests interfering with us
      sleep(0.2)
      FileUtils.rm_f(target_file)
      FileUtils.rm_f(alternate_target_file)

      @runner_began_flag = File.expand_path(File.join(Dir.consistent_tmpdir, 'runner_began_flag')) #used to know when the worker is ready
      FileUtils.rm_f(@runner_began_flag)

      @runner_listener = 'HydraExtension::RunnerListener::RunnerEndTest.new' # runner_end method that creates alternate_target_file
      @master_listener = HydraExtension::Listener::WorkerBeganFlag.new  #used to know when the runner is up
    end

    teardown do
      FileUtils.rm_f(target_file)
      FileUtils.rm_f(alternate_target_file)
    end

    context "running a local worker" do
      should "run runner_end on successful termination" do
        @pid = Process.fork do
            Hydra::Master.new(
              :files => [test_file] * 6,
              :autosort => false,
              :listeners => [@master_listener],
              :runner_listeners => [@runner_listener],
              :verbose => false
            )
          end
        Process.waitpid @pid

        assert_file_exists alternate_target_file
      end

      should "run runner_end after interruption signal" do
        add_infinite_worker_begin_to @master_listener

        capture_stderr do # redirect stderr
          @pid = Process.fork do
            Hydra::Master.new(
              :files => [test_file],
              :autosort => false,
              :listeners => [@master_listener],
              :runner_listeners => [@runner_listener],
              :verbose => false
            )
          end
        end
        wait_for_runner_to_begin

        Process.kill 'SIGINT', @pid
        Process.waitpid @pid

        assert_file_exists alternate_target_file
      end
    end

    context "running a remote worker" do
      setup do
        copy_worker_init_file # this method has a protection to avoid erasing an existing worker_init_file
      end

      teardown do
        FileUtils.rm_f(@remote_init_file) unless @protect_init_file
      end

      should "run runner_end on successful termination" do
        capture_stderr do # redirect stderr
          @pid = Process.fork do
            Hydra::Master.new(
              :files => [test_file],
              :autosort => false,
              :listeners => [@master_listener],
              :runner_listeners => [@runner_listener],
              :workers => [{
                :type => :ssh,
                :connect => 'localhost',
                :directory => remote_dir_path,
                :runners => 1
              }],
              :verbose => false
            )
          end
        end
        Process.waitpid @pid

        assert_file_exists alternate_target_file
      end
    end
  end

  context "redirecting runner's output and errors" do
    setup do
      # avoid having other tests interfering with us
      sleep(0.2)
      FileUtils.rm_f(target_file)
      FileUtils.rm_f(runner_log_file)
      FileUtils.rm_f("#{remote_dir_path}/#{runner_log_file}")
    end

    teardown do
      FileUtils.rm_f(target_file)
      FileUtils.rm_f(runner_log_file)
      FileUtils.rm_f("#{remote_dir_path}/#{runner_log_file}")
    end

    should "create a runner log file when usign local worker and passing a log file name" do
      @pid = Process.fork do
        Hydra::Master.new(
              :files => [test_file],
              :runner_log_file => runner_log_file,
              :verbose => false
            )
      end
      Process.waitpid @pid

      assert_file_exists target_file # ensure the test was successfully ran
      assert_file_exists runner_log_file
    end

    should "create a runner log file when usign remote worker and passing a log file name" do
      @pid = Process.fork do
        Hydra::Master.new(
              :files => [test_file],
              :workers => [{
                :type => :ssh,
                :connect => 'localhost',
                :directory => remote_dir_path,
                :runners => 1
              }],
              :verbose => false,
              :runner_log_file => runner_log_file
            )
      end
      Process.waitpid @pid

      assert_file_exists target_file # ensure the test was successfully ran
      assert_file_exists "#{remote_dir_path}/#{runner_log_file}"
    end

    should "create the default runner log file when passing an incorrect log file path" do
      default_log_file = "#{remote_dir_path}/#{Hydra::Runner::DEFAULT_LOG_FILE}" # hydra-runner.log"
      FileUtils.rm_f(default_log_file)

      @pid = Process.fork do
        Hydra::Master.new(
              :files => [test_file],
              :workers => [{
                :type => :ssh,
                :connect => 'localhost',
                :directory => remote_dir_path,
                :runners => 1
              }],
              :verbose => false,
              :runner_log_file => 'invalid-dir/#{runner_log_file}'
            )
      end
      Process.waitpid @pid

      assert_file_exists target_file # ensure the test was successfully ran
      assert_file_exists default_log_file #default log file
      assert !File.exists?( "#{remote_dir_path}/#{runner_log_file}" )

      FileUtils.rm_f(default_log_file)
    end
  end

  private

  def runner_log_file
    "my-hydra-runner.log"
  end

  def add_infinite_worker_begin_to master_listener
    class << master_listener
      def worker_begin( worker )
        super
        sleep 1 while true #ensure the process doesn't finish before killing it
      end
    end
  end

  #  this requires that a worker_begin listener creates a file named worker_began_flag in tmp directory
  def wait_for_runner_to_begin
    assert_file_exists @runner_began_flag
  end

  # with a protection to avoid erasing something important in lib
  def copy_worker_init_file
    @remote_init_file = "#{remote_dir_path}/#{File.basename( hydra_worker_init_file )}"
    if File.exists?( @remote_init_file )
      $stderr.puts "\nWARNING!!!: #{@remote_init_file} exits and this test needs to create a new file here. Make sure there is nothing inportant in that file and remove it before running this test\n\n"
      @protect_init_file = true
      exit
    end
    # copy the hydra_worker_init to the correct location
    FileUtils.cp(hydra_worker_init_file, remote_dir_path)
  end
end
