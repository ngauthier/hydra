require 'spec/autorun'
require 'spec/runner/formatter/progress_bar_formatter'
module Spec
  module Runner
    class << self
      # stop the auto-run at_exit
      def run
        return 0
      end 
    end
    module Formatter
      class HydraFormatter < ProgressBarFormatter
        # Stifle the post-test summary
        def dump_summary(duration, example, failure, pending)
        end
      end
    end
  end
end

