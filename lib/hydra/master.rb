module Hydra #:nodoc:
  # Hydra class responsible for delegate work down to workers.
  #
  # The Master is run once for any given testing session.
  class Master
    include Hydra::Messages::Master
    # Create a new Master
    #
    # Options:
    # * :files
    #   * An array of test files to be run. These should be relative paths from
    #     the root of the project, since they may be run on different machines
    #     which may have different paths.
    # * :workers
    #   * An array of hashes. Each hash should be the configuration options
    #     for a worker.
    def initialize(opts = { })
      @files = opts.fetch(:files) { [] }
      @workers = []
      @listeners = []
      # default is one worker that is configured to use a pipe with one runner
      worker_cfg = opts.fetch(:workers) {
        [ { :type => :local, :runners => 1} ] 
      }

      boot_workers worker_cfg
      process_messages
    end

    # Message handling
    
    # Send a file down to a worker. If there are no more files, this will shut the
    # worker down.
    def send_file(worker)
      f = @files.pop
      if f
        worker[:io].write(RunFile.new(:file => f))
      else
        worker[:io].write(Shutdown.new)
        Thread.exit
      end
    end

    private
    
    def boot_workers(workers)
      workers.select{|worker| worker[:type] == :local}.each do |worker|
        boot_local_worker(worker)
      end
      workers.select{|worker| worker[:type] == :ssh}.each do |worker|
        boot_ssh_worker(worker)
      end
    end

    def boot_local_worker(worker)
      pipe = Hydra::Pipe.new
      child = Process.fork do
        pipe.identify_as_child
        Hydra::Worker.new(:io => pipe, :runners => worker[:runners])
      end
      pipe.identify_as_parent
      @workers << { :pid => child, :io => pipe, :idle => false }
    end

    def boot_ssh_worker(worker)
      raise "Don't know how to boot SSH workers yet"
    end

    def process_messages
      Thread.abort_on_exception = true

      @workers.each do |worker|
        @listeners << Thread.new do
          while true
            begin
              message = worker[:io].gets
              message.handle(self, worker) if message
            rescue IOError => ex
              $stderr.write "Master lost Worker [#{worker.inspect}]\n"
              worker[:io].close
              @workers.delete(worker)
              Thread.exit
            end
          end
        end
      end
      
      @listeners.each{|l| l.join}
    end
  end
end
