module Hydra #:nodoc:
  # Base message object. Used to pass messages with parameters around
  # via IO objects.
  #   class MyMessage < Hydra::Message
  #     attr_accessor :my_var
  #     def serialize
  #       super(:my_var => @my_var)
  #     end
  #   end
  #   m = MyMessage.new(:my_var => 'my value')
  #   m.my_var
  #     => "my value"
  #   m.serialize
  #     => "{:class=>TestMessage::MyMessage, :my_var=>\"my value\"}"
  #   Hydra::Message.build(eval(@m.serialize)).my_var
  #     => "my value"
  class Message
    # Create a new message. Opts is a hash where the keys
    # are attributes of the message and the values are
    # set to the attribute.
    def initialize(opts = {})
      opts.delete :class
      opts.each do |variable,value|
        self.send("#{variable}=",value)
      end
    end

    # Build a message from a hash. The hash must contain
    # the :class symbol, which is the class of the message
    # that it will build to.
    def self.build(hash)
      hash.delete(:class).new(hash)
    end

    # Serialize the message for output on an IO channel.
    # This is really just a string representation of a hash
    # with no newlines. It adds in the class automatically
    def serialize(opts = {})
      opts.merge({:class => self.class}).inspect
    end
  end
end

require 'hydra/message/runner_messages'
require 'hydra/message/worker_messages'
require 'hydra/message/master_messages'

