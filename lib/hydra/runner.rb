module Hydra #:nodoc:
  # Hydra class responsible for running test files
  class Runner
    # Boot up a runner. It takes an IO object (generally a pipe from its
    # parent) to send it messages on which files to execute.
    def initialize(io)
      @io = io
      @io.write Hydra::Messages::Runner::RequestFile.new
      process_messages
    end

    # The runner will continually read messages and handle them.
    def process_messages
      @running = true
      while @running
        begin
          message = @io.gets
          message.handle(self) if message
          @io.write Hydra::Messages::Runner::Ping.new
        rescue IOError => ex
          $stderr.write "Runner lost Worker\n"
          @running = false
        end
      end
    end

    # Run a test file and report the results
    def run_file(file)
      `ruby #{file}`
      @io.write Hydra::Messages::Runner::Results.new(:output => "Finished", :file => file)
    end

    # Stop running
    def stop
      @running = false
    end
  end
end
