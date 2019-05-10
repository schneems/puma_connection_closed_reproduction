app = Proc.new do |env|
  sleep Float(ENV["EXAMPLE_SLEEP_TIME"] || 0 )
  # raise Exception#, 'hello'

  current_pid = Process.pid
  signal      = "SIGKILL"
  Process.kill(signal, current_pid)
  ['200', {'Content-Type' => 'text/html'}, ['A barebones rack app.']]
end

run app