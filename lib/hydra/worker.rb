module Hydra #:nodoc:
  class Worker
    def initialize(io, num_runners)
      @io = io
      @runners = []
      @listeners = []
      boot_runners(num_runners)
      process_messages
      @runners.each{|r| Process.wait r[:pid] }
    end

    def boot_runners(num_runners)
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

    def process_messages
      @running = true

      Thread.abort_on_exception = true

      # Worker listens and handles messages
      @listeners << Thread.new do
        while @running
          message = @io.gets
          message.handle(self) if message
        end
      end

      # Runners listen, but when they handle they pass themselves
      # so we can reference them when we deal with their messages
      @runners.each do |r|
        @listeners << Thread.new do
          while @running
            message = r[:io].gets
            message.handle(self, r) if message
          end
        end
      end
      @listeners.each{|l| l.join }
    end

    def idle_runner
      idle_r = nil
      while idle_r.nil?
        idle_r = @runners.detect{|r| r[:idle]}
        sleep(1)
      end
      return idle_r
    end

    # message handling methods
    
    def request_file(message, runner)
      @io.write(Hydra::Messages::Worker::RequestFile.new)
      runner[:idle] = true
    end

    def delegate_file(message)
      r = idle_runner
      r[:idle] = false
      r[:io].write(Hydra::Messages::Runner::RunFile.new(eval(message.serialize)))
    end

    def relay_results(message)
      @io.write(Hydra::Messages::Worker::Results.new(eval(message.serialize)))
    end

    def shutdown
      @running = false
      @runners.each do |r|
        r[:io].write(Hydra::Messages::Runner::Shutdown.new)
      end
    end
  end
end
