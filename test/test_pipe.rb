require File.join(File.dirname(__FILE__), 'helper')

class TestPipe < Test::Unit::TestCase
  context "a pipe" do
    setup do
      @pipe = Hydra::Pipe.new
    end
    should "be able to write messages" do
      Process.fork do
        @pipe.identify_as_child
        assert_equal "Test Message", @pipe.gets
        @pipe.write "Message Received"
        @pipe.write "Second Message"
        @pipe.close
      end
      @pipe.identify_as_parent
      @pipe.write "Test Message"
      assert_equal "Message Received", @pipe.gets
      assert_equal "Second Message", @pipe.gets
      assert_raise Hydra::PipeError::Broken do
        @pipe.write "anybody home?"
      end
      @pipe.close
    end
    should "not allow writing if unidentified" do
      assert_raise Hydra::PipeError::Unidentified do
        @pipe.write "hey\n"
      end
    end
    should "not allow reading if unidentified" do
      assert_raise Hydra::PipeError::Unidentified do
        @pipe.gets
      end
    end
    should "handle newlines" do
      Process.fork do
        @pipe.identify_as_child
        @pipe.write "Message\n"
      end
      @pipe.identify_as_parent
      assert_equal "Message", @pipe.gets
    end
  end
end
