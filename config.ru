require 'barnes'

Barnes.start

# Must run in a thread: Puma overrides signal handlers after loading config.ru.
# This waits for Puma to finish, then re-traps SIGTERM to delay shutdown.
# Without this, Puma exits immediately and the process dies before the
# platform deregisters the UUID from the metrics endpoint.
Thread.new do
  sleep 2
  trap("TERM") do
    $stderr.puts "SIGTERM received at #{Time.now.utc}, delaying shutdown..."
    sleep 300
    exit
  end
end

run proc { |env| [200, { 'content-type' => 'text/plain' }, ["ok\n"]] }
