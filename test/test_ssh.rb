require File.join(File.dirname(__FILE__), 'helper')

class TestSSH < Test::Unit::TestCase
  context "an ssh connection" do
    setup do
      @ssh = Hydra::SSH.new(
        'localhost', # connect to this machine
        File.expand_path(File.join(File.dirname(__FILE__))), # move to the test directory
        "ruby ./echo_the_dolphin.rb"
      )
      @message = Hydra::Messages::TestMessage.new
    end
    should "be able to execute a command" do
      @ssh.write @message 
      assert_equal @message.text, @ssh.gets.text
    end
  end
end
