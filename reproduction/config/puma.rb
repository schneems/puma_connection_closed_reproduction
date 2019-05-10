# drain_on_shutdown

workers 2

pidfile "puma.pid"

puts 'config loaded'

puts "Master pid #{Process.pid}"