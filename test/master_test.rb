require File.join(File.dirname(__FILE__), 'test_helper')

class MasterTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      FileUtils.rm_f(target_file)
    end

    teardown do
      FileUtils.rm_f(target_file)
    end

    should "run a test" do
      m = Hydra::Master.new({
        :files => Array(test_file)
      })
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end
  end
end
