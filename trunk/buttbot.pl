#!/usr/bin/perl 
use strict;
use warnings;

use Butts qw(buttify);
use IO::Socket;

## globals
use vars qw/$sock %CONF %results $hyp/;
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
#list of enemies (people who get buttified more often) and friends (people who dont get butted.)
my (@enemies, @friends);
#frequency that normal people and enemies get butted
my ($normalfrequency, $enemyfrequency);
#last thing said by someone in the channel
my (@previousdata);
#pre-setting frequencies
$enemyfrequency = 23;
$normalfrequency = 37;

#main execution loop
while (1) {

  &error("main: $! $@") if (($! ne "" ) || ($@ ne ""));
  
  @buffer=split(/\n/,&gets());
  
  foreach my $thing (@buffer) {
   
   ($from,$command,@data)=split(/\s+/,$thing);

   $from ||= '';
   $command ||= '';
   #if server pings, ping back.
   if ($from eq "PING") {
	   if ($command=~/^:\d+$/) {
	   		&send("PONG $command");
	   } else {
	  	 &send("PONG :$CONF{nick}");
	   }	   
   }
   
   &error("from server: @data") if ($from eq "ERROR");
 
  #If buttbot has successfully connected to the server, join a channel.
   if ($command eq "001") {
     if (defined $CONF{channel})
	{
		&send("JOIN $CONF{channel}") ;
		#&send("PRIVMSG $CONF{channel} : BUTTING SYSTEMS ONLINE!");
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
				  &send("PRIVMSG $to :".join(" ",&buttify(@data)));
			}
		}
		##if the first word in the string is equal to the password, set the user to be the admin
		if ($sub eq $CONF{pass}) {
		$auth=$from;
		}
		##ADMIN FUNCTIONS
		 if ($auth eq $from)  {
		##if the first word is "!quote", send the string that follows to the server
		## e.g. "quote PRIVMSG #testing : HELLO" prints out "HELLO" to #testing
			if ($sub eq "!quote" and @data >0 )
			{
				&send(@data) ;
			}
		##!echo spits out whatever to the channel
			if ($sub eq "!echo" and @data >0 )
			{
				&send("PRIVMSG $CONF{channel} :".join(" ",@data));
			}
		##!echobutt spits out whatever to the channel, but will buttify it
			if ($sub eq "!echobutt" and @data >0 )
			{
				&send("PRIVMSG $CONF{channel} :".join(" ",&buttify(@data)));
			}
		##!normfreq changes the frequency the normal people get butted
			if ($sub eq "!normfreq" and @data >0 )
			{
				$normalfrequency = $data[0];
				print("Normal Frequency changed to $normalfrequency");
			}
		##!enemfreq changes the frequency the enemies get butted
			if ($sub eq "!enemfreq" and @data >0 )
			{
				$enemyfrequency = $data[0];
				print("Enemy Frequency changed to $enemyfrequency");
			}
		##!addenemy adds someone to the enemy list. 
			if ($sub eq "!addenemy" and @data >0 )
			{
				push(@enemies, $data[0]);
				printf("Enemies:\n");
				foreach (@enemies)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						&send("PRIVMSG $CONF{channel} : TARGET DESIGNATED: $data[0]");
					}
				}
			}
		##!remenemy removes someone from the enemy list
			if ($sub eq "!remenemy" and @data >0 )
			{
				removeenemy($data[0]);
				printf("Enemies:\n");
				foreach (@enemies)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						&send("PRIVMSG $CONF{channel} : TARGET REMOVED: $data[0]");
					}
				}
			}
		##!addfriend adds someone to the friend list
			if ($sub eq "!addfriend" and @data >0 )
			{
				push(@friends, $data[0]);
				printf("Friends:\n");
				foreach (@friends)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						&send("PRIVMSG $CONF{channel} : $data[0], you're my bff :)");
					}
				}
			}
		##!remfriend removes someone from the friend list
			if ($sub eq "!remfriend" and @data >0 )
			{
				removefriend($data[0]);
				printf("Friends:\n");
				foreach (@friends)
				{
					printf("$_\n");
				}
				if (@data >1)
				{
					if ($data[1] eq "loud")
					{
						&send("PRIVMSG $CONF{channel} : $data[0],  I'm breaking up with you :(");
					}
				}
			}
		##!buttnow will buttify the previous message said in the channel.
			if ($sub eq "!buttnow" and @previousdata > 0)
			{
				if (($previousdata[0] !~ /^!/) && ($previousdata[0] !~ /^cout/)) 
				{
			  		&send("PRIVMSG $CONF{channel} :".join(" ",&buttify(@previousdata)));
				}
			}
		
			
		}
	}
	#if messages come from channel, start buttifying
      elsif ($to =~ /^#/ )  {
		
		##ignores statements from cout and users containing the word "bot"
              if (($from !~/^:cout/) && ($from !~/^:[^!]*bot[^!]*!/i)) {
	      if ($sub !~ /^!/) {
			my $rnd = 1;
			if (@data > 1) {
				#if it's a friend, don't buttify message. If enemy, buttify message more often.
				if (isfriend($from)) {
				$rnd = 1;
				}
				elsif (isenemy($from)) { 
				$rnd = int(rand(int($enemyfrequency)));
				} 
				else {
				$rnd = int(rand(int($normalfrequency)));
				}
				
			}
			  unshift (@data,$sub);
			#if the random number is 0, buttify that data
			if ($rnd ==0) {
			  sleep(@data*0.2 + 1);
			  &send("PRIVMSG $to :".join(" ",&buttify(@data)));
			}
			#store this for later butting
			else
			{
				@previousdata = @data;
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

sub isenemy{
	my($victim, $enemyname);
	$victim = $_[0];
	$victim =~ s/^:(.*)!.*$/$1/;
	foreach $enemyname (@enemies)
	{
		if ( $victim eq $enemyname)
		{
			return 1;
		}
	}
	return 0;
}

sub isfriend{
	
	my($victim, $friendname);
	$victim = $_[0];
	$victim =~ s/^:(.*)!.*$/$1/;
	foreach $friendname (@friends)
	{
		if ( $victim eq $friendname)
		{
			return 1;
		}
	}
	return 0;
}
sub removeenemy{
	my($victim, $blargh, $enemyname);
	$victim = $_[0];
	$blargh = 0;
	foreach $enemyname (@enemies)
	{
		if ( $victim eq $enemyname)
		{
			$enemies[$blargh] = "";
		}
		$blargh++;
	}
	
}

sub removefriend{
	my($victim, $blargh, $friendname);
	$victim = $_[0];
	$blargh = 0;
	foreach $friendname (@friends)
	{
		if ( $victim eq $friendname)
		{
			$friends[$blargh] = "";
		}
		$blargh++;
	}
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

