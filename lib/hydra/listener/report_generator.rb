module Hydra #:nodoc:
  module Listener #:nodoc:
    # Output a textual report at the end of testing
    class ReportGenerator < Hydra::Listener::Abstract
      def testing_begin(files)
        @report = { }
      end

      def file_begin(file)
        @report[file] ||= { }
        @report[file]['start'] = Time.now.to_f
      end

      def file_end(file, output)
        @report[file]['end'] = Time.now.to_f
        @report[file]['duration'] = @report[file]['end'] - @report[file]['start']
      end

      def testing_end
        YAML.dump(@report, @output)
        @output.close
      end
    end
  end
end
