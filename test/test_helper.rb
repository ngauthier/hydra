require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'tmpdir'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'hydra'

class Test::Unit::TestCase
end

TARGET = File.join(Dir.tmpdir, 'hydra_test.txt')
TESTFILE = File.join(File.dirname(__FILE__), 'fixtures', 'write_file.rb')

module Hydra #:nodoc:
  module Messages #:nodoc:
    class TestMessage < Hydra::Message
      attr_accessor :text
      def initialize(opts = {})
        @text = opts.fetch(:text){ "test" }
      end
      def serialize
        super(:text => @text)
      end
    end
  end
end

