require File.join(File.dirname(__FILE__), 'helper')

class TestMessage < Test::Unit::TestCase
  class MyMessage < Hydra::Message
    attr_accessor :my_var
    def serialize
      super(:my_var => @my_var)
    end
  end

  context "with a message" do
    setup do
      @m = MyMessage.new(:my_var => 'my value')
    end
    should "set values" do
      assert_equal 'my value', @m.my_var
    end
    should "serialize" do
      assert_equal(
        "{:class=>TestMessage::MyMessage, :my_var=>\"my value\"}",
        @m.serialize
      )
    end
    should "build from serialization" do
      assert_equal(
        @m.my_var,
        Hydra::Message.build(eval(@m.serialize)).my_var
      )
    end
  end
end
