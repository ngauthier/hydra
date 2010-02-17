require 'open3'
module Hydra #:nodoc:
  # Hydra Task Common attributes and methods
  class Task
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

    # Set to true if you want hydra to generate a report.
    # Defaults to fals
    attr_accessor :report
    #
    # Search for the hydra config file
    def find_config_file
      @config ||= 'hydra.yml'
      return @config if File.exists?(@config)
      @config = File.join('config', 'hydra.yml')
      return @config if File.exists?(@config)
      @config = nil
    end
    
    # Add files to test by passing in a string to be run through Dir.glob.
    # For example:
    #
    #   t.add_files 'test/units/*.rb'
    def add_files(pattern)
      @files += Dir.glob(pattern)
    end

  end

  # Define a test task that uses hydra to test the files.
  #
  #   Hydra::TestTask.new('hydra') do |t|
  #     t.add_files 'test/unit/**/*_test.rb'
  #     t.add_files 'test/functional/**/*_test.rb'
  #     t.add_files 'test/integration/**/*_test.rb'
  #     t.verbose = false # optionally set to true for lots of debug messages
  #     t.report = true # optionally set to true for a final report of test times
  #   end  
  class TestTask < Hydra::Task

    # Create a new HydraTestTask
    def initialize(name = :hydra)
      @name = name
      @files = []
      @verbose = false
      @report = false

      yield self if block_given?

      @config = find_config_file

      @opts = {
        :verbose => @verbose,
        :report => @report,
        :files => @files
      }
      if @config
        @opts.merge!(:config => @config)
      else
        @opts.merge!(:workers => [{:type => :local, :runners => 1}])
      end

      define
    end

    private
    # Create the rake task defined by this HydraTestTask
    def define
      desc "Hydra Tests" + (@name == :hydra ? "" : " for #{@name}")
      task @name do
        $stdout.write "Hydra Testing #{files.inspect}\n"
        h = Hydra::Master.new(@opts)
        $stdout.write h.report_text if @report
        $stdout.write "\nHydra Completed\n"
        exit(0) #bypass test on_exit output
      end
    end
  end

  # Setup a task that will be run across all remote workers
  #   Hydra::RemoteTask.new('db:reset')
  #
  # Then you can run:
  #   rake hydra:remote:db:reset
  class RemoteTask < Hydra::Task
    include Open3
    # Create a new hydra remote task with the given name.
    # The task will be named hydra:remote:<name>
    def initialize(name)
      @name = name
      yield self if block_given?
      @config = find_config_file
      if @config
        define
      else
        task "hydra:remote:#{@name}" do ; end
      end
    end

    private
    def define
      desc "Run #{@name} remotely on all workers"
      task "hydra:remote:#{@name}" do
        config = YAML.load_file(@config)
        workers = config.fetch('workers') { [] }
        workers = workers.select{|w| w['type'] == 'ssh'}
        workers.each do |worker|
          $stdout.write "==== Hydra Running #{@name} on #{worker['connect']} ====\n"
          ssh_opts = worker.fetch('ssh_opts') { '' }
          writer, reader, error = popen3("ssh -tt #{ssh_opts} #{worker['connect']} ")
          writer.write("cd #{worker['directory']}\n")
          writer.write "echo BEGIN HYDRA\n"
          writer.write("RAILS_ENV=test rake #{@name}\n")
          writer.write "echo END HYDRA\n"
          writer.write("exit\n")
          writer.close
          ignoring = true
          while line = reader.gets
            line.chomp!
            if line =~ /echo END HYDRA$/
              ignoring = true
            end
            $stdout.write "#{line}\n" unless ignoring
            if line == 'BEGIN HYDRA'
              ignoring = false
            end
          end
          $stdout.write "\n==== Hydra Running #{@name} COMPLETE ====\n\n"
        end
      end
    end
  end

  # A Hydra global task is a task that is run both locally and remotely.
  #
  # For example:
  #
  #   Hydra::GlobalTask.new('db:reset')
  #
  # Allows you to run:
  #   
  #   rake hydra:db:reset
  #
  # Then, db:reset will be run locally and on all remote workers. This
  # makes it easy to setup your workers and run tasks all in a row.
  #
  # For example:
  #
  #   rake hydra:db:reset hydra:factories hydra:tests
  #
  # Assuming you setup hydra:db:reset and hydra:db:factories as global
  # tasks and hydra:tests as a Hydra::TestTask for all your tests
  class GlobalTask < Hydra::Task
    def initialize(name)
      @name = name
      define
    end

    private
    def define
      Hydra::RemoteTask.new(@name)
      desc "Run #{@name.to_s} Locally and Remotely across all Workers"
      task "hydra:#{@name.to_s}" => [@name.to_s, "hydra:remote:#{@name.to_s}"] 
    end
  end
end
