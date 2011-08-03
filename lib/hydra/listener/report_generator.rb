module Hydra #:nodoc:
  module Listener #:nodoc:
    # Output a textual report at the end of testing
    class ReportGenerator < Hydra::Listener::Abstract
      # Initialize a new report
      def testing_begin(files)
        @report = { }
      end

      # Log the start time of a file
      def file_begin(file)
        @report[file] ||= { }
        @report[file]['start'] = Time.now.to_f
      end

      # Log the end time of a file and compute the file's testing
      # duration
      def file_end(file, output)
        @report[file]['end'] = Time.now.to_f
        @report[file]['duration'] = @report[file]['end'] - @report[file]['start']
        @report[file]['all_tests_passed_last_run'] = (output == '.')
      end

      # output the report
      def testing_end
        YAML.dump(@report, @output)
        @output.close
      end
    end
  end
end


