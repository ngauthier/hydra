require File.join(File.dirname(__FILE__), 'test_helper')

class PipeTest < Test::Unit::TestCase
  context "a pipe" do
    setup do
      @pipe = Hydra::Pipe.new
    end
    teardown do
      @pipe.close
    end
    should "be able to write messages" do
      child = Process.fork do
        @pipe.identify_as_child
        assert_equal "Test Message", @pipe.gets.text
        @pipe.write Hydra::Messages::TestMessage.new(:text => "Message Received")
        @pipe.write Hydra::Messages::TestMessage.new(:text => "Second Message")
      end
      @pipe.identify_as_parent
      @pipe.write Hydra::Messages::TestMessage.new(:text => "Test Message")
      assert_equal "Message Received", @pipe.gets.text
      assert_equal "Second Message", @pipe.gets.text
      Process.wait(child) #ensure it quits, so there is nothing to write to
      assert_raise IOError do
        @pipe.write Hydra::Messages::TestMessage.new(:text => "anyone there?")
      end
    end
    should "not allow writing if unidentified" do
      assert_raise IOError do
        @pipe.write Hydra::Messages::TestMessage.new(:text => "Test Message")
      end
    end
    should "not allow reading if unidentified" do
      assert_raise IOError do
        @pipe.gets
      end
    end
  end
end
