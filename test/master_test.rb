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
      Hydra::Master.new(
        :files => [test_file]
      )
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end

    should "run a test 6 times on 1 worker with 2 runners" do
      Hydra::Master.new(
        :files => [test_file]*6,
        :local => {
          :runners => 2
        }
      )
      assert File.exists?(target_file)
      assert_equal "HYDRA"*6, File.read(target_file)
    end

    # The test being run sleeps for 2 seconds. So, if this was run in
    # series, it would take at least 20 seconds. This test ensures that
    # in runs in less than that amount of time. Since there are 10
    # runners to run the file 10 times, it should only take 2-4 seconds
    # based on overhead.
    should "run a slow test 10 times on 1 worker with 10 runners quickly" do
      start = Time.now
      Hydra::Master.new(
        :files => [File.join(File.dirname(__FILE__), 'fixtures', 'slow.rb')]*10,
        :workers => [
          { :type => :local, :runners => 10 }
        ]
      )
      finish = Time.now
      assert (finish-start) < 15, "took #{finish-start} seconds"
    end

    should "run a slow test 10 times on 2 workers with 5 runners each quickly" do
      start = Time.now
      Hydra::Master.new(
        :files => [File.join(File.dirname(__FILE__), 'fixtures', 'slow.rb')]*10,
        :workers => [
          { :type => :local, :runners => 5 },
          { :type => :local, :runners => 5 }
        ]
      )
      finish = Time.now
      assert (finish-start) < 15, "took #{finish-start} seconds"
    end


    should "run a test via ssh" do
      Hydra::Master.new(
        :files => [test_file],
        :workers => [{
          :type => :ssh,
          :connect => 'localhost',
          :directory => File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')),
          :runners => 1 
        }]
      )
      assert File.exists?(target_file)
      assert_equal "HYDRA", File.read(target_file)
    end
  end
end
