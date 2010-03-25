module Hydra #:nodoc:
  module Listener #:nodoc:
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
      # Fired when testing has started
      def testing_begin(files)
      end

      # Fired when testing finishes
      def testing_end
      end

      # Fired when a file is started
      def file_begin(file)
      end

      # Fired when a file is finished
      def file_end(file, output)
      end
    end
  end
end
