module Hydra #:nodoc:
  # Hydra class responsible to dispatching runners and communicating with the master.
  #
  # The Worker is never run directly by a user. Workers are created by a
  # Master to delegate to Runners.
  #
  # The general convention is to have one Worker per machine on a distributed
  # network.
  class Worker
    include Hydra::Messages::Worker
    traceable('WORKER')

    attr_reader :runners
    # Create a new worker.
    # * io: The IO object to use to communicate with the master
    # * num_runners: The number of runners to launch
    def initialize(opts = {})
      @verbose = opts.fetch(:verbose) { false }
      @io = opts.fetch(:io) { raise "No IO Object" }
      @runners = []
      @listeners = []
      @options = opts.fetch(:options)

      load_worker_initializer

      @runner_event_listeners = Array(opts.fetch(:runner_listeners) { nil })
      @runner_event_listeners.select{|l| l.is_a? String}.each do |l|
        @runner_event_listeners.delete_at(@runner_event_listeners.index(l))
        listener = eval(l)
        @runner_event_listeners << listener if listener.is_a?(Hydra::RunnerListener::Abstract)
      end
      @runner_log_file = opts.fetch(:runner_log_file) { nil }

      boot_runners(opts.fetch(:runners) { 1 })
      @io.write(Hydra::Messages::Worker::WorkerBegin.new)

      process_messages

      @runners.each{|r| Process.wait r[:pid] }
    end

    def load_worker_initializer
      if File.exist?('./hydra_worker_init.rb')
        trace('Requiring hydra_worker_init.rb')
        require 'hydra_worker_init'
      else
        trace('hydra_worker_init.rb not present')
      end
    end
    
    # message handling methods

    # When a runner wants a file, it hits this method with a message.
    # Then the worker bubbles the file request up to the master.
    def request_file(message, runner)
      @io.write(RequestFile.new)
      runner[:idle] = true
    end

    # When the master sends a file down to the worker, it hits this
    # method. Then the worker delegates the file down to a runner.
    def delegate_file(message)
      runner = idle_runner
      runner[:idle] = false
      runner[:io].write(RunFile.new(eval(message.serialize)))
    end

    # When a runner finishes, it sends the results up to the worker. Then the
    # worker sends the results up to the master.
    def relay_results(message, runner)
      runner[:idle] = true
      @io.write(Results.new(eval(message.serialize)))
    end

    # When a master issues a shutdown order, it hits this method, which causes
    # the worker to send shutdown messages to its runners.
    def shutdown
      @running = false
      trace "Notifying #{@runners.size} Runners of Shutdown"
      @runners.each do |r|
        trace "Sending Shutdown to Runner"
        trace "\t#{r.inspect}"
        r[:io].write(Shutdown.new)
      end
      Thread.exit
    end

    private

    def boot_runners(num_runners) #:nodoc:
      trace "Booting #{num_runners} Runners"
      num_runners.times do
        pipe = Hydra::Pipe.new

        child = SafeFork.fork do
          pipe.identify_as_child
          Hydra::Runner.new(:io => pipe, :verbose => @verbose, :runner_listeners => @runner_event_listeners, :runner_log_file => @runner_log_file, :options => @options)
        end
        pipe.identify_as_parent
        @runners << { :pid => child, :io => pipe, :idle => false }
      end
      trace "#{@runners.size} Runners booted"
    end

    # Continuously process messages
    def process_messages #:nodoc:
      trace "Processing Messages"
      @running = true

      Thread.abort_on_exception = true

      process_messages_from_master
      process_messages_from_runners

      @listeners.each{|l| l.join }
      @io.close
      trace "Done processing messages"
    end

    def process_messages_from_master
      @listeners << Thread.new do
        while @running
          begin
            message = @io.gets
            if message and !message.class.to_s.index("Master").nil?
              trace "Received Message from Master"
              trace "\t#{message.inspect}"
              message.handle(self)
            else
              trace "Nothing from Master, Pinging"
              @io.write Ping.new
            end
          rescue IOError => ex
            trace "Worker lost Master"
            shutdown
          end
        end
      end
    end

    def process_messages_from_runners
      @runners.each do |r|
        @listeners << Thread.new do
          while @running
            begin
              message = r[:io].gets
              if message and !message.class.to_s.index("Runner").nil?
                trace "Received Message from Runner"
                trace "\t#{message.inspect}"
                message.handle(self, r)
              end
            rescue IOError => ex
              trace "Worker lost Runner [#{r.inspect}]"
              Thread.exit
            end
          end
        end
      end
    end

    # Get the next idle runner
    def idle_runner #:nodoc:
      idle_r = nil
      while idle_r.nil?
        idle_r = @runners.detect{|runner| runner[:idle]}
      end
      return idle_r
    end
  end
end
