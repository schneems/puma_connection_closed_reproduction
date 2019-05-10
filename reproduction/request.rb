# $ kill -s SIGTERM 51240

threads = []

threads << Thread.new do
  puts `puma > puma.log` unless ENV["NO_PUMA_BOOT"]
end

sleep(3)
require 'fileutils'
FileUtils.mkdir_p("tmp/requests")

20.times do |i|
  threads << Thread.new do
    request = `curl localhost:9292/?request_thread=#{i} &> tmp/requests/requests#{i}.log`
    # request = `curl localhost:9292`
    # puts request if ~request.include?('A barebones rack app')
    puts $?
  end
end

threads.map {|t| t.join }


# `curl localhost:9292`