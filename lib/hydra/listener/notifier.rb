module Hydra #:nodoc:
  module Listener #:nodoc:
    # Sends a command to Notifier when the testing has finished
    # http://manpages.ubuntu.com/manpages/gutsy/man1/notify-send.1.html
    class Notifier < Hydra::Listener::Abstract
      # output a finished notification
      def testing_end
        icon_path = File.join(
          File.dirname(__FILE__), '..', '..', '..',
          'hydra-icon-64x64.png'
        )
        `notify-send -i #{icon_path} "Hydra" "Testing Completed"`
      end
    end
  end
end

