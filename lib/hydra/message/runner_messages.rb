module Hydra #:nodoc:
  module Messages #:nodoc:
    module Runner #:nodoc:
      # Message indicating that a Runner needs a file to run
      class RequestFile < Hydra::Message
        def handle(worker, runner) #:nodoc:
          worker.request_file(self, runner)
        end
      end

      # Message telling the Runner to run a file
      # TODO: move to worker
      class RunFile < Hydra::Message
        attr_accessor :file
        def serialize #:nodoc:
          super(:file => @file)
        end
        def handle(runner) #:nodoc:
          runner.run_file(@file)
        end
      end

      # Message for the Runner to respond with its results
      class Results < Hydra::Message
        attr_accessor :output
        attr_accessor :file
        def serialize #:nodoc:
          super(:output => @output, :file => @file)
        end
        def handle(worker, runner) #:nodoc:
          worker.relay_results(self, runner)
        end
      end

      # Message to tell the Runner to shut down
      # TODO: move to worker
      class Shutdown < Hydra::Message
        def handle(runner) #:nodoc:
          runner.stop
        end
      end
      
      # Message a runner sends to a worker to verify the connection
      class Ping < Hydra::Message
        # We don't do anything to handle a ping. It's just to test
        # the connectivity of the IO
        def handle(worker, runner)
        end
      end
    end
  end
end
