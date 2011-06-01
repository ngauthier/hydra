module Hydra #:nodoc:
  module RunnerListener #:nodoc:
    # Abstract listener that implements all the events
    # but does nothing.
    class Abstract
      # Create a new listener.
      #
      # Output: The IO object for outputting any information.
      # Defaults to STDOUT, but you could pass a file in, or STDERR
      def initialize(output = $stdout)
        @output = output
      end

      # Fired by the runner just before requesting the first file
      def runner_begin( runner )
      end

      # Fired by the runner just after stoping
      def runner_end( runner )
      end
    end
  end
end
