require 'cucumber/formatter/html'

module Hydra
  module Formatter
    class PartialHtml < Cucumber::Formatter::Html

      def before_features(features)
        # we do not want the default implementation as we will write our own header
      end

      def after_features(features)
        # we do not want the default implementation as we will write our own footer
      end

      def after_step(step)
        # need an alterantive way of incrementing progress/outputing stats
      end

      def percent_done
        0
      end
    end
  end
end
