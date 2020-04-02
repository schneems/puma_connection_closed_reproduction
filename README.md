
# Puma Connection Closed reproduction

On applications that see frequent scaling (usually via auto scaling) on Heroku, they will sometimes see H13 errors (connection closed with no response) when these scale down events happen. This does not happen to all applications, it seems they must be reasonably high traffic. The goal of this repo is to provide some reproduction scripts.

One important fact is that there is a slight race condition between when a dyno is told to shut down (it sends a SIGTERM to all processes) and when the router stops sending requests to the dyno. It is possible that the dyno (computer) receives a request or two AFTER it has received a SIGTERM.


## How Puma Works

When puma is running it accepts connections on a socket. When you send a SIGTERM it will stop accepting new connections (which is different from a connection closed error) and once it is done processing the requests that it currently has in it's queue, it will shut down.

For this connection closed error to occur, puma must have the socket open, and be accepting connections but then shut down before it processes the request.

The dominant theory of why this error happens is that there is a race condition between when the puma stops processing requests but it has not yet closed the socket so new requests are accepted.

## Simple Repro

This reproduction shows what a connection closed error looks like from a client, but it doesn't try to reproduce the sigterm conditions that are seen on Heroku.

You can see a simple reproduction of a connection being closed with no response by going into the `simple_reproduction` folder and booting a server:

```
$ cd simple_reproduction
$ puma
```

If you look in the `config.ru` you will see that on first request it sends a SIGKILL to itself. Now it you fire two requests at the same time one of them will error 52 from curl:


```
$ curl localhost:9292 &> request1.log & curl:localhost:9292 &> request2.log
```

You will see this in one of the request logs:

```
$ cat request1.log
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
curl: (52) Empty reply from server
```

## Heroku Reproduction

Instead of sending a sigkill, we send a SIGTERM to the master process which then sends a SIGTERM to each child. If we send many requests at one time then we will see an H13 error.

You can deploy this code to heroku, first create an app:

```
$ heroku create
```

Next set the buildpacks:

```
heroku buildpacks:set https://github.com/lstoll/heroku-buildpack-monorepo
heroku buildpacks:add heroku/ruby
```


You will also have to tell it that your app lives in a sub directory:

```
heroku config:set APP_BASE=reproduction
```

Deploy the app:

```
$ git push heroku master
```

Now run the reproduction script and look at your logs:


```
$ ruby request-heroku.rb
$ ruby request-heroku.rb
pid 92736 exit 0
pid 92746 exit 0
pid 92740 exit 0
pid 92738 exit 0
pid 92734 exit 0
pid 92735 exit 0
pid 92744 exit 0
pid 92742 exit 0
```

> Note: the process shows an exit status of 0 because Heroku returns an error page, however you can see the H13 in the logs:

```
$ heroku logs -t
2019-05-10T18:40:10.635370+00:00 heroku[router]: at=info method=GET path="/?request_thread=0" host=ruby-h13.herokuapp.com request_id=f47fac62-f64b-427c-89d8-a37be56ea85e fwd="<ip>" dyno=web.1 connect=5003ms service=9ms status=200 bytes=104 protocol=https
2019-05-10T18:40:53.742213+00:00 heroku[web.1]: State changed from crashed to starting
2019-05-10T18:40:54.725525+00:00 heroku[web.1]: Starting process with command `puma -p 33201`
2019-05-10T18:40:56.769762+00:00 app[web.1]: config loaded
2019-05-10T18:40:56.769944+00:00 app[web.1]: [4] Puma starting in cluster mode...
2019-05-10T18:40:56.769973+00:00 app[web.1]: [4] * Version 3.12.1 (ruby 2.5.3-p105), codename: Llamas in Pajamas
2019-05-10T18:40:56.769975+00:00 app[web.1]: [4] * Min threads: 0, max threads: 16
2019-05-10T18:40:56.769980+00:00 app[web.1]: [4] * Environment: production
2019-05-10T18:40:56.770003+00:00 app[web.1]: [4] * Process workers: 2
2019-05-10T18:40:56.770005+00:00 app[web.1]: [4] * Phased restart available
2019-05-10T18:40:56.770204+00:00 app[web.1]: [4] * Listening on tcp://0.0.0.0:33201
2019-05-10T18:40:56.770273+00:00 app[web.1]: [4] Use Ctrl-C to stop
2019-05-10T18:40:56.785664+00:00 app[web.1]: [4] - Worker 0 (pid: 8) booted, phase: 0
2019-05-10T18:40:56.787225+00:00 app[web.1]: [4] - Worker 1 (pid: 11) booted, phase: 0
2019-05-10T18:40:57.475171+00:00 heroku[web.1]: State changed from starting to up
2019-05-10T18:41:06.848018+00:00 app[web.1]: [4] - Gracefully shutting down workers...
2019-05-10T18:41:06.937369+00:00 heroku[web.1]: State changed from up to crashed
2019-05-10T18:41:06.859330+00:00 heroku[router]: at=error code=H13 desc="Connection closed without response" method=GET path="/?request_thread=6" host=ruby-h13.herokuapp.com request_id=05696319-a6ff-4fad-b219-6dd043536314 fwd="<ip>" dyno=web.1 connect=0ms service=5ms status=503 bytes=0 protocol=https
2019-05-10T18:41:06.847732+00:00 heroku[router]: at=info method=GET path="/?request_thread=1" host=ruby-h13.herokuapp.com request_id=d2f9b0fe-2250-47d5-8aea-84d3ecd79ae7 fwd="<ip>" dyno=web.1 connect=1ms service=2ms status=200 bytes=104 protocol=https
2019-05-10T18:41:06.905734+00:00 heroku[web.1]: Process exited with status 143
2019-05-10T18:41:07.862567+00:00 heroku[router]: at=error code=H10 desc="App crashed" method=GET path="/?request_thread=3" host=ruby-h13.herokuapp.com request_id=f939302a-e88a-482a-89c9-dfcddf125ca0 fwd="<ip>" dyno=web.1 connect=0ms service= status=503 bytes= protocol=https
2019-05-10T18:41:07.910259+00:00 heroku[router]: at=error code=H10 desc="App crashed" method=GET path="/?request_thread=2" host=ruby-h13.herokuapp.com request_id=9030fbb8-03ed-496d-8b1d-c1cef64f5bb2 fwd="<ip>" dyno=web.1 connect=0ms service= status=503 bytes= protocol=https
2019-05-10T18:41:07.863377+00:00 heroku[router]: at=error code=H10 desc="App crashed" method=GET path="/?request_thread=5" host=ruby-h13.herokuapp.com request_id=bf9bb067-1baf-479e-8d2e-e15e6c0255cb fwd="<ip>" dyno=web.1 connect=0ms service= status=503 bytes= protocol=https
2019-05-10T18:41:07.882068+00:00 heroku[router]: at=error code=H10 desc="App crashed" method=GET path="/?request_thread=0" host=ruby-h13.herokuapp.com request_id=ce988901-9689-48dc-9018-fe0caa97e6dc fwd="<ip>" dyno=web.1 connect=0ms service= status=503 bytes= protocol=https
2019-05-10T18:41:07.885375+00:00 heroku[router]: at=error code=H10 desc="App crashed" method=GET path="/?request_thread=7" host=ruby-h13.herokuapp.com request_id=4387c36f-73a1-4f2e-a38c-f144bb3d9391 fwd="<ip>" dyno=web.1 connect=1ms service= status=503 bytes= protocol=https
2019-05-10T18:41:08.868392+00:00 heroku[router]: at=error code=H10 desc="App crashed" method=GET path="/?request_thread=4" host=ruby-h13.herokuapp.com request_id=a6ed6406-6600-4879-ae2e-264594486645 fwd="<ip>" dyno=web.1 connect=0ms service= status=503 bytes= protocol=https
```

After running the script you'll need to restart your server:

```
$ heroku restart
```

## Local Reproduction

We don't see the exact same behavior locally as on Heroku, but we do see odd behavior and I think it's related, or at least it seems like a bug in Puma even if it's unrelated.

If we boot the exact same app locally that sends a SIGTERM to the puma.pid on first request, then we would expect to see at least one request succeed and most of the others fail. Instead, what we see is that one request succeeds, and all the other requests hang. Puma never shuts down, you must kill it via the activity monitor. The curl commands keep waiting on a response from puma, but puma will never return a response.

```
$ ruby request.rb
```

This will boot a server and hit it with a number of requests, you can also observe the same behavior by running `curl localhost:9292` in another terminal window.

The output of each request is available in `requests<number>.log` and the output of puma is visible in `puma.log`.

It is worth noting that this only happens in multi-worker mode. If you remove the `workers` line from `config/puma.rb` it will either respond to requests, or prevent the connection from being made (which is different than accepting and closing the connection).

## Puma configuration

In addition to using workers, this reproduction needs to write the parent pid to a file and so it uses the `pidfile` command in `config/puma.rb`. There is a directive `drain_on_shutdown` which attempts to clear out the requests that are queued on the socket before first shutting down. This setting does not seem to fix the issue, it also does not seem to cause it.



52 - Client closed connection `curl: (52) Empty reply from server`
56 - ??? `(56) Recv failure: Connection reset by peer`
7  - Failed to connect to localhost port 9292: Connection refused


