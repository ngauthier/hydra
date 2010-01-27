module Hydra #:nodoc:
  class Runner
    def initialize(io)
      @io = io
      @io.write Hydra::Messages::RunnerRequestsFile.new.serialize
    end
  end
end
