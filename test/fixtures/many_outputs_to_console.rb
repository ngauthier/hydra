#!/usr/bin/env ruby

10000.times do 
  $stdout.write "A non-hydra message...\n"
  $stdout.flush
end

$stdout.write "{:class=>Hydra::Messages::TestMessage, :text=>\"My message\"}\n"
$stdout.flush
