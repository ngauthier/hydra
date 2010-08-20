#!/usr/bin/env ruby
if File.expand_path($0) == File.expand_path(__FILE__)
  require 'rubygems'
  require 'hydra'
  
  @files = ARGV.inject([]){|memo,f| memo += Dir.glob f}
  
  if @files.empty?
    puts "You must specify a list of files to run"
    puts "If you specify a pattern, it must be in quotes"
    puts %{USAGE: #{$0} test/unit/my_test.rb "test/functional/**/*_test.rb"}
    exit(1)
  end
  
  Signal.trap("TERM", "KILL") do
    puts "Warm Snake says bye bye"
    exit(0)
  end
  
  bold_yellow = "\033[1;33m"
  reset = "\033[0m"
  
  
  loop do
    env_proc = Process.fork do
      puts "#{bold_yellow}Booting Environment#{reset}"
      start = Time.now
      ENV['RAILS_ENV']='test'
      require 'config/environment'
      require 'test/test_helper'
      finish = Time.now
      puts "#{bold_yellow}Environment Booted (#{finish-start})#{reset}"
  
      loop do
        puts "#{bold_yellow}Running#{reset} [#{@files.inspect}]"
        start = Time.now
        Hydra::Master.new(
          :files => @files.dup,
          :listeners => Hydra::Listener::ProgressBar.new(STDOUT),
          :workers => [{:type => :local, :runners => 4}]
        )
        finish = Time.now
        puts "#{bold_yellow}Tests finished#{reset} (#{finish-start})"
        
        puts ""
  
        $stdout.write "Press #{bold_yellow}ENTER#{reset} to retest. Type #{bold_yellow}r#{reset} then hit enter to reboot environment. #{bold_yellow}CTRL-C#{reset} to quit\n> "
        begin
          command = $stdin.gets
        rescue Interrupt
          exit(0)
        end
        break if !command.nil? and command.chomp == "r"
      end
    end
    begin
      Process.wait env_proc
    rescue Interrupt
      puts "\n#{bold_yellow}SSsssSsssSSssSs#{reset}"
      break
    end
  end
end

