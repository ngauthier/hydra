require File.join(File.dirname(__FILE__), '..', 'test_helper')

# this test is around to make sure that we handle all the errors
# that can occur when 'require'ing a test file.
class SyncTest < Object
  def test_it_again
    assert true
  end
end

