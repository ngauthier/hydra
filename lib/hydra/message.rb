module Hydra #:nodoc:
  class Message #:nodoc:
    def initialize(opts = {})
      opts.each do |k,v|
        self.send(k,v)
      end
    end
    def self.build(hash)
      hash.delete(:class).new(hash)
    end

    def serialize(opts = {})
      opts[:class] = self.class
      opts.inspect
    end
  end
end
require 'hydra/message/runner_requests_file'
