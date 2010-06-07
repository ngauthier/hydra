require 'yaml'
module Hydra #:nodoc:
  # Hydra class responsible for delegate work down to workers.
  #
  # The Sync is run once for each remote worker.
  class Sync
    traceable('SYNC')
    self.class.traceable('SYNC MANY')

    attr_reader :connect, :ssh_opts, :remote_dir

    # Create a new Sync instance to rsync source from the local machine to a remote worker
    #
    # Arguments:
    # * :worker_opts
    #   * A hash of the configuration options for a worker.
    # * :sync
    #   * A hash of settings specifically for copying the source directory to be tested
    #     to the remote worked
    # * :verbose
    #   * Set to true to see lots of Hydra output (for debugging)
    def initialize(worker_opts, sync_opts, verbose = false)
      worker_opts ||= {}
      worker_opts.stringify_keys!
      @verbose = verbose
      @connect = worker_opts.fetch('connect') { raise "You must specify an SSH connection target" }
      @ssh_opts = worker_opts.fetch('ssh_opts') { "" }
      @remote_dir = worker_opts.fetch('directory') { raise "You must specify a remote directory" }

      return unless sync_opts
      sync_opts.stringify_keys!
      @local_dir = sync_opts.fetch('directory') { raise "You must specify a synchronization directory" }
      @exclude_paths = sync_opts.fetch('exclude') { [] }

      trace "Initialized"
      trace "  Worker: (#{worker_opts.inspect})"
      trace "  Sync:   (#{sync_opts.inspect})"

      sync
    end

    def sync
      #trace "Synchronizing with #{connect}\n\t#{sync_opts.inspect}"
      exclude_opts = @exclude_paths.inject(''){|memo, path| memo += "--exclude=#{path} "}

      rsync_command = [
        'rsync',
        '-avz',
        '--delete',
        exclude_opts,
        File.expand_path(@local_dir)+'/',
        "-e \"ssh #{@ssh_opts}\"",
        "#{@connect}:#{@remote_dir}"
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
      @sync = opts.fetch('sync') { {} }

      workers_opts = opts.fetch('workers') { [] }
      @remote_worker_opts = []
      workers_opts.each do |worker_opts|
        worker_opts.stringify_keys!
        if worker_opts['type'].to_s == 'ssh'
          @remote_worker_opts << worker_opts
        end
      end

      trace "Initialized"
      trace "  Sync:   (#{@sync.inspect})"
      trace "  Workers: (#{@remote_worker_opts.inspect})"

      Thread.abort_on_exception = true
      trace "Processing workers"
      @listeners = []
      @remote_worker_opts.each do |worker_opts|
        @listeners << Thread.new do
          begin
            trace "Syncing #{worker_opts.inspect}"
            Sync.new worker_opts, @sync, @verbose
          rescue 
            trace "Syncing failed [#{worker_opts.inspect}]"
          end
        end
      end
      
      @listeners.each{|l| l.join}
    end

  end
end
