require File.join(File.dirname(__FILE__), 'test_helper')

TARGET = File.join(Dir.tmpdir, 'hydra_test.txt')
TESTFILE = File.join(File.dirname(__FILE__), 'fixtures', 'write_file.rb')

class RunnerTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      FileUtils.rm_f(TARGET)
    end

    teardown do
      FileUtils.rm_f(TARGET)
    end


    should "run a test" do
      # flip it around to the parent is in the fork, this gives
      # us more direct control over the runner and proper test
      # coverage output
      @pipe = Hydra::Pipe.new
      @parent = Process.fork do
        request_a_file_and_verify_completion(@pipe)
      end
      run_the_runner(@pipe)
      Process.wait(@parent)
    end

    # this flips the above test, so that the main process runs a bit of the parent
    # code, but only with minimal assertion
    should "be able to tell a runner to run a test" do
      @pipe = Hydra::Pipe.new
      @child = Process.fork do
        run_the_runner(@pipe)
      end
      request_a_file_and_verify_completion(@pipe)
      Process.wait(@child)
    end
  end

  module RunnerTestHelper
    def request_a_file_and_verify_completion(pipe)
      pipe.identify_as_parent

      # make sure it asks for a file, then give it one
      assert pipe.gets.is_a?(Hydra::Messages::Runner::RequestFile)
      pipe.write(Hydra::Messages::Runner::RunFile.new(:file => TESTFILE))
      
      # grab its response. This makes us wait for it to finish
      response = pipe.gets
      
      # tell it to shut down
      pipe.write(Hydra::Messages::Runner::Shutdown.new)
      
      # ensure it ran
      assert File.exists?(TARGET)
      assert_equal "HYDRA", File.read(TARGET)

      pipe.close
    end

    def run_the_runner(pipe)
      pipe.identify_as_child
      Hydra::Runner.new(pipe)
      pipe.close
    end
  end
  include RunnerTestHelper
end

