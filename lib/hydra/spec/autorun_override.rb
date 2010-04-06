if defined?(Spec)
  module Spec
    module Runner
      class << self
        # stop the auto-run at_exit
        def run
          return 0
        end 
      end
    end
  end
end
