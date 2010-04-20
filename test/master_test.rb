require File.join(File.dirname(__FILE__), 'test_helper')

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
      report_file = File.join(Dir.tmpdir, 'hydra_heuristics.yml')
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
          :directory => File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')),
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
      local = File.join(Dir.tmpdir, 'hydra', 'local')
      remote = File.join(Dir.tmpdir, 'hydra', 'remote')
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
end
