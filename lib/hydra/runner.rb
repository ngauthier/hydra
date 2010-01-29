module Hydra #:nodoc:
  # Hydra class responsible for running test files.
  #
  # The Runner is never run directly by a user. Runners are created by a
  # Worker to run test files.
  #
  # The general convention is to have one Runner for each logical processor
  # of a machine.
  class Runner
    include Hydra::Messages::Runner
    # Boot up a runner. It takes an IO object (generally a pipe from its
    # parent) to send it messages on which files to execute.
    def initialize(opts = {})
      @io = opts.fetch(:io) { raise "No IO Object" } 
      @verbose = opts.fetch(:verbose) { false }

      Test::Unit.run = true

      @io.write RequestFile.new
      process_messages
    end

    # Run a test file and report the results
    def run_file(file)
      require file
      output = []
      @result = Test::Unit::TestResult.new
      @result.add_listener(Test::Unit::TestResult::FAULT) do |value|
        output << value
      end

      klasses = Runner.find_classes_in_file(file)
      begin
        klasses.each{|klass| klass.suite.run(@result){|status, name| ;}}
      rescue => ex
        output << ex.to_s
      end

      output << '.' if output.empty?

      @io.write Results.new(:output => output.join("\n"), :file => file)
    end

    # Stop running
    def stop
      @running = false
    end

    private

    # The runner will continually read messages and handle them.
    def process_messages
      $stdout.write "RUNNER| Processing Messages\n" if @verbose
      @running = true
      while @running
        begin
          message = @io.gets
          if message
            $stdout.write "RUNNER| Received message from worker\n" if @verbose
            $stdout.write "      | #{message.inspect}\n" if @verbose
            message.handle(self)
          else
            @io.write Ping.new
          end
        rescue IOError => ex
          $stderr.write "Runner lost Worker\n" if @verbose
          @running = false
        end
      end
    end

    def self.find_classes_in_file(f)
      code = ""
      File.open(f) {|buffer| code = buffer.read}
      matches = code.scan(/class\s+([\S]+)/)
      klasses = matches.collect do |c|
        begin
          if c.first.respond_to? :constantize
            c.first.constantize
          else
            eval(c.first)
          end
        rescue NameError
          # $stderr.write "Could not load [#{c.first}] from [#{f}]\n"
          nil
        rescue SyntaxError
          # $stderr.write "Could not load [#{c.first}] from [#{f}]\n"
          nil
        end
      end
      return klasses.select{|k| k.respond_to? 'suite'}
    end
  end
end
