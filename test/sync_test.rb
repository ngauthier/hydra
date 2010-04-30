require File.join(File.dirname(__FILE__), 'test_helper')

class SyncTest < Test::Unit::TestCase
  context "with a file to test and a destination to verify" do
    setup do
      # avoid having other tests interfering with us
      sleep(0.2)
      #FileUtils.rm_f(target_file)
    end

    teardown do
      #FileUtils.rm_f(target_file)
    end

    should "synchronize a test file over ssh with rsync" do
      local = File.join(Dir.tmpdir, 'hydra', 'local')
      remote = File.join(Dir.tmpdir, 'hydra', 'remote')
      sync_test = File.join(File.dirname(__FILE__), 'fixtures', 'sync_test.rb')
      [local, remote].each{|f| FileUtils.rm_rf f; FileUtils.mkdir_p f}

      # setup the folders:
      # local:
      #   - test_a
      #   - test_c
      # remote:
      #   - test_b
      #
      # add test_c to exludes
      FileUtils.cp(sync_test, File.join(local, 'test_a.rb'))
      FileUtils.cp(sync_test, File.join(local, 'test_c.rb'))
      FileUtils.cp(sync_test, File.join(remote, 'test_b.rb'))

      # ensure a is not on remote
      assert !File.exists?(File.join(remote, 'test_a.rb')), "A should not be on remote"
      # ensure c is not on remote
      assert !File.exists?(File.join(remote, 'test_c.rb')), "C should not be on remote"
      # ensure b is on remote
      assert File.exists?(File.join(remote, 'test_b.rb')),  "B should be on remote"

      Hydra::Sync.new(
        {
          :type => :ssh,
          :connect => 'localhost',
          :directory => remote,
          :runners => 1
        },
        {
          :directory => local,
          :exclude => ['test_c.rb']
        }
      )
      # ensure a is copied
      assert File.exists?(File.join(remote, 'test_a.rb')), "A was not copied"
      # ensure c is not copied
      assert !File.exists?(File.join(remote, 'test_c.rb')), "C was copied, should be excluded"
      # ensure b is deleted
      assert !File.exists?(File.join(remote, 'test_b.rb')), "B was not deleted"
    end

    should "synchronize a test file over ssh with rsync to multiple workers" do
      local = File.join(Dir.tmpdir, 'hydra', 'local')
      remote_a = File.join(Dir.tmpdir, 'hydra', 'remote_a')
      remote_b = File.join(Dir.tmpdir, 'hydra', 'remote_b')
      sync_test = File.join(File.dirname(__FILE__), 'fixtures', 'sync_test.rb')
      [local, remote_a, remote_b].each{|f| FileUtils.rm_rf f; FileUtils.mkdir_p f}

      # setup the folders:
      # local:
      #   - test_a
      # remote_a:
      #   - test_b
      # remote_b:
      #   - test_c
      #
      # add test_c to exludes
      FileUtils.cp(sync_test, File.join(local, 'test_a.rb'))
      FileUtils.cp(sync_test, File.join(remote_a, 'test_b.rb'))
      FileUtils.cp(sync_test, File.join(remote_b, 'test_c.rb'))

      # ensure a is not on remotes
      assert !File.exists?(File.join(remote_a, 'test_a.rb')), "A should not be on remote_a"
      assert !File.exists?(File.join(remote_b, 'test_a.rb')), "A should not be on remote_b"
      # ensure b is on remote_a
      assert File.exists?(File.join(remote_a, 'test_b.rb')),  "B should be on remote_a"
      # ensure c is on remote_b
      assert File.exists?(File.join(remote_b, 'test_c.rb')),  "C should be on remote_b"

      Hydra::Sync.sync_many(
        :workers => [{
          :type => :ssh,
          :connect => 'localhost',
          :directory => remote_a,
          :runners => 1
        },
        {
          :type => :ssh,
          :connect => 'localhost',
          :directory => remote_b,
          :runners => 1
        }],
        :sync => {
          :directory => local
        }
      )
      # ensure a is copied to both remotes
      assert File.exists?(File.join(remote_a, 'test_a.rb')), "A was not copied to remote_a"
      assert File.exists?(File.join(remote_b, 'test_a.rb')), "A was not copied to remote_b"
      # ensure b and c are deleted from remotes
      assert !File.exists?(File.join(remote_a, 'test_b.rb')), "B was not deleted from remote_a"
      assert !File.exists?(File.join(remote_b, 'test_c.rb')), "C was not deleted from remote_b"
    end
  end
end
