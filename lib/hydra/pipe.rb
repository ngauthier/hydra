require 'hydra/messaging_io'
module Hydra #:nodoc:
  # Read and write between two processes via pipes. For example:
  #   @pipe = Hydra::Pipe.new
  #   @child = Process.fork do
  #     @pipe.identify_as_child
  #     puts "A message from my parent:\n#{@pipe.gets.text}"
  #     @pipe.close
  #   end
  #   @pipe.identify_as_parent
  #   @pipe.write Hydra::Messages::TestMessage.new(:text => "Hello!")
  #   @pipe.close
  #
  # Note that the TestMessage class is only available in tests, and
  # not in Hydra by default.
  #
  #
  # When the process forks, the pipe is copied. When a pipe is
  # identified as a parent or child, it is choosing which ends
  # of the pipe to use.
  #
  # A pipe is actually two pipes:
  #
  #  Parent  == Pipe 1 ==> Child
  #  Parent <== Pipe 2 ==  Child
  #
  # It's like if you had two cardboard tubes and you were using
  # them to drop balls with messages in them between processes.
  # One tube is for sending from parent to child, and the other
  # tube is for sending from child to parent.
  class Pipe
    include Hydra::MessagingIO
    # Creates a new uninitialized pipe pair.
    def initialize
      @child_read, @parent_write = IO.pipe
      @parent_read, @child_write = IO.pipe
    end

    # Identify this side of the pipe as the child.
    def identify_as_child
      @parent_write.close
      @parent_read.close
      @reader = @child_read
      @writer = @child_write
    end

    # Identify this side of the pipe as the parent
    def identify_as_parent
      @child_write.close
      @child_read.close
      @reader = @parent_read
      @writer = @parent_write
    end

    # Output pipe nicely
    def inspect
      "#<#{self.class} @reader=#{@reader.to_s}, @writer=#{@writer.to_s}>"
    end

  end
end
