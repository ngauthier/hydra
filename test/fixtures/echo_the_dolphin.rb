#!/usr/bin/env ruby
# Echoes back to the sender
$stdout.sync = true
while line = $stdin.gets
  $stdout.write(line)
end

