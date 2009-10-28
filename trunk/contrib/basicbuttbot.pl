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
    $self->{in_channels} = {};

    if ($self->config('debug')) {
        $self->log("DBG: Debugging output enabled\n");
    }

    1;
}

#@OVERRIDE
sub start_state {
    # in ur states, adding extra events so we can invite and shiz.
    my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
    my $ret = $self->SUPER::start_state($self, $kernel, $session);
    $kernel->state('irc_invite', $self, 'handle_invite');
    $kernel->state('irc_405', $self, 'handle_err_too_many_chans');

    return $ret;
}

sub handle_err_too_many_chans {
    my ($self, $server, $msg_text, $msg_parsed)
      = @_[OBJECT, ARG0, ARG1, ARG2];
    $self->log("IRC: too many channels:\n" . Dumper($msg_parsed) . "\n");
    # TODO: how can we let the user who requested us know that we're
    # unable to comply.  Maybe keep a queue of pending commands, and
    # only respond ok/err when we get an appropriate response from server.
    return;
}

sub handle_invite {
    my ($self, $inviter, $channel) = @_[OBJECT, ARG0, ARG1];
    $inviter = $self->nick_strip($inviter);
    $self->log("IRC: Going to join $channel, invited by $inviter\n");
    $self->join_channel($channel);
}

sub join_channel {
    my ($self, $channel, $key) = @_;
    $key = '' unless defined $key;
    $self->log("IRC: Joining channel [$channel]\n");
    $poe_kernel->post($self->{IRCNAME}, 'join', $channel, $key);
}

sub leave_channel {
    my ($self, $channel, $part_msg) = @_;
    $part_msg ||= "ButtBot Go Byebye!";
    $self->log("IRC: Leaving channel [$channel]: \"$part_msg\"\n");
    $poe_kernel->post($self->{IRCNAME}, 'part', $channel, $part_msg);
}

sub in_channel {
    my ($self, $channel, $present) = @_;
    if (defined $present) {
        if (!$present) {
            delete $self->{in_channels}->{$channel}
              if exists $self->{in_channels}->{$channel};
        } else {
            $self->{in_channels}->{$channel} = 1;
        }
    }
    return $self->{in_channels}->{$channel};
}

sub get_all_channels {
    my ($self) = @_;
    return keys %{ $self->{in_channels} };
}

sub chanjoin {
    my ($self, $ref) = @_;
    my ($channel, $who) = @{$ref}{qw/channel who/};
    $self->log("IRC: [$channel] $who joined\n");

    if ($self->is_me($who)) {
        $self->in_channel($channel, 1);
    }
    return;
}

sub chanpart {
    my ($self, $ref) = @_;
    my ($channel, $who) = @{$ref}{qw/channel who/};
    $self->log("IRC: [$channel] $who left\n");

    if ($self->is_me($who)) {
        $self->in_channel($channel, 0);
    }
    return;
}

sub kicked {
    my ($self, $ref) = @_;
    my ($channel, $who, $who_by, $why) =
      @{$ref}{qw/channel kicked who reason/};

    $self->log("$who just got kicked from $channel by $who_by: \"$why\"\n");
    if ($self->is_me($who)) {
        $self->in_channel($channel, 0);
    }
    return;
}

sub said {
    my ($self, $ref) = @_;
    # slicin' ma hashes.
    my ($channel, $body, $address, $who) =
      @{$ref}{qw/channel body address who/};

    # address doesn't even get set unless it's true :(
    $address ||= 0;

    print STDERR Dumper($ref);
    print STDERR "\n---------\n";

    if ($channel ne 'msg' && $address ne '') {
        # normal command
        # eg: <bob> ButtBot: stop it
        return if $self->handle_channel_command($who, $channel, $body);
    } elsif ($channel eq 'msg') {
        # parse for command
        return if $self->handle_pm_command($who, $body);
    }

    # butting is the default behaviour.
    $self->log("BUTT: Might butt\n");
    if ($self->to_butt_or_not_to_butt($who)) {
        $self->log("BUTT: Buttiing $who in [$channel]\n");
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

sub _parse_channel {
    # parse a string into a channel (optionally with a leading # or &), and the
    # remainder of the string.
    my ($str) = @_;
    if ($str =~ m/^([#&]?)([^,\s\x07]+)\s*(.*)$/) {
        return ($1.$2, $3) if $1;
        return ('#'.$2, $3);
    }
    return (undef, $str);
}

sub pm_reply {
    my ($self, $who, $msg) = @_;
    $self->say(who => $who, channel => 'msg', body => $msg);
}

# TODO: handle de-authentication when nick changes(?) or leaves all shared
# channels.
sub handle_pm_command {
    my ($self, $who, $msg) = @_;

    $self->log("CMD: testing for PM command: [$who], [$msg]\n");

    my ($cmd, $args) = _parse_command($msg);
    return 0 unless defined $cmd && length $cmd;
    $self->log("CMD: [$msg] is a PM command\n");

    # commands that don't need authentication
    # NB: They need to call return or they'll hit the auth barrier.
    if ($cmd eq 'auth') {
        if ($args eq $self->config('pass')) {
            $self->auth_set($who, 1);
            $self->pm_reply($who, "Hello again!");
        } else {
            $self->pm_reply($who, "Authentication Failed :(");
        }
        return 1;
    } elsif ($cmd eq 'friend') {
        # TODO: become friend/enemy
    }

    # do some authentication
    if ( ! $self->is_authed($who)) {
        $self->pm_reply($who, "You're not authenticated :(");
        return 1;
    }

    # TODO: command to query/set butt frequencies?


    # commands that *do* need authentication
    if ($cmd eq 'join') {
        my ($arg_chan, $arg_rem) = _parse_channel($args);
        if (defined $arg_chan) {
            if ($self->in_channel($arg_chan)) {
                $self->pm_reply($who, "I'm already in that channel!");
            } else {
                $self->join_channel($arg_chan);
                $self->pm_reply($who, "Joining channel $1");
            }
        } else {
            $self->pm_reply($who, "I needs a channel name please.");
        }

    } elsif ($cmd eq 'leave') {
        my ($arg_chan, $arg_msg) = _parse_channel($args);
        if (defined $arg_chan) {
            if (!$self->in_channel($arg_chan)) {
                $self->pm_reply($who, "I'm not in that channel!");
            } else {
                $self->leave_channel($arg_chan, $arg_msg);
                $self->pm_reply($who, "Ok.");
            }
        } else {
            $self->pm_reply($who, "I needs a channel name please. "
                            . "Also maybe a message.");
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
    } elsif ($cmd eq 'channel-list') {
        my @channels = $self->get_all_channels;;
        $self->pm_reply($who, "I'm in: " . join(', ', @channels));
    } else {
        $self->pm_reply($who, "Dunno what you want.");
    }

    return 1;
}

sub handle_channel_command {
    my ($self, $who, $channel, $msg) = @_;
    # return false if we don't handle a command, so things can
    # be appropriately butted.

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

sub to_butt_or_not_to_butt {
    my ($self, $sufferer) = @_;
    my $rnd = 0;
    my $frequencies = $self->config('frequency');

    if ($self->is_enemy($sufferer)) {
        $rnd = 0;
        $self->log("BUTT: Enemy [$sufferer], not butting\n");
    } elsif ($self->is_friend($sufferer)) {
        $rnd = int rand $frequencies->{friend};
        $self->log("BUTT: [friend] rand is $rnd\n");
    } else {
        $rnd = int rand $frequencies->{normal};
        $self->log("BUTT: [normal] rand is $rnd\n");
    }

    return ($rnd==1);
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

sub is_me {
    my ($self, $who) = @_;
    # TODO: support B::BBot's alt_nicks param too?
    return $self->{nick} eq $who;
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

sub log {
    my $self = shift;
    if ($self->config('debug')) {
        $self->SUPER::log(@_);
    }
}
1;

