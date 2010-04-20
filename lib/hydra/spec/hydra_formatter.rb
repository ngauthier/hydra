require 'spec/runner/formatter/progress_bar_formatter'
module Spec
  module Runner
    module Formatter
      class HydraFormatter < ProgressBarFormatter
        # Stifle the post-test summary
        def dump_summary(duration, example, failure, pending)
        end

        # Stifle the output of pending examples
        def example_pending(*args)
        end
      end
    end
  end
end

