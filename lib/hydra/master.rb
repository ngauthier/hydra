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
        boot_local_worker(worker)
      end
      workers.select{|worker| worker[:type] == :ssh}.each do |worker|
        @workers << worker # will boot later, during the listening phase
      end
    end

    def boot_local_worker(worker)
      runners = worker.fetch(:runners) { raise "You must specify the number of runners" }
      $stdout.write "MASTER| Booting local worker\n" if @verbose 
      pipe = Hydra::Pipe.new
      child = Process.fork do
        pipe.identify_as_child
        Hydra::Worker.new(:io => pipe, :runners => runners)
      end
      pipe.identify_as_parent
      @workers << { :pid => child, :io => pipe, :idle => false, :type => :local }
    end

    def boot_ssh_worker(worker)
      runners = worker.fetch(:runners) { raise "You must specify the number of runners"  }
      connect = worker.fetch(:connect) { raise "You must specify SSH connection options" }
      directory = worker.fetch(:directory) { raise "You must specify a remote directory" }
      command = worker.fetch(:command) { 
        "ruby -e \"require 'rubygems'; require 'hydra'; Hydra::Worker.new(:io => Hydra::Stdio.new, :runners => #{runners}, :verbose => #{@verbose});\""
      }

      $stdout.write "MASTER| Booting SSH worker\n" if @verbose 
      ssh = Hydra::SSH.new(connect, directory, command)
      return { :io => ssh, :idle => false, :type => :ssh }
    end

    def process_messages
      Thread.abort_on_exception = true

      $stdout.write "MASTER| Processing Messages\n" if @verbose
      $stdout.write "MASTER| Workers: #{@workers}\n" if @verbose
      @workers.each do |worker|
        @listeners << Thread.new do
          $stdout.write "MASTER| Listening to #{worker.inspect}\n" if @verbose
          worker = boot_ssh_worker(worker) if worker.fetch(:type){ :local } == :ssh
          while true
            begin
              $stdout.write "MASTER| listen....\n" if @verbose
              message = worker[:io].gets
              $stdout.write "MASTER| got message: #{message}\n" if @verbose
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
