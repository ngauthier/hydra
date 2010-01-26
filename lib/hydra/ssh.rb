require 'open3'
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

    # Initialize new SSH connection. The single parameters is passed
    # directly to ssh for starting a connection. So you can do:
    #  Hydra::SSH.new('localhost')
    #  Hydra::SSH.new('user@server.com')
    #  Hydra::SSH.new('-p 3022 user@server.com')
    # etc..
    def initialize(connection_options)
      @stdin, @stdout, @stderr = popen3("ssh #{connection_options}")
    end

    # Write a string to ssh. This method returns the string passed to
    # ssh. Note that if you do not add a newline at the end, it adds
    # one for you, and the modified string is returned
    def write(str)
      unless str =~ /\n$/
        str += "\n"
      end
      @stdin.write(str)
      return str
    end

    # Read a line from ssh. This call blocks when there is nothing
    # to read.
    def gets
      @stdout.gets.chomp
    end
  end
end
