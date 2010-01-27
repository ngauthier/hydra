module Hydra #:nodoc:
  module MessagingIO
    # Read a line from the input IO object.
    def gets
      raise IOError unless @reader
      message = @reader.gets
      return nil unless message
      return Message.build(eval(message.chomp))
    end

    # Write a line to the output IO object
    def write(message)
      raise IOError unless @writer
      raise UnprocessableMessage unless message.is_a?(Hydra::Message)
      begin
        @writer.write(message.serialize+"\n")
      rescue Errno::EPIPE
        raise IOError
      end
    end

    def close
      @reader.close if @reader
      @writer.close if @writer
    end

    class UnprocessableMessage < RuntimeError
      attr_accessor :message
      def initialize(message = "Message expected")
        @message = message    
      end
    end
  end
end
