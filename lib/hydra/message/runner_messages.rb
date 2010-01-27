module Hydra #:nodoc:
  module Messages #:nodoc:
    module Runner #:nodoc:
      # Message indicating that a Runner needs a file to run
      class RequestFile < Hydra::Message
      end

      # Message telling the Runner to run a file
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
      end

      # Message to tell the Runner to shut down
      class Shutdown < Hydra::Message
        def handle(runner) #:nodoc:
          runner.stop
        end
      end
    end
  end
end
