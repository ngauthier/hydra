require File.join(File.dirname(__FILE__), 'helper')

class TestRunner < Test::Unit::TestCase
  context "a test runner" do
    setup do
      @pipe = Hydra::Pipe.new
      @child = Process.fork do
        @pipe.identify_as_child
        Hydra::Runner.new(@pipe)
      end
      @pipe.identify_as_parent
    end
    teardown do
      @pipe.close
      Process.wait(@child)
    end
    should "boot and run a file and shut down" do
      assert @pipe.gets.is_a?(Hydra::Messages::Runner::RequestFile)

      file = File.join(File.dirname(__FILE__), 'sample_tests', 'assert_true.rb')
      @pipe.write(Hydra::Messages::Runner::RunFile.new(:file => file))
      response = @pipe.gets
      assert response.is_a?(Hydra::Messages::Runner::Results)
      assert response.output =~ /Finished/
      assert_equal file, response.file
      @pipe.write(Hydra::Messages::Runner::Shutdown.new)
    end

    should "run a test" do
      target = File.join(Dir.tmpdir, 'hydra_test.txt')
      FileUtils.rm_f(target)
      assert !File.exists?(target)
      file = File.join(File.dirname(__FILE__), 'sample_tests', 'write_file.rb')
      assert @pipe.gets.is_a?(Hydra::Messages::Runner::RequestFile)
      @pipe.write(Hydra::Messages::Runner::RunFile.new(:file => file))
      response = @pipe.gets
      @pipe.write(Hydra::Messages::Runner::Shutdown.new)
      assert File.exists?(target)
      assert_equal "HYDRA", File.read(target)
    end
  end
end
