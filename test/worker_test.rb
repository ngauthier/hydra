require File.join(File.dirname(__FILE__), 'test_helper')

class WorkerTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      FileUtils.rm_f(target_file)
    end

    teardown do
      FileUtils.rm_f(target_file)
    end

    # run the worker in the foreground and the requests in the background
    should "run a test in the foreground" do
      num_runners = 4
      pipe = Hydra::Pipe.new
      child = Process.fork do
        request_a_file_and_verify_completion(pipe, num_runners)
      end
      run_the_worker(pipe, num_runners)
      Process.wait(child)
    end

    # inverse of the above test to run the worker in the background
    should "run a test in the background" do
      num_runners = 4
      pipe = Hydra::Pipe.new
      child = Process.fork do
        run_the_worker(pipe, num_runners)
      end
      request_a_file_and_verify_completion(pipe, num_runners)
      Process.wait(child)
    end
  end

  module WorkerTestHelper
    def run_the_worker(pipe, num_runners)
      pipe.identify_as_child
      Hydra::Worker.new({:io => pipe, :runners => num_runners})
    end

    def request_a_file_and_verify_completion(pipe, num_runners)
      pipe.identify_as_parent
      pipe.gets # grab the WorkerBegin
      num_runners.times do
        response = pipe.gets # grab the RequestFile
        assert response.is_a?(Hydra::Messages::Worker::RequestFile), "Expected RequestFile but got #{response.class.to_s}"
      end
      pipe.write(Hydra::Messages::Master::RunFile.new(:file => test_file))

      assert pipe.gets.is_a?(Hydra::Messages::Worker::Results)

      pipe.write(Hydra::Messages::Master::Shutdown.new)

      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end
  end
  include WorkerTestHelper
end
