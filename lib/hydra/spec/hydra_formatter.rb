require 'rspec/core/formatters/progress_formatter'
module RSpec
  module Core
    module Formatters
      class HydraFormatter < ProgressFormatter
        def example_passed(example)
        end

        def example_pending(example)
        end

        def example_failed(example)
        end

        # Stifle the post-test summary
        def dump_summary(duration, example, failure, pending)
        end

        # Stifle pending specs
        def dump_pending
        end
      end
    end
  end
end

