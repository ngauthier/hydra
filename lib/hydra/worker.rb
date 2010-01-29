module Hydra #:nodoc:
  # Hydra class responsible to dispatching runners and communicating with the master.
  #
  # The Worker is never run directly by a user. Workers are created by a
  # Master to delegate to Runners.
  #
  # The general convention is to have one Worker per machine on a distributed
  # network.
  class Worker
    # Create a new worker.
    # * io: The IO object to use to communicate with the master
    # * num_runners: The number of runners to launch
    # TODO: options hash
    def initialize(opts = {})
      @verbose = opts.fetch(:verbose) { false }
      @io = opts.fetch(:io) { raise "No IO Object" }
      @runners = []
      @listeners = []

      boot_runners(opts.fetch(:runners) { 1 })
      process_messages
      
      @runners.each{|r| Process.wait r[:pid] }
    end


    # message handling methods
    
    # When a runner wants a file, it hits this method with a message.
    # Then the worker bubbles the file request up to the master.
    def request_file(message, runner)
      @io.write(Hydra::Messages::Worker::RequestFile.new)
      runner[:idle] = true
    end

    # When the master sends a file down to the worker, it hits this
    # method. Then the worker delegates the file down to a runner.
    def delegate_file(message)
      r = idle_runner
      r[:idle] = false
      r[:io].write(Hydra::Messages::Runner::RunFile.new(eval(message.serialize)))
    end

    # When a runner finishes, it sends the results up to the worker. Then the
    # worker sends the results up to the master.
    # TODO: when we relay results, it should trigger a RunFile or Shutdown from
    # the master implicitly
    def relay_results(message, runner)
      runner[:idle] = true
      @io.write(Hydra::Messages::Worker::Results.new(eval(message.serialize)))
    end

    # When a master issues a shutdown order, it hits this method, which causes
    # the worker to send shutdown messages to its runners.
    # TODO: implement a ShutdownComplete message, so that we can kill the
    # processes if necessary.
    def shutdown
      @running = false
      $stdout.write "WORKER| Notifying #{@runners.size} Runners of Shutdown\n" if @verbose
      @runners.each do |r|
        $stdout.write "WORKER| Sending Shutdown to Runner\n" if @verbose
        $stdout.write "      | #{r.inspect}\n" if @verbose
        r[:io].write(Hydra::Messages::Runner::Shutdown.new)
      end
      Thread.exit
    end

    private

    def boot_runners(num_runners) #:nodoc:
      $stdout.write "WORKER| Booting #{num_runners} Runners\n" if @verbose
      num_runners.times do
        pipe = Hydra::Pipe.new
        child = Process.fork do
          pipe.identify_as_child
          Hydra::Runner.new(:io => pipe, :verbose => @verbose)
        end
        pipe.identify_as_parent
        @runners << { :pid => child, :io => pipe, :idle => false }
      end
      $stdout.write "WORKER| #{@runners.size} Runners booted\n" if @verbose
    end

    # Continuously process messages
    def process_messages #:nodoc:
      $stdout.write "WORKER| Processing Messages\n" if @verbose
      @running = true

      # Abort the worker if one of the runners has an exception
      # TODO: catch this exception, return a dying message to the master
      # then shutdown
      Thread.abort_on_exception = true

      # Worker listens and handles messages
      @listeners << Thread.new do
        while @running
          begin
            message = @io.gets
            if message
              $stdout.write "WORKER| Received Message from Master\n" if @verbose 
              $stdout.write "      | #{message.inspect}\n" if @verbose
              message.handle(self)
            else
              @io.write Hydra::Messages::Worker::Ping.new
            end
          rescue IOError => ex
            $stderr.write "Worker lost Master\n" if @verbose
            Thread.exit
          end
        end
      end

      # Runners listen, but when they handle they pass themselves
      # so we can reference them when we deal with their messages
      @runners.each do |r|
        @listeners << Thread.new do
          while @running
            begin
              message = r[:io].gets
              if message
                $stdout.write "WORKER| Received Message from Runner\n" if @verbose
                $stdout.write "      | #{message.inspect}\n" if @verbose
                message.handle(self, r)
              end
            rescue IOError => ex
              $stderr.write "Worker lost Runner [#{r.inspect}]\n"
              Thread.exit
            end
          end
        end
      end
      @listeners.each{|l| l.join }
      @io.close
      $stdout.write "WORKER| Done processing messages\n" if @verbose
    end

    # Get the next idle runner
    def idle_runner #:nodoc:
      idle_r = nil
      while idle_r.nil?
        idle_r = @runners.detect{|r| r[:idle]}
        sleep(1)
      end
      return idle_r
    end
  end
end
