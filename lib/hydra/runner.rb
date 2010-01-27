module Hydra #:nodoc:
  # Hydra class responsible for running test files
  class Runner
    # Boot up a runner. It takes an IO object (generally a pipe from its
    # parent) to send it messages on which files to execute.
    def initialize(io)
      @io = io
      @io.write Hydra::Messages::RunnerRequestsFile.new
    end
  end
end
