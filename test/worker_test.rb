require File.join(File.dirname(__FILE__), 'test_helper')

TARGET = File.join(Dir.tmpdir, 'hydra_test.txt')
TESTFILE = File.join(File.dirname(__FILE__), 'fixtures', 'write_file.rb')

class WorkerTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      FileUtils.rm_f(TARGET)
    end

    teardown do
      FileUtils.rm_f(TARGET)
    end

    should "run a test" do
      @pipe = Hydra::Pipe.new
      @child = Process.fork do
        @pipe.identify_as_child
        Hydra::Worker.new(@pipe, 1)
        @pipe.close
      end
      @pipe.identify_as_parent
      assert @pipe.gets.is_a?(Hydra::Messages::Worker::RequestFile)
      @pipe.write(Hydra::Messages::Worker::RunFile.new(:file => TESTFILE))

      response = @pipe.gets
      assert response.is_a?(Hydra::Messages::Worker::Results)

      @pipe.write(Hydra::Messages::Worker::Shutdown.new)

      assert File.exists?(TARGET)
      assert_equal "HYDRA", File.read(TARGET)

      @pipe.close
      Process.wait(@child)
    end
  end
end
