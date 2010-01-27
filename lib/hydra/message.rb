module Hydra #:nodoc:
  class Message #:nodoc:
    def self.build(str)
      eval(str).new
    end
  end
end
require 'hydra/message/runner_requests_file'
