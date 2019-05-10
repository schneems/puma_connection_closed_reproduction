app = Proc.new do |env|
  sleep Float(ENV["EXAMPLE_SLEEP_TIME"] || 0 )

  puma_pid = File.read('puma.pid').to_i
  Process.kill("SIGTERM", puma_pid)
  Process.kill("SIGTERM", Process.pid)

  ['200', {'Content-Type' => 'text/html'}, ['A barebones rack app.']]
end

run app