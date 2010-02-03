require File.join(File.dirname(__FILE__), 'test_helper')

class RunnerTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      FileUtils.rm_f(target_file)
    end

    teardown do
      FileUtils.rm_f(target_file)
    end


    should "run a test in the foreground" do
      # flip it around to the parent is in the fork, this gives
      # us more direct control over the runner and proper test
      # coverage output
      pipe = Hydra::Pipe.new
      parent = Process.fork do
        request_a_file_and_verify_completion(pipe)
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
      request_a_file_and_verify_completion(pipe)
      Process.wait(child)
    end

    should "be able to run a runner over ssh" do
      ssh = Hydra::SSH.new(
        'localhost', 
        File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')),
        "ruby -e \"require 'rubygems'; require 'hydra'; Hydra::Runner.new(:io => Hydra::Stdio.new);\""
      )
      assert ssh.gets.is_a?(Hydra::Messages::Runner::RequestFile)
      ssh.write(Hydra::Messages::Worker::RunFile.new(:file => test_file))
      
      # grab its response. This makes us wait for it to finish
      response = ssh.gets
      
      # tell it to shut down
      ssh.write(Hydra::Messages::Worker::Shutdown.new)
      
      # ensure it ran
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end
  end

  module RunnerTestHelper
    def request_a_file_and_verify_completion(pipe)
      pipe.identify_as_parent

      # make sure it asks for a file, then give it one
      assert pipe.gets.is_a?(Hydra::Messages::Runner::RequestFile)
      pipe.write(Hydra::Messages::Worker::RunFile.new(:file => test_file))
      
      # grab its response. This makes us wait for it to finish
      response = pipe.gets
      
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

