require 'tmpdir'

class Dir
  def self.consistent_tmpdir
    if RUBY_PLATFORM =~ /darwin/i
      '/tmp' # OS X normally returns a crazy tmpdir, BUT when logged in via SSH, it is '/tmp'. This unifies it.
    else
      Dir.tmpdir
    end
  end
end