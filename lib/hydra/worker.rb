module Hydra #:nodoc:
  # Hydra class responsible to dispatching runners and communicating with the master.
  class Worker
    # Create a new worker.
    # * io: The IO object to use to communicate with the master
    # * num_runners: The number of runners to launch
    def initialize(io, num_runners)
      @io = io
      @runners = []
      @listeners = []
      boot_runners(num_runners)
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
      @runners.each do |r|
        r[:io].write(Hydra::Messages::Runner::Shutdown.new)
        Thread.exit
      end
    end

    private

    def boot_runners(num_runners) #:nodoc:
      num_runners.times do
        pipe = Hydra::Pipe.new
        child = Process.fork do
          pipe.identify_as_child
          Hydra::Runner.new(pipe)
        end
        pipe.identify_as_parent
        @runners << { :pid => child, :io => pipe, :idle => false }
      end
    end

    # Continuously process messages
    def process_messages #:nodoc:
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
            message.handle(self) if message
            @io.write Hydra::Messages::Worker::Ping.new
          rescue IOError => ex
            $stderr.write "Worker lost Master\n"
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
              message.handle(self, r) if message
            rescue IOError => ex
              $stderr.write "Worker lost Runner [#{r.inspect}]\n"
              @runners.delete(r)
              Thread.exit
            end
          end
        end
      end
      @listeners.each{|l| l.join }
      @io.close
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
