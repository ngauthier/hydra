require File.join(File.dirname(__FILE__), 'test_helper')

class RunnerTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      sleep(0.2)
      FileUtils.rm_f(target_file)
      FileUtils.rm_f(alternate_target_file)
    end

    teardown do
      FileUtils.rm_f(target_file)
      FileUtils.rm_f(alternate_target_file)
    end


    should "run a test in the foreground" do
      # flip it around to the parent is in the fork, this gives
      # us more direct control over the runner and proper test
      # coverage output
      pipe = Hydra::Pipe.new
      parent = Process.fork do
        request_a_file_and_verify_completion(pipe, test_file)
      end
      run_the_runner(pipe)
      Process.wait(parent)
    end

    # this flips the above test, so that the main process runs a bit of the parent
    # code, but only with minimal assertion
    should "run a test in the background" do
      pipe = Hydra::Pipe.new
      child = Process.fork do
        run_the_runner(pipe)
      end
      request_a_file_and_verify_completion(pipe, test_file)
      Process.wait(child)
    end

    should "run a js lint file and find errors" do
      runner = Hydra::Runner.new(:io => File.new('/dev/null', 'w'))
      results = runner.run_file(javascript_file)
      assert results =~ /Missing semicolon/, results
    end

    should "run a json data file and find errors" do
      runner = Hydra::Runner.new(:io => File.new('/dev/null', 'w'))
      results = runner.run_file(json_file)
      assert results =~ /trailing comma/, results
    end

    should "run two rspec tests" do
      runner = Hydra::Runner.new(:io => File.new('/dev/null', 'w'))
      runner.run_file(rspec_file)
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)

      FileUtils.rm_f(target_file)
      
      runner.run_file(alternate_rspec_file)
      assert File.exists?(alternate_target_file)
      assert_equal "HYDRA", File.read(alternate_target_file)
      assert !File.exists?(target_file)
    end

    should "run rspec tests with pending examples" do
      runner = Hydra::Runner.new(:io => File.new('/dev/null', 'w'))
      assert File.exists?(rspec_file_with_pending)

      runner.run_file(rspec_file_with_pending)

      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)

      FileUtils.rm_f(target_file)
    end

    should "run two cucumber tests" do
      # because of all the crap cucumber pulls in
      # we run this in a fork to not contaminate
      # the main test environment
      pid = Process.fork do
        puts "THE FOLLOWING WARNINGS CAN BE IGNORED"
        puts "It is caused by Cucumber loading all rb files near its features"

        runner = Hydra::Runner.new(:io => File.new('/dev/null', 'w'))
        runner.run_file(cucumber_feature_file)
        assert File.exists?(target_file)
        assert_equal "HYDRA", File.read(target_file)
        
        FileUtils.rm_f(target_file)
        
        runner.run_file(alternate_cucumber_feature_file)
        assert File.exists?(alternate_target_file)
        assert_equal "HYDRA", File.read(alternate_target_file)
        assert !File.exists?(target_file)
        
        puts "END IGNORABLE OUTPUT"
      end
      Process.wait pid
    end

    should "be able to run a runner over ssh" do
      ssh = Hydra::SSH.new(
        'localhost', 
        File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')),
        "ruby -e \"require 'rubygems'; require 'hydra'; Hydra::Runner.new(:io => Hydra::Stdio.new, :verbose => true);\""
      )
      assert ssh.gets.is_a?(Hydra::Messages::Runner::RequestFile)
      ssh.write(Hydra::Messages::Worker::RunFile.new(:file => test_file))
      
      # grab its response. This makes us wait for it to finish
      echo = ssh.gets # get the ssh echo
      response = ssh.gets

      assert_equal Hydra::Messages::Runner::Results, response.class
      
      # tell it to shut down
      ssh.write(Hydra::Messages::Worker::Shutdown.new)

      ssh.close
      
      # ensure it ran
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end
  end

  module RunnerTestHelper
    def request_a_file_and_verify_completion(pipe, file)
      pipe.identify_as_parent

      # make sure it asks for a file, then give it one
      assert pipe.gets.is_a?(Hydra::Messages::Runner::RequestFile)
      pipe.write(Hydra::Messages::Worker::RunFile.new(:file => file))
      
      # grab its response. This makes us wait for it to finish
      response = pipe.gets
      puts response.output
      
      # tell it to shut down
      pipe.write(Hydra::Messages::Worker::Shutdown.new)
      
      # ensure it ran
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end

    def run_the_runner(pipe)
      pipe.identify_as_child
      Hydra::Runner.new(:io => pipe)
    end
  end
  include RunnerTestHelper
end

