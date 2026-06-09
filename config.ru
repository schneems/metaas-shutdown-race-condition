require 'barnes'

Barnes.start

trap("TERM") do
  $stderr.puts "SIGTERM received at #{Time.now.utc}, delaying shutdown..."
  sleep 300
  exit
end

run proc { |env| [200, { 'content-type' => 'text/plain' }, ["ok\n"]] }
