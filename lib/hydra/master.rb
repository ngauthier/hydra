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
      @verbose = opts.fetch(:verbose) { false }
      # default is one worker that is configured to use a pipe with one runner
      worker_cfg = opts.fetch(:workers) {
        [ { :type => :local, :runners => 1} ] 
      }

      $stdout.write "MASTER| Initialized\n" if @verbose

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
      $stdout.write "MASTER| Booting workers\n" if @verbose
      workers.select{|worker| worker[:type] == :local}.each do |worker|
        $stdout.write "MASTER| Booting local worker\n" if @verbose 
        boot_local_worker(worker)
      end
      workers.select{|worker| worker[:type] == :ssh}.each do |worker|
        $stdout.write "MASTER| Booting ssh worker\n" if @verbose 
        boot_ssh_worker(worker)
      end
    end

    def boot_local_worker(worker)
      runners = worker.fetch(:runners) { raise "You must specify the number of runners" }
      pipe = Hydra::Pipe.new
      child = Process.fork do
        pipe.identify_as_child
        Hydra::Worker.new(:io => pipe, :runners => runners)
      end
      pipe.identify_as_parent
      @workers << { :pid => child, :io => pipe, :idle => false }
    end

    def boot_ssh_worker(worker)
      runners = worker.fetch(:runners) { raise "You must specify the number of runners"  }
      connect = worker.fetch(:connect) { raise "You must specify SSH connection options" }
      directory = worker.fetch(:directory) { raise "You must specify a remote directory" }
      command = worker.fetch(:command) { 
        "ruby -e \"require 'rubygems'; require 'hydra'; Hydra::Worker.new(:io => Hydra::Stdio.new, :runners => #{runners});\""
      }

      ssh = nil
      child = Process.fork do
        ssh = Hydra::SSH.new(connect, directory, command)
      end
      @workers << { :pid => child, :io => ssh, :idle => false }
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
