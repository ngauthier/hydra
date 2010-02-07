module Hydra #:nodoc:
  # Define a test task that uses hydra to test the files.
  #
  # TODO: examples
  class TestTask
    # Name of the task. Default 'hydra'
    attr_accessor :name

    # Files to test.
    # You can add files manually via:
    #   t.files << [file1, file2, etc]
    #
    # Or you can use the add_files method
    attr_accessor :files

    # True if you want to see Hydra's message traces
    attr_accessor :verbose

    # Path to the hydra config file.
    # If not set, it will check 'hydra.yml' and 'config/hydra.yml'
    attr_accessor :config

    # Create a new HydraTestTask
    def initialize(name = :hydra)
      @name = name
      @files = []
      @verbose = false

      yield self if block_given?

      @config = find_config_file

      @opts = {
        :verbose => @verbose,
        :files => @files
      }
      if @config
        @opts.merge!(:config => @config)
      else
        $stderr.write "Hydra: No configuration file found at 'hydra.yml' or 'config/hydra.yml'\n"
        $stderr.write "Hydra: Using default configuration for a single-core machine\n"
        @opts.merge!(:workers => [{:type => :local, :runners => 1}])
      end

      define
    end

    # Create the rake task defined by this HydraTestTask
    def define
      desc "Hydra Tests" + (@name == :hydra ? "" : " for #{@name}")
      task @name do
        $stdout.write "Hydra Testing #{files.inspect}\n"
        Hydra::Master.new(@opts)
        $stdout.write "\nHydra Completed\n"
        exit(0) #bypass test on_exit output
      end
    end

    # Add files to test by passing in a string to be run through Dir.glob.
    # For example:
    #
    #   t.add_files 'test/units/*.rb'
    def add_files(pattern)
      @files += Dir.glob(pattern)
    end

    # Search for the hydra config file
    def find_config_file
      @config ||= 'hydra.yml'
      return @config if File.exists?(@config)
      @config = File.join('config', 'hydra.yml')
      return @config if File.exists?(@config)
      @config = nil
    end
  end
end
