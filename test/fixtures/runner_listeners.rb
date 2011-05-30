require File.join(File.dirname(__FILE__), '..', 'test_helper')

module RunnerListener
  class RunnerBeginTest < Hydra::RunnerListener::Abstract
    # Fired by the runner just before requesting the first file
    def runner_begin
      FileUtils.touch File.expand_path(File.join(Dir.consistent_tmpdir, 'alternate_hydra_test.txt'))
    end
  end

  class RunnerEndTest < Hydra::RunnerListener::Abstract
    # Fired by the runner just after stoping
    def runner_end
      FileUtils.touch File.expand_path(File.join(Dir.consistent_tmpdir, 'alternate_hydra_test.txt'))
    end
  end
end
