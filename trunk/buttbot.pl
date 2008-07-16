#!/usr/bin/perl 
use strict;
use warnings;

use Butts qw(buttify);
use IO::Socket;

$|++;

my %CONF;

$CONF{file} = shift;
if (not $CONF{file}) {
  $CONF{file}=$0;
  $CONF{file}=~s/\.pl$/\.conf/i;
}

&readconf();

my $socket = new IO::Socket::INET(
	PeerAddr => $CONF{server},
	PeerPort => $CONF{port},
	proto    => 'tcp',
	Type     => SOCK_STREAM,
	Timeout  => 10
) or die "socket: $!";

_send("NICK $CONF{nick}");
_send("USER $CONF{ident} 0 * :$CONF{gecos}");

_fork() unless $CONF{debug};

my $auth = "";

my ($from,$command,@data);
#list of friends (people who get buttified more often) and enemies (people who dont get butted.)
my (%friends, %enemies);
#frequency that normal people and friends get butted
my ($normalfrequency, $friendfrequency);
#last thing said by someone in the channel
my (@previousdata);
my ($previouschannel);
my (@channels);
my ($starttime);
my (%linestotal);
my (%timeoflastbutting);

#pre-setting frequencies
$friendfrequency = 37;
$normalfrequency = 51;

#remove whitespace!
$CONF{channel} =~ s/\s+//;

# add friends from conf file
%friends = map {
	(my $friend = $_) =~ s/^\s+|\s+$//g;

	$friend, 1;
} split /,/, $CONF{friends} if $CONF{friends};

# add enemies from conf file
%enemies = map {
	(my $enemy = $_) =~ s/^\s+|\s+$//g;

	$enemy, 1;
} split /,/, $CONF{enemies} if $CONF{enemies};

#== forever butting... ========================================================

while (1) {
	die "main: $!" if $!;

	my @buffer = split /\n/, &gets();

	foreach my $line (@buffer) {
		print "$line\n";

		($from, $command, @data) = split /\s+/, $line;

   $from ||= '';
   $command ||= '';
   #if server pings, ping back.
   if ($from eq "PING") {
	   if ($command=~/^:\d+$/) {
	   		_send("PONG $command");
	   } else {
	  	 _send("PONG :$CONF{nick}");
	   }	   
   }
   
   die "from server: @data" if ($from eq "ERROR");
 
  #If buttbot has successfully connected to the server, join a channel.
   if ($command eq "001") {
      _send("MODE $CONF{nick} -x"); # hiding hostnames is for wimps.
     if (defined $CONF{channel})
	{
		_send("JOIN $CONF{channel}") ;
		$starttime = time;
		#_send("PRIVMSG $CONF{channel} : BUTTING SYSTEMS ONLINE!");
	}

     if (defined $CONF{nickpass})
	{
		_send("NICKSERV :identify $CONF{nickpass}");
	}
   } 
	#otherwise, if it's a message
	elsif ($command eq "PRIVMSG") {
	#get destination of message
        my $to=shift(@data);
	#get first word of message (might be command)
        my $sub=shift(@data);
	## remove preceding ':'
	$sub=~s/^://;

	##if a user private messages the bot...
	if ($to eq $CONF{nick})
	{
		$to = $from;
		$to =~ s/^:(.*)!.*$/$1/;
		#If the command is !butt, buttify message.
		if ($sub eq "!butt" and @data >0 ) 
		{
	     		 if (($data[0] !~ /^!/) && ($data[0] !~ /^cout/)) 
			{
				  _send("PRIVMSG $to :".join(" ",&buttify(@data)));
			}
		}
		
			#!help helps a brotha out, yo
			if ($sub eq "!help")
			{
			    _send("PRIVMSG $to : Buttbot is a butting robot of the future. Use !butt <message> to buttify a message.");
			}

		##if the first word in the string is equal to the password, set the user to be the admin
		if ($sub eq $CONF{pass}) {
		$auth=$from;
		}

		##ADMIN FUNCTIONS
		 if ($auth eq $from)  {

		##if the first word is "!quote", send the string that follows to the server
		## e.g. "!quote PRIVMSG #testing : HELLO" prints out "HELLO" to #testing
			if ($sub eq "!quote" and @data >0 )
			{
				_send(@data) ;
			}
		##!echo #channel spits out whatever to the channel
			elsif ($sub eq "!echo" and @data >1 )
			{
			    $_ = shift(@data);
			    
				_send("PRIVMSG $_ :".join(" ",@data));
			}
		##!echobutt #channel spits out whatever to the channel, but will buttify it
			elsif ($sub eq "!echobutt" and @data >1 )
			{
			    $_ = shift(@data);
			   
				_send("PRIVMSG $_ :".join(" ",&buttify(@data)));
			}
		#!boom spits out whatever to every channel
			elsif ($sub eq "!boom" and @data > 0)
			{
			    _send("PRIVMSG $CONF{channel} :".join(" ",@data));
			}
		#duh
			elsif ($sub eq "!boombutt" and @data > 0)
			{
			    _send("PRIVMSG $CONF{channel} :".join(" ",&buttify(@data)))
			}
		##!normfreq changes the frequency the normal people get butted
			elsif ($sub eq "!normfreq" and @data >0 )
			{
				$normalfrequency = $data[0];
				print("Normal Frequency changed to $normalfrequency");
			}
		##!friendfreq changes the frequency the friends get butted
			elsif ($sub eq "!friendfreq" and @data >0 )
			{
				$friendfrequency = $data[0];
				print("Friend Frequency changed to $friendfrequency");
			}
		##!addfriend adds someone to the friend list. 
			elsif ($sub eq "!addfriend" and @data >0 )
			{
			    $friends{$data[0]} = 1;
				printf("Friends:\n");
			        foreach (sort keys %friends)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						_send("PRIVMSG $CONF{channel} : $data[0], you're my BFF :)");
					}
					else
					{
					       _send("PRIVMSG $data[1] : $data[0], you're my BFF :)");
					}
				}
			}
		##!remfriend removes someone from the friend list
			elsif ($sub eq "!remfriend" and @data >0 )
			{
				delete $friends{$data[0]};
				printf("Friends:\n");
				foreach (sort keys %friends)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						_send("PRIVMSG $CONF{channel} :  $data[0],  I'm breaking up with you :(");
					}
					else
					{
						_send("PRIVMSG $data[1] :  $data[0],  I'm breaking up with you :(");
					}
				}
			}
		##!addenemy adds someone to the enemy list
			elsif ($sub eq "!addenemy" and @data >0 )
			{
			    $enemies{$data[0]} = 1;
				printf("Enemies:\n");
				foreach (sort keys %enemies)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						_send("PRIVMSG $CONF{channel} : SHUN DESIGNATED: $data[0]");
					}
					else
					{
					    _send("PRIVMSG $data[1] :  SHUN DESIGNATED: $data[0]");
					}
				}
			}
		##!remenemy removes someone from the enemy list
			elsif ($sub eq "!remenemy" and @data >0 )
			{
			        delete $enemies{$data[0]};
				printf("Enemies:\n");
				foreach (sort keys %enemies)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						_send("PRIVMSG $CONF{channel} : SHUN REMOVED: $data[0]");
					}
					else
					{
					    	_send("PRIVMSG $data[1] : SHUN REMOVED: $data[0]");
					}
				}
			}
		##!buttnow will buttify the previous message said in the channel.
			elsif ($sub eq "!buttnow" and @previousdata > 0)
			{
				if (($previousdata[0] !~ /^!/) && ($previousdata[0] !~ /^cout/)) 
				{
			  		_send("PRIVMSG $previouschannel :".join(" ",&buttify(@previousdata)));
				}
			}
			elsif ($sub eq "!join" and @data > 0)
			{
			    $CONF{channel} = $CONF{channel}.",";
			    $CONF{channel} = $CONF{channel}.$data[0];
			    _send("JOIN $data[0]");
			}
			elsif ($sub eq "!leave" and @data > 0)
			{
			    $CONF{channel} =~ s/$data[0]//;
			    _send("PART $data[0]");
			}
		
			
		}
	}
	#if messages come from channel, start buttifying
      elsif ($to =~ /^#/ )  {
	  
	  my $sender = $from;
	  $sender =~ s/^:(.*)!.*$/$1/;
	  if (exists $linestotal{$to})
	  {
	  $linestotal{$to}++;
	  }
	  else
	  {
	      $linestotal{$to} = 1;
	  }
		##ignores statements from cout and users containing the word "bot"
              if (($from !~/^:cout/) && ($from !~/^:[^!]*bot[^!]*!/i)) {
	      if ($sub !~ /^!/) {
			my $rnd = 1;
			unshift (@data,$sub);
			if (@data > 1) {
				#if it's a enemy, don't buttify message. If friend, buttify message more often.
			    $rnd = tobuttornottobutt($sender);
				
			}
			  
			#if the random number is 0, buttify that data
			if ($rnd ==0) {
			  
			  $timeoflastbutting{$to} = time;
			  sleep(@data*0.2 + 1);
			  # if the message is a CTCP line, avoid replacing
			  # the CTCP command in the first word
			  if (substr($data[0], 0, 1) eq "\1") {
			    # only butt if the command is not the only word
			    if (@data > 1 && $data[1] ne "\1") {
			      my $first = shift(@data);
			      my @butted = &buttify(@data);
			      unshift(@butted, $first);
			      _send("PRIVMSG $to :".join(" ", @butted));
			    }
			  } else {
			    _send("PRIVMSG $to :".join(" ", &buttify(@data)));
			  }
			}
			#store this for later butting
			else
			{
				@previousdata = @data;
				$previouschannel = $to;
			}
	      } elsif ($sub eq "!butt" and @data >0 ) {
	          if (($data[0] !~ /^!/) && ($data[0] !~ /^cout/)) {
		  _send("PRIVMSG $to :".join(" ",&buttify(@data)));
	      }
	      }
	 }
	 }
   }
 }
}

#== subroutines ===============================================================

#for future determining of butting
sub tobuttornottobutt
{
    my($rnd, $sender);
    $sender = shift;
    if (exists $enemies{$sender}) {
				$rnd = 1;
				}
				elsif (exists $friends{$sender}) { 
				$rnd = int(rand(int($friendfrequency)));
				} 
				else {
				$rnd = int(rand(int($normalfrequency)));
				}
    return $rnd;
}

sub gets {
  my $data = "";
  $socket->recv($data, 1024);

  return $data;
}

sub _send {
  $socket->send("@_\n");
}

sub _fork {
	my $pid = fork;

	if (defined $pid) {
		if ($pid == 0) { # is child process
			return;
		} else {
			print "exiting, child pid = $pid\n";
			exit;
		}
	} else {
		die "fork: $!";
	}
}

sub readconf {
  open my($fh), "$CONF{file}" or die "readconf: cannot open $CONF{file}";

  while (my $line = <$fh>) {
    if (substr($line,0,1) ne "#") {
     if ($line =~/^\s*([^\s]+)\s*=\s*(.+)$/) {
        $CONF{lc($1)}=$2;
      }
     }
  }   
}
