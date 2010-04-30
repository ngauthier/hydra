require 'yaml'
module Hydra #:nodoc:
  # Hydra class responsible for delegate work down to workers.
  #
  # The Sync is run once for each remote worker.
  class Sync
    traceable('SYNC')
    class << self
      traceable('SYNC')
    end

    # Create a new Sync instance to rsync source from the local machine to a remote worker
    #
    # Arguments:
    # * :worker
    #   * A hash of the configuration options for a worker.
    # * :sync
    #   * A hash of settings specifically for copying the source directory to be tested
    #     to the remote worked
    # * :verbose
    #   * Set to true to see lots of Hydra output (for debugging)
    def initialize(worker, sync, verbose = false)
      @verbose = verbose

      trace "Initialized"
      trace "  Worker: (#{worker.inspect})"
      trace "  Sync:   (#{sync.inspect})"
      trace "  Verbose: (#{@verbose.inspect})"

      sync(worker, sync)
    end

    def sync worker_opts, sync_opts
      return unless sync_opts and worker_opts
      sync_opts.stringify_keys!
      worker_opts.stringify_keys!
      @verbose = sync_opts.fetch('verbose') { false }
    
      connect, ssh_opts, directory = Master.remote_connection_opts(worker_opts)

      trace "Synchronizing with #{connect}\n\t#{sync_opts.inspect}"
      local_dir = sync_opts.fetch('directory') { 
        raise "You must specify a synchronization directory"
      }
      exclude_paths = sync_opts.fetch('exclude') { [] }
      exclude_opts = exclude_paths.inject(''){|memo, path| memo += "--exclude=#{path} "}

      rsync_command = [
        'rsync',
        '-avz',
        '--delete',
        exclude_opts,
        File.expand_path(local_dir)+'/',
        "-e \"ssh #{ssh_opts}\"",
        "#{connect}:#{directory}"
      ].join(" ")
      trace rsync_command
      trace `#{rsync_command}`
    end

    def self.sync_many opts
      opts.stringify_keys!
      config_file = opts.delete('config') { nil }
      if config_file
        opts.merge!(YAML.load_file(config_file).stringify_keys!)
      end
      @verbose = opts.fetch('verbose') { false }
      @sync = opts.fetch('sync') { nil }

      # default is one worker that is configured to use a pipe with one runner
      worker_opts = opts.fetch('workers') { [ { 'type' => 'local', 'runners' => 1} ] }
      @workers = []
      worker_opts.each do |worker|
        worker.stringify_keys!
        trace "worker opts #{worker.inspect}"
        type = worker.fetch('type') { 'local' }
        if type.to_s == 'ssh'
          @workers << worker
        end
      end

      trace "Initialized"
      trace "  Sync:   (#{@sync.inspect})"
      trace "  Workers: (#{@workers.inspect})"
      trace "  Verbose: (#{@verbose.inspect})"

      Thread.abort_on_exception = true
      trace "Processing workers"
      @listeners = []
      @workers.each do |worker|
        @listeners << Thread.new do
          begin
            trace "Syncing #{worker.inspect}"
            Sync.new worker, @sync, @verbose
          rescue 
            trace "Syncing failed [#{worker.inspect}]"
            Thread.exit
          end
        end
      end
      
      @listeners.each{|l| l.join}
    end

  end
end
