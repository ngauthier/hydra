module Hydra #:nodoc:
  module Messages #:nodoc:
    module Master #:nodoc:
      # Message telling a worker to delegate a file to a runner
      class RunFile < Hydra::Messages::Worker::RunFile
        def handle(worker) #:nodoc:
          worker.delegate_file(self)
        end
      end

      # Message telling the worker to shut down.
      class Shutdown < Hydra::Messages::Worker::Shutdown
        def handle(worker) #:nodoc:
          worker.shutdown
        end
      end
    end
  end
end
