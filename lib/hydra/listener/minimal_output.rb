module Hydra #:nodoc:
  module Listener #:nodoc:
    # Minimal output listener. Outputs all the files at the start
    # of testing and outputs a ./F/E per file. As well as
    # full error output, if any.
    class MinimalOutput < Hydra::Listener::Abstract
      def testing_begin(files)
        @output.write "Hydra Testing:\n#{files.inspect}\n"
      end

      def testing_end
        @output.write "\nHydra Completed\n"
      end

      def file_end(file, output)
        @output.write output
      end
    end
  end
end
