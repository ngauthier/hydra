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
      Process.wait(@child)
    end
    should "request a file on boot" do
      assert @pipe.gets.is_a?(Hydra::Messages::RunnerRequestsFile)
    end
    should "return a result message after processing a file" do
      
    end
    should "terminate when sent a shutdown message"
  end
end
