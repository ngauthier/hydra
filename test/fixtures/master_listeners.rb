module HydraExtension
  module Listener
    class WorkerBeganFlag < Hydra::Listener::Abstract
      # Fired after runner processes have been started
      def worker_begin(worker)
        FileUtils.touch File.expand_path(File.join(Dir.consistent_tmpdir, 'worker_began_flag'))
      end
    end
  end
end
