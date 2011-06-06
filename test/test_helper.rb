require 'rubygems'
require 'test/unit'
gem 'shoulda', '2.10.3'
gem 'rspec', '2.0.0.beta.19'
require 'shoulda'
require 'tmpdir'
require "stringio"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'hydra'

# Since Hydra turns off testing, we have to turn it back on
Test::Unit.run = false

class Test::Unit::TestCase
  def target_file
    File.expand_path(File.join(Dir.consistent_tmpdir, 'hydra_test.txt'))
  end
  
  def alternate_target_file
    File.expand_path(File.join(Dir.consistent_tmpdir, 'alternate_hydra_test.txt'))
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

  def conflicting_test_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'conflicting.rb'))
  end

  def remote_dir_path
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
  end

  def hydra_worker_init_file
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'hydra_worker_init.rb'))
  end

  def capture_stderr
    # The output stream must be an IO-like object. In this case we capture it in
    # an in-memory IO object so we can return the string value. You can assign any
    # IO object here.
    previous_stderr, $stderr = $stderr, StringIO.new
    yield
    $stderr.string
  ensure
    # Restore the previous value of stderr (typically equal to STDERR).
    $stderr = previous_stderr
  end

  #this method allow us to wait for a file for a maximum number of time, so the
  #test can pass in slower machines. This helps to speed up the tests
  def assert_file_exists file, time_to_wait = 2
    time_begin = Time.now

    until Time.now - time_begin >= time_to_wait or File.exists?( file ) do
      sleep 0.01
    end

    assert File.exists?( file )
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

