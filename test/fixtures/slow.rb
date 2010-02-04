require File.join(File.dirname(__FILE__), '..', 'test_helper')

class WriteFileTest < Test::Unit::TestCase
  def test_slow
    sleep(5)
  end
end


