require 'json'
threads = []

out = `heroku info --json`

raise "command `heroku info` failed: #{out}" unless $?.success?

web_url = JSON.parse(out)["app"]["web_url"]


puts "Detected web url as: #{web_url}"

8.times do |i|
  threads << Thread.new do
    request = `curl #{web_url}?request_thread=#{i} &> requests#{i}.log`
    # request = `curl localhost:9292`
    # puts request if ~request.include?('A barebones rack app')
    puts $?
  end
end



threads.map {|t| t.join }


# `curl localhost:9292`