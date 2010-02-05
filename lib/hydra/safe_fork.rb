class SafeFork
  def self.fork
    begin
      # remove our connection so it doesn't get cloned
      ActiveRecord::Base.remove_connection if defined?(ActiveRecord)
      # fork a process
      child = Process.fork do
        begin
          # create a new connection and perform the action
          ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
          yield
        ensure
          # make sure we remove the connection before we're done
          ActiveRecord::Base.remove_connection if defined?(ActiveRecord)
        end      
      end
    ensure
      # make sure we re-establish the connection before returning to the main instance
      ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
    end
    return child
  end
end
