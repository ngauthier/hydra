require File.join(File.dirname(__FILE__), 'test_helper')

class SSHTest < Test::Unit::TestCase
  should "be able to execute a command over ssh" do
    ssh = Hydra::SSH.new(
      'localhost', # connect to this machine
      File.expand_path(File.join(File.dirname(__FILE__))), # move to the test directory
      "ruby fixtures/echo_the_dolphin.rb"
    )
    message = Hydra::Messages::TestMessage.new
    ssh.write message 
    assert_equal message.text, ssh.gets.text
    ssh.close
  end
end
