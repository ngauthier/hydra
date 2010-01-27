require 'open3'
require 'hydra/io'
module Hydra #:nodoc:
  # Read and write with an ssh connection. For example:
  #  @ssh = Hydra::SSH.new('nick@nite')
  #  @ssh.write("echo hi")
  #  puts @ssh.gets
  #    => hi
  #
  # You can also use this to launch an interactive process. For
  # example:
  #  @ssh = Hydra::SSH.new('nick@nite')
  #  @ssh.write('irb')
  #  @ssh.write("5+3")
  #  @ssh.gets
  #    => "5+3\n"       # because irb echoes commands
  #  @ssh.gets
  #    => "8"           # the output from irb
  class SSH
    include Open3
    include Hydra::MessagingIO

    # Initialize new SSH connection. The single parameters is passed
    # directly to ssh for starting a connection. So you can do:
    #  Hydra::SSH.new('localhost')
    #  Hydra::SSH.new('user@server.com')
    #  Hydra::SSH.new('-p 3022 user@server.com')
    # etc..
    def initialize(connection_options)
      @writer, @reader, @error = popen3("ssh #{connection_options}")
    end
  end
end
