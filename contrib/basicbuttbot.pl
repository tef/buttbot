#!/usr/bin/perl

package main;

use strict;
use warnings;
use Data::Dumper;

my $conf_file = $ARGV[0] || "./contrib/conf.yml";
my $bot = BasicButtBot->new(config => $conf_file);

# fly, my pretties, fly!
$bot->run;

package BasicButtBot;

use base qw/Bot::BasicBot/;

# What would you like to Butt today?
use Butts;
# config-parsing is a bit passe.
use YAML::Any;
use Data::Dumper;
# so we can hax our own handlers for things.
use POE;

sub init {
    my $self = shift;
    my $config = YAML::Any::LoadFile($conf_file);
    $self->{$_} = $config->{connection}->{$_}
      for (keys %{$config->{connection}});
    $self->{settings}->{$_} = $config->{settings}->{$_}
      for (keys %{$config->{settings}});

    $self->{authed_nicks} = {};

    1;
}

#@OVERRIDE
sub start_state {
    # in ur states, adding extra events so we can invite and shiz.
    my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
    my $ret = $self->SUPER::start_state($self, $kernel, $session);
    $kernel->state('irc_invite', $self, 'handle_invite');

    return $ret;
}

sub handle_invite {
    my ($self, $inviter, $channel) = @_[OBJECT, ARG0, ARG1];
    $inviter = $self->nick_strip($inviter);
    $self->log("Going to join $channel, invited by $inviter\n");
    $self->join_channel($channel);
}

sub join_channel {
    my ($self, $channel, $key) = @_;
    $key = '' unless defined $key;
    $self->log("Joining channel [$channel]\n");
    $poe_kernel->post($self->{IRCNAME}, 'join', $channel, $key);
}

sub leave_channel {
    my ($self, $channel, $part_msg) = @_;
    $part_msg ||= "ButtBot Go Byebye!";
    $self->log("Leaving channel [$channel]: $part_msg\n");
    $poe_kernel->post($self->{IRCNAME}, 'part', $channel, $part_msg);
}

sub config {
    my ($self, $key, $value) = @_;
    if (defined $value) {
        $self->{settings}->{$key} = $value;
    }
    return $self->{settings}->{$key};
}

sub is_authed {
    my ($self, $nick) = @_;
    return exists($self->{authed_nicks}->{$nick});
}

sub auth_set {
    my ($self, $nick, $auth) = @_;
    if ($auth) {
        $self->{authed_nicks}->{$nick} = 1;
    } else {
        if ($self->is_authed($nick)) {
            delete($self->{authed_nicks}->{$nick});
        } else {
            $self->log("Trying to de-auth someone who isn't authenticated: $nick\n");
        }
    }
}

sub said {
    my ($self, $ref) = @_;
    # slicin' ma hashes.
    my ($channel, $body, $address, $who) =
      @{$ref}{qw/channel body address who/};

    # doesn't even get set unless it's true :(
    $address ||= 0;

    print STDERR Dumper($ref);
    print STDERR "\n\n---------\n\n";

    if ($channel ne 'msg' && $address ne '') {
        # normal command
        return if $self->handle_user_command($who, $channel, $body);
    } elsif ($channel eq 'msg') {
        # parse for command
        return if $self->handle_admin_command($who, $body);
    }
    # butting is the fallback behaviour.
    if ($self->to_butt_or_not_to_butt($who)) {
        $self->buttify_message($who, $channel, $body);
    }

    return;
}


sub _parse_command {
    my ($msg) = @_;

    if ($msg =~ m/^!([\w_-]+)\s*(.*)$/) {
        return ($1, $2);
    } else {
        return ();
    }
}

sub pm_reply {
    my ($self, $who, $msg) = @_;
    $self->say(who => $who, channel => 'msg', body => $msg);
}

# TODO: handle de-authentication when nick changes(?) or leaves all shared
# channels.
sub handle_admin_command {
    my ($self, $who, $msg) = @_;

    $self->log("CMD: testing admin command: [$who], [$msg]\n");

    my ($cmd, $args) = _parse_command($msg);


    return 0 unless defined $cmd && length $cmd;

    if ($cmd eq 'auth') {
        if ($args eq $self->config('pass')) {
            $self->auth_set($who, 1);
            $self->pm_reply($who, "Hello again!");
        } else {
            $self->pm_reply($who, "Authentication Failed :(");
        }
        return 1;
    }

    if ( ! $self->is_authed($who)) {
        $self->pm_reply($who, "You're not authenticated :(");
        return 1;
    }

    # TODO: Keep track of which channels we're already in (and check when
    # join/leaving)
    # TODO: have a !list-channels command that tells someone what they are.
    # TODO: command to query/set butt frequencies?

    if ($cmd eq 'join') {
        if ($args =~ m/(#\w+)/) {
            $self->join_channel($1);
            $self->pm_reply($who, "Joining channel $1");
        } else {
            $self->pm_reply($who, "I needs a channel please.");
        }

    } elsif ($cmd eq 'leave') {
        if ($args =~ m/(#\w+)\s*(.*?)$/) {
            $self->leave_channel($1, $2);
            $self->pm_reply($who, "Ok.");
        } else {
            $self->pm_reply($who, "I needs a channel please. Also maybe a message.");
        }

    } elsif ($cmd eq 'change-nick') {
        #TODO: this
        $self->pm_reply($who, "Sorry, not implemented yet");

    } elsif ($cmd eq 'set-meme') {
        if ($args =~ m/^(\w+)/) {
            my $old_meme = $self->config('meme');
            $self->config('meme', $1);
            $self->pm_reply($who, "Changed meme from [$old_meme] to [$1]");
        } else {
            $self->pm_reply($who, "Meme unchanged. Learn some syntax");
        }
    } elsif ($cmd eq 'deauth') {
        $self->auth_set($who, 0);
        $self->pm_reply($who, "Ok. See you again sometime");
    } else {
        $self->pm_reply($who, "Dunno what you want.");
    }

    return 1;
}

sub handle_user_command {
    my ($self, $who, $channel, $msg) = @_;
    # return false if we don't handle a command, so things can be appropriately
    # butted.
    $self->log("CMD: testing user command\n");
    my ($cmd, $args) = _parse_command($msg);
    return 0 unless defined $cmd && length $cmd;

    return 0; # TODO: unimplemented.

    # TODO: !stopit - adds them to the enemies list.
    # TODO: !butt - randomly butts something?
}

sub buttify_message {
    my ($self, $who, $where, $what) = @_;
    my $meme = $self->config('meme');

    my @butt_bits = split /\s+/, $what;
    my @butted_bits = Butts::buttify($meme, @butt_bits);
    my $butt_msg = join ' ', @butted_bits;

    $self->say(channel => $where, who => $who,
               body => $butt_msg, address => 1);
    1;
}

sub is_enemy {
    my ($self, $who) = @_;
    my $enemies = $self->config('enemies');
    return exists $enemies->{$who}
}

sub is_friend {
    my ($self, $who) = @_;
    my $friends = $self->config('friends');
    return exists $friends->{$who}
}

sub to_butt_or_not_to_butt {
    my ($self, $sufferer) = @_;
    my $rnd = 0;
    my $frequencies = $self->config('frequency');

    if ($self->is_enemy($sufferer)) {
        $rnd = 0;
    } elsif ($self->is_friend($sufferer)) {
        $rnd = int rand $frequencies->{friend};
    } else {
        $rnd = int rand $frequencies->{normal};
    }

    return ($rnd==1);
}
1;

