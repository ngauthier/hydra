require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'tmpdir'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'hydra'

# Since Hydra turns off testing, we have to turn it back on
Test::Unit.run = false

class Test::Unit::TestCase
  def target_file
    File.expand_path(File.join(Dir.tmpdir, 'hydra_test.txt'))
  end
  
  def alternate_target_file
    File.expand_path(File.join(Dir.tmpdir, 'alternate_hydra_test.txt'))
  end

  def test_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'write_file.rb'))
  end

  def rspec_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'write_file_spec.rb'))
  end

  def alternate_rspec_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'write_file_alternate_spec.rb'))
  end

  def rspec_file_with_pending
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'write_file_with_pending_spec.rb'))
  end

  def cucumber_feature_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'features', 'write_file.feature'))
  end

  def alternate_cucumber_feature_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'features', 'write_alternate_file.feature'))
  end

  def javascript_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'js_file.js'))
  end

  def json_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'json_data.json'))
  end
end

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

