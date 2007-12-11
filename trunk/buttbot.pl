#!/usr/bin/perl 
use strict;
use warnings;

use Butts qw(buttify);
use IO::Socket;

## globals
use vars qw<$sock %CONF %results $hyp>;
$|=1;

$CONF{file} = shift;
if (not $CONF{file}) {
  $CONF{file}=$0;
  $CONF{file}=~s/\.pl$/\.conf/i;
}

&readconf();

$sock=&connect($CONF{server},$CONF{port});
&error("socket: $! $@") if ($sock eq "");

&send("NICK $CONF{nick}");
&send("USER $CONF{ident} 0 * :$CONF{gecos}");

&forks() if (not $CONF{debug});;

my ($auth, @buffer) ;
$auth ="";
@buffer=();
my ($from,$command,@data);


while (1) {

  &error("main: $! $@") if (($! ne "" ) || ($@ ne ""));
  
  @buffer=split(/\n/,&gets());
  
  foreach my $thing (@buffer) {
   
   ($from,$command,@data)=split(/\s+/,$thing);

   $from ||= '';
   $command ||= '';

   if ($from eq "PING") {
	   if ($command=~/^:\d+$/) {
	   		&send("PONG $command");
	   } else {
	  	 &send("PONG :$CONF{nick}");
	   }	   
   }
   
   &error("from server: @data") if ($from eq "ERROR");
 
   if ($command eq "001") {
     &send("JOIN $CONF{channel}") if (defined $CONF{channel});
   } elsif ($command eq "PRIVMSG") {
      my $to=shift(@data);
      my $sub=shift(@data);
     $sub=~s/^://;
     
      if ($sub eq $CONF{pass}) {
         $auth=$from;
	}
      
      if ($auth eq $from)  {
	    &send(@data) if ($sub eq "quote");
      }
      if ($to =~ /^#/)  {
              if (($from !~/^:cout/) && ($from !~/^:[^!]*bot[^!]*!/i)) {
	      if ($sub !~ /^!/) {
			my $rnd = 1;
			if (@data > 2) {
			if ($from =~ /floWenoL/ ) { 
			  $rnd = int(rand(23));
			} else {
			   $rnd = int(rand(37));
			}
			}
			if ($rnd ==0) {
			  unshift (@data,$sub);
			  sleep(@data*0.2+1);
			  &send("PRIVMSG $to :".join(" ",&buttify(@data)));
			}
	      } elsif ($sub eq "!butt" and @data >0 ) {
	          if (($data[0] !~ /^!/) && ($data[0] !~ /^cout/)) {
		  &send("PRIVMSG $to :".join(" ",&buttify(@data)));
	      }
	      }
}
	 }
   }
 }
}

sub connect {
  my ($remote_host,$remote_port,$local_host)=(shift,shift,shift);
  my $socket=IO::Socket::INET->new( PeerAddr => $remote_host,
                                 PeerPort => $remote_port,
                                 proto    => "tcp",
                                 Type     => SOCK_STREAM,
                                 Timeout  => 10
                                 );
  return $socket;
}

sub gets {
  my $data = "";
  $sock->recv($data,1024) ;
#or &error("get: $! $@");
  return $data;
}
sub send {
  my ($text) = join(" ",@_);
  $text.="\n";
  $sock->send($text);
}

sub forks {
my $spoon=fork();
  if (defined $spoon) {
    if ($spoon==0) {
    return;
    } else {
    print "exiting, child pid=$spoon\n";
    exit;
    }
  } else {
    &error("fork: $! $@");
  }
}

sub error {
    print "\nerror: @_\n";
    exit;
}

sub readconf {
  our %CONF;
  my ($conffile)=@_;
  open(CONF,"$CONF{file}") or &error("readconf: cannot open $CONF{file}");
  while (my $line=<CONF>) {
    if (substr($line,0,1) ne "#") {
     if ($line =~/^\s*([^\s]+)\s*=\s*(.+)$/) {
        $CONF{lc($1)}=$2;
      }
     }
  }   
  close(CONF);
}

