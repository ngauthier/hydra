module Hydra #:nodoc: 
  module Messages #:nodoc:
    module Worker #:nodoc:
      # Message indicating that a worker needs a file to delegate to a runner
      class RequestFile < Hydra::Message
        def handle(master, worker)
          master.send_file(worker)
        end
      end

      # Message telling a worker to delegate a file to a runner
      # TODO: move to master messages
      class RunFile < Hydra::Messages::Runner::RunFile
        def handle(worker)
          worker.delegate_file(self)
        end
      end

      # Message relaying the results of a worker up to the master
      class Results < Hydra::Messages::Runner::Results
        def handle(master, worker)
          master.send_file(worker)
        end
      end

      # Message telling the worker to shut down.
      # TODO: move to master
      class Shutdown < Hydra::Messages::Runner::Shutdown
        def handle(worker)
          worker.shutdown
        end
      end

      # Message a worker sends to a master to verify the connection
      class Ping < Hydra::Message
        # We don't do anything to handle a ping. It's just to test
        # the connectivity of the IO
        def handle(master, worker)
        end
      end
    end
  end
end
