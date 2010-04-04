module Hydra #:nodoc:
  module Messages #:nodoc:
    module Runner #:nodoc:
      # Message indicating that a Runner needs a file to run
      class RequestFile < Hydra::Message
        def handle(worker, runner) #:nodoc:
          worker.request_file(self, runner)
        end
      end

      # Message for the Runner to respond with its results
      class Results < Hydra::Message
        # The output from running the test
        attr_accessor :output
        # The file that was run
        attr_accessor :file
        def serialize #:nodoc:
          super(:output => @output, :file => @file)
        end
        def handle(worker, runner) #:nodoc:
          worker.relay_results(self, runner)
        end
      end

      # Message a runner sends to a worker to verify the connection
      class Ping < Hydra::Message
        def handle(worker, runner) #:nodoc:
          # We don't do anything to handle a ping. It's just to test
          # the connectivity of the IO
        end
      end

      # The runner forks to run rspec messages
      # so that specs don't get rerun. It uses
      # this message to report the results. See
      # Runner::run_rspec_file.
      class RSpecResult < Hydra::Message
        # the output of the spec
        attr_accessor :output
        def serialize #:nodoc:
          super(:output => @output)
        end
      end
    end
  end
end
