require 'cucumber/formatter/progress'

module Cucumber #:nodoc:
  module Formatter #:nodoc:
    # Hydra formatter for cucumber.
    # Stifles all output except error messages
    # Based on the 
    class Hydra < Cucumber::Formatter::Progress
      # Removed the extra newlines here
      def after_features(features)
        print_summary(features)
      end

      private
      
      # Removed the file statistics
      def print_summary(features)
        print_steps(:pending)
        print_steps(:failed)
        print_snippets(@options)
        print_passing_wip(@options)
        print_tag_limit_warnings(features)
      end

      # Removed all progress output
      def progress(status)
      end
    end
  end
end
