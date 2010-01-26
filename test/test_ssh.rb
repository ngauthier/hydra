require File.join(File.dirname(__FILE__), 'helper')

class TestSSH < Test::Unit::TestCase
  context "an ssh connection" do
    setup do
      @ssh = Hydra::SSH.new('localhost')
    end
    should "be able to execute a command" do
      @ssh.write "echo hi"
      assert_equal "hi", @ssh.gets
    end
    should "be able to execute a command with a newline" do
      @ssh.write "echo hi\n"
      assert_equal "hi", @ssh.gets
    end
    should "be able to communicate with a process" do
      pwd = File.dirname(__FILE__)
      echo_the_dolphin = File.expand_path(
        File.join(File.dirname(__FILE__), 'echo_the_dolphin.rb')
      )
      @ssh.write('ruby -e "puts \'Hello\'"')
      assert_equal "Hello", @ssh.gets

      @ssh.write("ruby #{echo_the_dolphin}")
      @ssh.write("Hello Echo!")
      assert_equal "Hello Echo!", @ssh.gets
    end
  end
end
