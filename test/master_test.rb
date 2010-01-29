require File.join(File.dirname(__FILE__), 'test_helper')

class MasterTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      FileUtils.rm_f(TARGET)
    end

    teardown do
      FileUtils.rm_f(TARGET)
    end

    should "run a test" do
      m = Hydra::Master.new({
        :files => Array(TESTFILE)
      })
      assert File.exists?(TARGET)
      assert_equal "HYDRA", File.read(TARGET)
    end
  end
end
