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
      boot_workers(opts.fetch(:workers) { [ {:runners => 1} ] } )
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
      workers.each do |w|
        pipe = Hydra::Pipe.new
        child = Process.fork do
          pipe.identify_as_child
          Hydra::Worker.new(:io => pipe, :runners => w[:runners])
        end
        pipe.identify_as_parent
        @workers << { :pid => child, :io => pipe, :idle => false }
      end
    end

    def process_messages
      @running = true

      Thread.abort_on_exception = true

      @workers.each do |w|
        @listeners << Thread.new do
          while @running
            begin
              message = w[:io].gets
              message.handle(self, w) if message
            rescue IOError => ex
              $stderr.write "Master lost Worker [#{w.inspect}]\n"
              w[:io].close
              @workers.delete(w)
              Thread.exit
            end
          end
        end
      end
      
      @listeners.each{|l| l.join}
    end
  end
end
