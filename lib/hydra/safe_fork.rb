class SafeFork
  def self.fork
    begin
      # remove our connection so it doesn't get cloned
      connection = ActiveRecord::Base.remove_connection if defined?(ActiveRecord)
      # fork a process
      child = Process.fork do
        begin
          # create a new connection and perform the action
          begin
          ActiveRecord::Base.establish_connection((connection || {}).merge({:allow_concurrency => true})) if defined?(ActiveRecord)
          rescue ActiveRecord::AdapterNotSpecified
            # AR was defined but we didn't have a connection
          end
          yield
        ensure
          # make sure we remove the connection before we're done
          ActiveRecord::Base.remove_connection if defined?(ActiveRecord)
        end      
      end
    ensure
      # make sure we re-establish the connection before returning to the main instance
      begin
        ActiveRecord::Base.establish_connection((connection || {}).merge({:allow_concurrency => true})) if defined?(ActiveRecord)
      rescue ActiveRecord::AdapterNotSpecified
        # AR was defined but we didn't have a connection
      end
    end
    return child
  end
end
