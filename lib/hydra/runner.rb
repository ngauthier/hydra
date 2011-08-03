require 'test/unit'
require 'test/unit/testresult'
Test::Unit.run = true

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
    traceable('RUNNER')

    DEFAULT_LOG_FILE = 'hydra-runner.log'

    # Boot up a runner. It takes an IO object (generally a pipe from its
    # parent) to send it messages on which files to execute.
    def initialize(opts = {})
      redirect_output( opts.fetch( :runner_log_file ) { DEFAULT_LOG_FILE } )
      reg_trap_sighup

      @io = opts.fetch(:io) { raise "No IO Object" }
      @verbose = opts.fetch(:verbose) { false }
      @event_listeners = Array( opts.fetch( :runner_listeners ) { nil } )
      @options = opts.fetch(:options)

      $stdout.sync = true
      runner_begin

      trace 'Booted. Sending Request for file'
      @io.write RequestFile.new
      begin
        process_messages
      rescue => ex
        trace ex.to_s
        raise ex
      end
    end

    def reg_trap_sighup
      for sign in [:SIGHUP, :INT]
        trap sign do
          stop
        end
      end
      @runner_began = true
    end

    def runner_begin
      trace "Firing runner_begin event"
      @event_listeners.each {|l| l.runner_begin( self ) }
    end

    # Run a test file and report the results
    def run_file(file)
      trace "Running file: #{file}"

      output = ""
      if file =~ /_spec.rb$/i
        output = run_rspec_file(file)
      elsif file =~ /.feature$/i
        output = run_cucumber_file(file)
      elsif file =~ /.js$/i or file =~ /.json$/i
        output = run_javascript_file(file)
      else
        output = run_test_unit_file(file)
      end

      output = "." if output == ""

      @io.write Results.new(:output => output, :file => file)
      return output
    end

    # Stop running
    def stop
      runner_end if @runner_began
      @runner_began = @running = false
    end

    def runner_end
      trace "Ending runner #{self.inspect}"
      @event_listeners.each {|l| l.runner_end( self ) }
    end

    def format_exception(ex)
      "#{ex.class.name}: #{ex.message}\n    #{ex.backtrace.join("\n    ")}"
    end

    private

    # The runner will continually read messages and handle them.
    def process_messages
      trace "Processing Messages"
      @running = true
      while @running
        begin
          message = @io.gets
          if message and !message.class.to_s.index("Worker").nil?
            trace "Received message from worker"
            trace "\t#{message.inspect}"
            message.handle(self)
          else
            @io.write Ping.new
          end
        rescue IOError => ex
          trace "Runner lost Worker"
          stop
        end
      end
    end

    def format_ex_in_file(file, ex)
      "Error in #{file}:\n  #{format_exception(ex)}"
    end

    # Run all the Test::Unit Suites in a ruby file
    def run_test_unit_file(file)
      begin
        require file
      rescue LoadError => ex
        trace "#{file} does not exist [#{ex.to_s}]"
        return ex.to_s
      rescue Exception => ex
        trace "Error requiring #{file} [#{ex.to_s}]"
        return format_ex_in_file(file, ex)
      end
      output = []
      @result = Test::Unit::TestResult.new
      @result.add_listener(Test::Unit::TestResult::FAULT) do |value|
        output << value
      end

      klasses = Runner.find_classes_in_file(file)
      begin
        klasses.each{|klass| klass.suite.run(@result){|status, name| ;}}
      rescue => ex
        output << format_ex_in_file(file, ex)
      end

      return output.join("\n")
    end

    # run all the Specs in an RSpec file (NOT IMPLEMENTED)
    def run_rspec_file(file)
      # pull in rspec
      begin
        require 'rspec'
        require 'hydra/spec/hydra_formatter'
        # Ensure we override rspec's at_exit
        RSpec::Core::Runner.disable_autorun!
      rescue LoadError => ex
        return ex.to_s
      end
      hydra_output = StringIO.new

      config = [
        '-f', 'RSpec::Core::Formatters::HydraFormatter',
        file
      ]

      RSpec.instance_variable_set(:@world, nil)
      RSpec::Core::Runner.run(config, hydra_output, hydra_output)

      hydra_output.rewind
      output = hydra_output.read.chomp
      output = "" if output.gsub("\n","") =~ /^\.*$/

      return output
    end

    # run all the scenarios in a cucumber feature file
    def run_cucumber_file(file)
      hydra_response = StringIO.new

      options = @options if @options.is_a?(Array)
      options = @options.split(' ') if @options.is_a?(String)

      fork_id = fork do
        files = [file]
        dev_null = StringIO.new

        args = [file, options].flatten.compact
        hydra_response.puts args.inspect

        results_directory = "#{Dir.pwd}/results/features"
        FileUtils.mkdir_p results_directory

        require 'cucumber/cli/main'
        require 'hydra/cucumber/formatter'
        require 'hydra/cucumber/partial_html'

        Cucumber.logger.level = Logger::INFO

        cuke = Cucumber::Cli::Main.new(args, dev_null, dev_null)
        cuke.configuration.formats << ['Cucumber::Formatter::Hydra', hydra_response]

        html_output = cuke.configuration.formats.select{|format| format[0] == 'html'}
        if html_output
          cuke.configuration.formats.delete(html_output)
          cuke.configuration.formats << ['Hydra::Formatter::PartialHtml', "#{results_directory}/#{file.split('/').last}.html"]
        end

        cuke_runtime = Cucumber::Runtime.new(cuke.configuration)
        cuke_runtime.run!
        exit 1 if cuke_runtime.results.failure?
      end
      Process.wait fork_id

      hydra_response.puts "." if not $?.exitstatus == 0
      hydra_response.rewind

      hydra_response.read
    end

    def run_javascript_file(file)
      errors = []
      require 'v8'
      V8::Context.new do |context|
        context.load(File.expand_path(File.join(File.dirname(__FILE__), 'js', 'lint.js')))
        context['input'] = lambda{
          File.read(file)
        }
        context['reportErrors'] = lambda{|js_errors|
          js_errors.each do |e|
            e = V8::To.rb(e)
            errors << "\n\e[1;31mJSLINT: #{file}\e[0m"
            errors << "  Error at line #{e['line'].to_i + 1} " + 
              "character #{e['character'].to_i + 1}: \e[1;33m#{e['reason']}\e[0m"
            errors << "#{e['evidence']}"
          end
        }
        context.eval %{
          JSLINT(input(), {
            sub: true,
            onevar: true,
            eqeqeq: true,
            plusplus: true,
            bitwise: true,
            regexp: true,
            newcap: true,
            immed: true,
            strict: true,
            rhino: true
          });
          reportErrors(JSLINT.errors);
        }
      end

      if errors.empty?
        return '.'
      else
        return errors.join("\n")
      end
    end

    # find all the test unit classes in a given file, so we can run their suites
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
          # means we could not load [c.first], but thats ok, its just not
          # one of the classes we want to test
          nil
        rescue SyntaxError
          # see above
          nil
        end
      end
      return klasses.select{|k| k.respond_to? 'suite'}
    end

    # Yanked a method from Cucumber
    def tag_excess(features, limits)
      limits.map do |tag_name, tag_limit|
        tag_locations = features.tag_locations(tag_name)
        if tag_limit && (tag_locations.length > tag_limit)
          [tag_name, tag_limit, tag_locations]
        else
          nil
        end
      end.compact
    end

    def redirect_output file_name
      begin
        $stderr = $stdout =  File.open(file_name, 'a')
      rescue
        # it should always redirect output in order to handle unexpected interruption
        # successfully
        $stderr = $stdout =  File.open(DEFAULT_LOG_FILE, 'a')
      end
    end
  end
end

