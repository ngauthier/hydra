module Hydra #:nodoc:
  module Listener #:nodoc:
    # Output a progress bar as files are completed
    class ProgressBar < Hydra::Listener::Abstract
      # Store the total number of files
      def testing_begin(files)
        @total_files = files.size
        @files_completed = 0
        @test_output = ""
        @errors = false
        render_progress_bar
      end

      # Increment completed files count and update bar
      def file_end(file, output)
        unless output == '.'
          @output.write "\r#{' '*60}\r#{output}\n"
          @errors = true
        end
        @files_completed += 1
        render_progress_bar
      end

      # Break the line
      def testing_end
        render_progress_bar
        @output.write "\n"
      end

      private

      def render_progress_bar
        width = 30
        complete = ((@files_completed.to_f / @total_files.to_f) * width).to_i
        @output.write "\r" # move to beginning
        @output.write 'Hydra Testing ['
        @output.write @errors ? "\033[1;31m" : "\033[1;32m"
        complete.times{@output.write '#'}
        @output.write '>'
        (width-complete).times{@output.write ' '}
        @output.write "\033[0m"
        @output.write "] #{@files_completed}/#{@total_files}"
        @output.flush
      end
    end
  end
end

