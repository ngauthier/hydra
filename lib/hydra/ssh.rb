require 'open3'
require 'hydra/messaging_io'
module Hydra #:nodoc:
  # Read and write with an ssh connection. For example:
  #   @ssh = Hydra::SSH.new(
  #     'localhost', # connect to this machine
  #     '/home/user', # move to the home directory
  #     "ruby hydra/test/echo_the_dolphin.rb" # run the echo script
  #   )
  #   @message = Hydra::Messages::TestMessage.new("Hey there!")
  #   @ssh.write @message
  #   puts @ssh.gets.text
  #     => "Hey there!"
  #
  # Note that what ever process you run should respond with Hydra messages.
  class SSH
    include Open3
    include Hydra::MessagingIO

    # Initialize new SSH connection. The single parameters is passed
    # directly to ssh for starting a connection. So you can do:
    #  Hydra::SSH.new('localhost')
    #  Hydra::SSH.new('user@server.com')
    #  Hydra::SSH.new('-p 3022 user@server.com')
    # etc..
    def initialize(connection_options, directory, command)
      @writer, @reader, @error = popen3("ssh -tt #{connection_options}")
      @writer.write("cd #{directory}\n")
      @writer.write(command+"\n")
    end

    def close
      @writer.write "exit\n"
      super
    end
  end
end
