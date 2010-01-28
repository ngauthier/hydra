require File.join(File.dirname(__FILE__), '..', 'test_helper')

class WriteFileTest < Test::Unit::TestCase
  should "write file" do
    File.open(File.join(Dir.tmpdir, 'hydra_test.txt'), 'w') do |f|
      f.write "HYDRA"
    end
  end
end

