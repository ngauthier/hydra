require 'hydra/messaging_io'
module Hydra #:nodoc:
  # Read and write via stdout and stdin.
  class Stdio
    include Hydra::MessagingIO

    # Initialize new Stdio
    def initialize()
      @reader = $stdin
      @writer = $stdout
      @reader.sync = true
      @writer.sync = true
    end
  end
end

