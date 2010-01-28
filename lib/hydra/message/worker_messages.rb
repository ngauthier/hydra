module Hydra #:nodoc:
  module Messages #:nodoc:
    module Worker #:nodoc:
      # Message indicating that a work needs a file to delegate to a runner
      class RequestFile < Hydra::Message
      end

      # Message telling a worker to delegate a file to a runner
      class RunFile < Hydra::Messages::Runner::RunFile
        def handle(worker)
          worker.delegate_file(self)
        end
      end

      # Message relaying the results of a worker up to the master
      class Results < Hydra::Messages::Runner::Results
      end

      class Shutdown < Hydra::Messages::Runner::Shutdown
        def handle(worker)
          worker.shutdown
        end
      end
    end
  end
end
