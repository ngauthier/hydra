module Hydra #:nodoc:
  # Read and write between two processes via pipes. For example:
  #   @pipe = Hydra::Pipe.new
  #   Process.fork do
  #     @pipe.identify_as_child
  #     sleep(1)
  #     puts "A message from my parent:\n#{@pipe.gets}"
  #     @pipe.close
  #   end
  #   @pipe.identify_as_parent
  #   @pipe.write "Hello, Child!"
  #   @pipe.close
  # When the process forks, the pipe is copied. When a pipe is
  # identified as a parent or child, it is choosing which ends
  # of the pipe to use.
  #
  # A pipe is actually two pipes:
  #
  # Parent === Pipe 1 ==> Child
  # Parent <== Pipe 2 === Child
  class Pipe
    # Creates a new uninitialized pipe pair.
    def initialize
      @child_read, @parent_write = IO.pipe
      @parent_read, @child_write = IO.pipe
      [@parent_write, @child_write].each{|io| io.sync = true}
    end

    # Read a line from a pipe. It will have a trailing newline.
    def gets
      force_identification
      @reader.gets
    end

    # Write a line to a pipe. It must have a trailing newline.
    def write(str)
      force_identification
      begin
        @writer.write(str)
        return str
      rescue Errno::EPIPE
        raise Hydra::PipeError::Broken
      end
    end

    # Returns true if there is nothing to read (right now). However it is
    # not exactly eof, if the other side writes, this will return false.
    #
    # It's a good way to tell if there is anything to process right now,
    # otherwise, you can sleep.
    def eof?
      @reader.eof?
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

    # closes the pipes. Once a pipe is closed on one end, the other
    # end will get a PipeError::Broken if it tries to write.
    def close
      done_reading
      done_writing
    end

    private
    def done_writing #:nodoc:
      @writer.close unless @writer.closed?
    end

    def done_reading #:nodoc:
      @reader.close unless @reader.closed?
    end

    def force_identification #:nodoc:
      raise PipeError::Unidentified if @reader.nil? or @writer.nil?
    end
  end

  module PipeError #:nodoc:
    # Raised if you try to read or write to a pipe when it is unidentified.
    # Use identify_as_parent and identify_as_child to identify a pipe.
    class Unidentified < RuntimeError
      def message #:nodoc:
        "Must identify as child or parent"
      end
    end
    # Raised when a pipe has been broken between two processes.
    # This happens when a process exits, and is a signal that
    # there is no more data to communicate.
    class Broken < RuntimeError
      def message #:nodoc:
        "Other side closed the connection"
      end
    end
  end
end
