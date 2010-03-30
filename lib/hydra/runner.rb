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
    # Boot up a runner. It takes an IO object (generally a pipe from its
    # parent) to send it messages on which files to execute.
    def initialize(opts = {})
      @io = opts.fetch(:io) { raise "No IO Object" } 
      @verbose = opts.fetch(:verbose) { false }      
      $stdout.sync = true
      trace 'Booted. Sending Request for file'

      @io.write RequestFile.new
      begin
        process_messages
      rescue => ex
        trace ex.to_s
        raise ex
      end
    end

    # Run a test file and report the results
    def run_file(file)
      trace "Running file: #{file}"

      output = ""
      if file =~ /.rb$/
        output = run_ruby_file(file)
      elsif file =~ /.feature$/
        output = run_cucumber_file(file)
      end

      output = "." if output == ""

      @io.write Results.new(:output => output, :file => file)
    end

    # Stop running
    def stop
      @running = false
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
          @running = false
        end
      end
    end

    # Run a ruby file (ending in .rb)
    def run_ruby_file(file)
      run_test_unit_file(file) + run_rspec_file(file)
    end

    # Run all the Test::Unit Suites in a ruby file
    def run_test_unit_file(file)
      begin
        require file
      rescue LoadError => ex
        trace "#{file} does not exist [#{ex.to_s}]"
        return ex.to_s
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
        output << ex.to_s
      end

      return output.join("\n")
    end

    # run all the Specs in an RSpec file (NOT IMPLEMENTED)
    def run_rspec_file(file)
      #TODO
      # Given the file
      # return "" if all the tests passed
      # or return the error messages for the entire file
      return ""
    end

    # run all the scenarios in a cucumber feature file
    def run_cucumber_file(file)
      require 'cucumber'
      require 'cucumber/formatter/progress'
      require 'hydra/cucumber/formatter'
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

      files = [file]
      dev_null = StringIO.new

      options = Cucumber::Cli::Options.new
      configuration = Cucumber::Cli::Configuration.new(dev_null, dev_null)
      configuration.parse!([]+files)
      step_mother = Cucumber::StepMother.new

      step_mother.options = configuration.options
      step_mother.log = configuration.log
      step_mother.load_code_files(configuration.support_to_load)
      step_mother.after_configuration(configuration)
      features = step_mother.load_plain_text_features(files)
      step_mother.load_code_files(configuration.step_defs_to_load)

      tag_excess = tag_excess(features, configuration.options[:tag_expression].limits)
      configuration.options[:tag_excess] = tag_excess

      hydra_response = StringIO.new
      formatter = Cucumber::Formatter::Hydra.new(
        step_mother, hydra_response, configuration.options
      )

      runner = Cucumber::Ast::TreeWalker.new(
        step_mother, [formatter], configuration.options, dev_null
      )
      step_mother.visitor = runner
      runner.visit_features(features)

      hydra_response.rewind
      return hydra_response.read
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
  end
end
