module Hydra #:nodoc:
  # Trace output when in verbose mode.
  module Trace
    module ClassMethods
      # Make a class traceable. Takes one parameter,
      # which is the prefix for the trace to identify this class
      def traceable(prefix = self.class.to_s)
        include Hydra::Trace::InstanceMethods
        class << self; attr_accessor :_traceable_prefix; end
        self._traceable_prefix = prefix
      end
    end

    module InstanceMethods
      # Trace some output with the class's prefix and a newline.
      # Checks to ensure we're running verbosely.
      def trace(str)
        $stdout.write "#{self.class._traceable_prefix}| #{str}\n" if @verbose
      end
    end
  end
end
Object.extend(Hydra::Trace::ClassMethods)
