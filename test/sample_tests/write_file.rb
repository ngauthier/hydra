require File.join(File.dirname(__FILE__), '..', 'helper')

class TestWriteFile < Test::Unit::TestCase
  should "write file" do
    File.open(File.join(Dir.tmpdir, 'hydra_test.txt'), 'w') do |f|
      f.write "HYDRA"
    end
  end
end

