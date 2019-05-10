pid = fork do
  while true
    sleep(1)
  end
end

puts pid.inspect

# Process.kill("SIGTERM", pid)
Process.waitpid(pid,  Process::WNOHANG)
