require 'hydra/hash'
require 'open3'
require 'tmpdir'
require 'erb'
require 'yaml'

module Hydra #:nodoc:
  # Hydra class responsible for delegate work down to workers.
  #
  # The Master is run once for any given testing session.
  class YmlLoadError < StandardError; end

  class Master
    include Hydra::Messages::Master
    include Open3
    traceable('MASTER')

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
    # * :listeners
    #   * An array of Hydra::Listener objects. See Hydra::Listener::MinimalOutput for an
    #     example listener
    # * :verbose
    #   * Set to true to see lots of Hydra output (for debugging)
    # * :autosort
    #   * Set to false to disable automatic sorting by historical run-time per file
    def initialize(opts = { })
      opts.stringify_keys!
      config_file = opts.delete('config') { nil }
      if config_file

        begin
          config_erb = ERB.new(IO.read(config_file)).result(binding)
        rescue Exception => e
          raise(YmlLoadError,"config file was found, but could not be parsed with ERB.\n#{$!.inspect}")
        end

        begin
          config_yml = YAML::load(config_erb)
        rescue StandardError => e
          raise(YmlLoadError,"config file was found, but could not be parsed.\n#{$!.inspect}")
        end

        opts.merge!(config_yml.stringify_keys!)
      end
      @files = Array(opts.fetch('files') { nil })
      raise "No files, nothing to do" if @files.empty?
      @incomplete_files = @files.dup
      @workers = []
      @listeners = []
      @event_listeners = Array(opts.fetch('listeners') { nil } )
      @event_listeners.select{|l| l.is_a? String}.each do |l|
        @event_listeners.delete_at(@event_listeners.index(l))
        listener = eval(l)
        @event_listeners << listener if listener.is_a?(Hydra::Listener::Abstract)
      end
      @verbose = opts.fetch('verbose') { false }
      @autosort = opts.fetch('autosort') { true }
      @sync = opts.fetch('sync') { nil }
      @environment = opts.fetch('environment') { 'test' }

      if @autosort
        sort_files_from_report
        @event_listeners << Hydra::Listener::ReportGenerator.new(File.new(heuristic_file, 'w'))
      end

      # default is one worker that is configured to use a pipe with one runner
      worker_cfg = opts.fetch('workers') { [ { 'type' => 'local', 'runners' => 1} ] }

      trace "Initialized"
      trace "  Files:   (#{@files.inspect})"
      trace "  Workers: (#{worker_cfg.inspect})"
      trace "  Verbose: (#{@verbose.inspect})"

      @event_listeners.each{|l| l.testing_begin(@files) }

      boot_workers worker_cfg
      process_messages
    end

    # Message handling
    def worker_begin(worker)
      @event_listeners.each {|l| l.worker_begin(worker) }
    end

    # Send a file down to a worker.
    def send_file(worker)
      f = @files.shift
      if f
        trace "Sending #{f.inspect}"
        @event_listeners.each{|l| l.file_begin(f) }
        worker[:io].write(RunFile.new(:file => f))
      else
        trace "No more files to send"
      end
    end

    # Process the results coming back from the worker.
    def process_results(worker, message)
      if message.output =~ /ActiveRecord::StatementInvalid(.*)[Dd]eadlock/ or
         message.output =~ /PGError: ERROR(.*)[Dd]eadlock/ or
         message.output =~ /Mysql::Error: SAVEPOINT(.*)does not exist: ROLLBACK/ or
         message.output =~ /Mysql::Error: Deadlock found/
        trace "Deadlock detected running [#{message.file}]. Will retry at the end"
        @files.push(message.file)
        send_file(worker)
      else
        @incomplete_files.delete_at(@incomplete_files.index(message.file))
        trace "#{@incomplete_files.size} Files Remaining"
        @event_listeners.each{|l| l.file_end(message.file, message.output) }
        if @incomplete_files.empty?
          @workers.each do |worker|
            @event_listeners.each{|l| l.worker_end(worker) }
          end

          shutdown_all_workers
        else
          send_file(worker)
        end
      end
    end

    # A text report of the time it took to run each file
    attr_reader :report_text

    private

    def boot_workers(workers)
      trace "Booting #{workers.size} workers"
      workers.each do |worker|
        worker.stringify_keys!
        trace "worker opts #{worker.inspect}"
        type = worker.fetch('type') { 'local' }
        if type.to_s == 'local'
          boot_local_worker(worker)
        elsif type.to_s == 'ssh'
          @workers << worker # will boot later, during the listening phase
        else
          raise "Worker type not recognized: (#{type.to_s})"
        end
      end
    end

    def boot_local_worker(worker)
      runners = worker.fetch('runners') { raise "You must specify the number of runners" }
      trace "Booting local worker"
      pipe = Hydra::Pipe.new
      child = SafeFork.fork do
        pipe.identify_as_child
        Hydra::Worker.new(:io => pipe, :runners => runners, :verbose => @verbose)
      end

      pipe.identify_as_parent
      @workers << { :pid => child, :io => pipe, :idle => false, :type => :local }
    end

    def boot_ssh_worker(worker)
      sync = Sync.new(worker, @sync, @verbose)

      runners = worker.fetch('runners') { raise "You must specify the number of runners"  }
      command = worker.fetch('command') {
        "RAILS_ENV=#{@environment} ruby -e \"require 'rubygems'; require 'hydra'; Hydra::Worker.new(:io => Hydra::Stdio.new, :runners => #{runners}, :verbose => #{@verbose});\""
      }

      trace "Booting SSH worker"
      ssh = Hydra::SSH.new("#{sync.ssh_opts} #{sync.connect}", sync.remote_dir, command)
      return { :io => ssh, :idle => false, :type => :ssh, :connect => sync.connect }
    end

    def shutdown_all_workers
      trace "Shutting down all workers"
      @workers.each do |worker|
        worker[:io].write(Shutdown.new) if worker[:io]
        worker[:io].close if worker[:io]
      end
      @listeners.each{|t| t.exit}
    end

    def process_messages
      Thread.abort_on_exception = true

      trace "Processing Messages"
      trace "Workers: #{@workers.inspect}"
      @workers.each do |worker|
        @listeners << Thread.new do
          trace "Listening to #{worker.inspect}"
           if worker.fetch('type') { 'local' }.to_s == 'ssh'
             worker = boot_ssh_worker(worker)
             @workers << worker
           end
          while true
            begin
              message = worker[:io].gets
              trace "got message: #{message}"
              # if it exists and its for me.
              # SSH gives us back echoes, so we need to ignore our own messages
              if message and !message.class.to_s.index("Worker").nil?
                message.handle(self, worker)
              end
            rescue IOError
              trace "lost Worker [#{worker.inspect}]"
              Thread.exit
            end
          end
        end
      end

      @listeners.each{|l| l.join}
      @event_listeners.each{|l| l.testing_end}
    end

    def sort_files_from_report
      if File.exists? heuristic_file
        report = YAML.load_file(heuristic_file)
        return unless report
        sorted_files = report.sort{ |a,b|
          b[1]['duration'] <=> a[1]['duration']
        }.collect{|tuple| tuple[0]}

        sorted_files.each do |f|
          @files.push(@files.delete_at(@files.index(f))) if @files.index(f)
        end
      end
    end

    def heuristic_file
      @heuristic_file ||= File.join(Dir.tmpdir, 'hydra_heuristics.yml')
    end
  end
end
