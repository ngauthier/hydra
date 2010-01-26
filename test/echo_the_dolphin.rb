#!/usr/bin/env ruby
# read lines from stdin
# echo each line back
# on EOF, quit nicely

$stdout.sync = true

while line = $stdin.gets
  $stdout.write(line)
end

