module Hydra #:nodoc:
  # Hydra class responsible for running test files.
  #
  # The Runner is never run directly by a user. Runners are created by a
  # Worker to run test files.
  #
  # The general convention is to have one Runner for each logical processor
  # of a machine.
  class Runner
    include Hydra::Messages::Runner
    # Boot up a runner. It takes an IO object (generally a pipe from its
    # parent) to send it messages on which files to execute.
    def initialize(opts = {})
      @io = opts.fetch(:io) { raise "No IO Object" } 
      @verbose = opts.fetch(:verbose) { false }

      @io.write RequestFile.new
      process_messages
    end

    # The runner will continually read messages and handle them.
    def process_messages
      $stdout.write "RUNNER| Processing Messages\n" if @verbose
      @running = true
      while @running
        begin
          message = @io.gets
          if message
            $stdout.write "RUNNER| Received message from worker\n" if @verbose
            $stdout.write "      | #{message.inspect}\n" if @verbose
            message.handle(self)
          else
            @io.write Ping.new
          end
        rescue IOError => ex
          $stderr.write "Runner lost Worker\n" if @verbose
          @running = false
        end
      end
    end

    # Run a test file and report the results
    def run_file(file)
      `ruby #{file}`
      @io.write Results.new(:output => "Finished", :file => file)
    end

    # Stop running
    def stop
      @running = false
    end
  end
end
