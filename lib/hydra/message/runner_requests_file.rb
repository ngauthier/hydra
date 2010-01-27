module Hydra #:nodoc:
  module Messages #:nodoc:
    class RunnerRequestsFile < Hydra::Message
      def serialize
        "Hydra::Messages::RunnerRequestsFile"
      end
    end
  end
end
