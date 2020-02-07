#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::JSON qw/decode_json encode_json/;
use Mojo::Pg;

helper pg => sub { state $pg = Mojo::Pg->new('postgresql://chat_user@/sketchat') };


get '/' => sub {
    my $c = shift;
    $c->render(template => 'index');
};

get '/sender' => sub {
    my $c = shift;
    $c->stash('type' => 'sender');
    $c->render(template => 'index');
};

get '/receiver' => sub {
    my $c = shift;
    $c->stash('type' => 'receiver');
    $c->render(template => 'index');
};

get '/canvas';

websocket '/channel' => sub {
    my $c = shift;
    $c->inactivity_timeout(36000);

    my $channel = 'threertc';
    $c->on('message' => sub {
	my ($c, $message) = @_;
	$c->app->log->info($message);
	$c->pg->pubsub->notify($channel => $message);
	$c->send($message)
    });

    my $cb = sub  {
	my ($pubsub, $message) = @_;
	$c->app->log->info('pubsub');
	$c->send($message)
    };

    $c->pg->pubsub->listen($channel => $cb);
    
    # Remove callback from PG listeners on close
    $c->on(finish => sub  {
	       my $c = shift;
	       my $channel = 'threertc';
	       $c->pg->pubsub->unlisten($channel => $cb);
	   });
    
};

websocket '/old' => sub {
    my $c = shift;
    $c->inactivity_timeout(36000);

    $c->on('message' => sub {
	my ($c, $message) = @_;
	$c->app->log->info($message);
	$c->send($message)
    });
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<h1>Welcome to the Mojolicious real-time web framework!</h1>

<video id="localVideo" autoplay muted playsinline></video>
<video id="remoteVideo" autoplay playsinline></video>
<div>
  <button id="startButton">Start</button>
  <button id="callButton">Call</button>
  <button id="hangupButton">Hang Up</button>
  <div><%= current_route %></div>
</div>
    % if ($type eq 'sender') {
    <script src="mojortc.js"></script>
	% } else {
    <script src="mojortc.js"></script>
	% }
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <script
    src="https://code.jquery.com/jquery-3.4.1.slim.js"
    integrity="sha256-BTlTdQO9/fascB1drekrDVkaKd9PkwBymMlHOiG+qLI="
    crossorigin="anonymous"></script>
    <script src="https://webrtc.github.io/adapter/adapter-latest.js"></script>
    <link rel="stylesheet" type="text/css" href="main.css" media="screen" />
    <link rel="stylesheet" type="text/css" href="webrtc.css" media="screen" />

    
  <body><%= content %></body>
</html>
@@ canvas.html.ep
% layout 'default';
% title 'Welcome';
<h1>This is a canvas test</h1>

<div><canvas id="canvas" width="256" height="256" style="width:256px;height:256px"></canvas></div>
  <button id="startButton">Start</button>
  <button id="callButton">Call</button>
  <button id="hangupButton">Hang Up</button>
</div>
    <script>
    $(function(){
	var ctx = document.getElementById('canvas').getContext('2d');
	var img = new Image();
	const ws = new WebSocket('ws://localhost:3000/img');

	ws.addEventListener('open', function (event) {
	    ws.send('Hello Server!');
	    img.onload = function() {
		console.log(img);
		ctx.drawImage(img, 0, 0);
		console.log(canvas.toDataURL('image/jpeg').length);
		console.log(canvas.toDataURL('image/png').length);
		try {
		    ws.send(canvas.toDataURL('image/jpeg'));
		    ws.send(canvas.toDataURL('image/png'));
		} catch(e) {
		    console.log(e)
		}
	    }
	    img.src = "Lenna_%28test_image%29.png"
	});

	ws.addEventListener('message', function (event) {
	    console.log(event.data)
	})
	ws.onerror = (e) => { cconsole.log(e) }

    })
</script>
