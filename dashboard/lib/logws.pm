package logws;
use AntDen;
use Dancer2;
use Dancer2::Plugin::WebSocket;
use EV;
use FindBin qw( $RealBin );
use IPC::Open2;
use Symbol 'gensym';

set show_errors => 1;

our %conn;

sub replace
{
    my $s = shift;
    #$s =~ s/.\[1m.\[31m/<font color="#FF0000">/g;
    #$s =~ s/.\[1m.\[32m/<font color="#00FF00">/g;
    #$s =~ s/\[31m.\[42m/<font color="#0000FF">/g;
    #$s =~ s/\[0m.\[0m/<\/font>/g;
    #$s =~ s/\r/<br>/g;
    #$s =~ s/\n/<br>/g;
    return $s;
}

websocket_on_open sub {
    my( $conn, $env ) = @_;
    my ( $QUERY_STRING ) = @$env{qw( QUERY_STRING )};

    my %query = map{ split /=/, $_, 2 } split /&/, $QUERY_STRING;

    my $uuid = $query{uuid};
    my $error = 'open log fail:';
    unless( defined $uuid && $uuid =~ /^[a-zA-Z0-9\._]+$/ )
    {
        $conn->send("$error uuid format error");
        return;
    }

    my ( $err, $rdr, $cmd ) = gensym;

    if( $uuid =~ /^([Tt].+)_(\d+\.\d+\.\d+\.\d+)\.([a-z]+)/ )
    {
        $cmd = "$AntDen::PATH/scheduler/tools/tailtask --taskid $1 --host $2 --type $3";
    }
    else
    {
        if ( $uuid =~ /^(.+)\.([a-z]+)$/ )
        {
            $cmd = "$AntDen::PATH/slave/tools/remotelog --host $1 --type $2";
        }
        else
        {
            $cmd = "$AntDen::PATH/slave/tools/remotelog --host $uuid";
        }
    }

    $cmd = "tail -n 300 -F $AntDen::PATH/logs/$uuid*/current" if grep{ $uuid eq $_ }qw( scheduler controller dashboard ); 
    $conn{$conn}{pid} = IPC::Open3::open3( undef, $rdr, $err, $cmd );
    #TODO

    $conn{$conn}{err} = AnyEvent->io (
        fh => $err, poll => "r",
        cb => sub {
            my $input;my $n = sysread $err, $input, 102400;
            $conn->send(replace($input)) if $n;
        }
    );
    $conn{$conn}{rdr} = AnyEvent->io (
        fh => $rdr, poll => "r",
        cb => sub {
            my $input;my $n = sysread $rdr, $input, 102400;
            $conn->send(replace($input)) if $n;
        }
    );
};

websocket_on_close sub
{
    my( $conn ) = @_;
    #TODO
    kill 'KILL', $conn{$conn}{pid};
    delete $conn{$conn};
};

get '/tasklog/:uuid' => sub {
  my $uuid = params()->{uuid};
  my $ws_url = request->env->{HTTP_X_REAL_IP}
            ? sprintf( "ws://%s/ws", request->env->{HTTP_HOST} )
            : websocket_url;

  return <<"END";
    <html>
      <head><script>
          var urlMySocket = "$ws_url?uuid=$uuid";
          var mySocket = new WebSocket(urlMySocket);
          mySocket.onmessage = function (evt) {
            setMessageInnerHTML(evt.data);
          };
          mySocket.onopen = function(evt) {
            console.log("opening");
          };
          function setMessageInnerHTML(innerHTML) {
              document.getElementById('message').innerHTML += innerHTML + '<br/>';
           }
    </script></head>
    <body style="background:#000; color:#FFF" ><div id="message"></div></body>
  </html>
END
};

any '/mon' => sub { return  'ok'; };

true;
