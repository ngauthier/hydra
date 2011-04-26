require File.join(File.dirname(__FILE__), 'test_helper')

class SSHTest < Test::Unit::TestCase
  should "be able to execute a command over ssh" do
    ssh = Hydra::SSH.new(
      'localhost', # connect to this machine
      File.expand_path(File.join(File.dirname(__FILE__))), # move to the test directory
      "ruby fixtures/hello_world.rb"
    )
    response = ssh.gets
    assert_equal "Hello World", response.text
    ssh.close
  end

  should "be able to handle a large number of non-Hydra console output" do
    ssh = Hydra::SSH.new(
      'localhost', # connect to this machine
      File.expand_path(File.join(File.dirname(__FILE__))), # move to the test directory
      "ruby fixtures/many_outputs_to_console.rb"
    )
    response = ssh.gets
    assert_equal "My message", response.text
    ssh.close
  end
end
