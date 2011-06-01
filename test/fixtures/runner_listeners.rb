module HydraExtension
  module RunnerListener
    class RunnerBeginTest < Hydra::RunnerListener::Abstract
      # Fired by the runner just before requesting the first file
      def runner_begin( runner )
        FileUtils.touch File.expand_path(File.join(Dir.consistent_tmpdir, 'alternate_hydra_test.txt'))
      end
    end

    class RunnerEndTest < Hydra::RunnerListener::Abstract
      # Fired by the runner just after stoping
      def runner_end( runner )
        # NOTE: do not use trace here
        FileUtils.touch File.expand_path(File.join(Dir.consistent_tmpdir, 'alternate_hydra_test.txt'))
      end
    end
  end
end
