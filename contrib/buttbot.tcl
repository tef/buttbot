#eggdrop1.6 +/-
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
#
# Version Information (Major Additions and Bug Fixes!) can be found in the
# Version.txt included in the package.
#
# Feature explanations, instructions, and HELP can be found in
# How-to.txt included in the package.
#
##########################################################################

#Make sure hyphen.tex exists
package require textutil
#TODO relative path instructions
textutil::adjust::readPatterns "/home/lamer/hyphen.tex"

#@##### SETUP THE SCRIPT #######
# Please change the details below

set channel "#lamechan"

# People who get buttified more often
set friends "lamedude lamerguy"

# How often to buttify friends
set friendfreq 25

# People who don't get buttified
set enemies ""

# How often to buttify everyone else
set normalfreq 51

#invite, pass, debug

#change this if you really have to
set stopwords {
 {a}
 {about}
 {above}
 {absent}
 {across}
 {after}
 {against}
 {all}
 {along}
 {among}
 {an}
 {and}
 {are}
 {around}
 {as}
 {at}
 {atop}
 {be}
 {before}
 {behind}
 {below}
 {beneath}
 {beside}
 {besides}
 {between}
 {beyond}
 {but}
 {by}
 {can}
 {could}
 {do}
 {down}
 {during}
 {each}
 {except}
 {for}
 {from}
 {had}
 {has}
 {have}
 {he}
 {he'll}
 {her}
 {him}
 {his}
 {how}
 {I}
 {I'm}
 {if}
 {in}
 {inside}
 {into}
 {is}
 {it}
 {it's}
 {like}
 {many}
 {might}
 {must}
 {near}
 {next}
 {not}
 {of}
 {off}
 {on}
 {one}
 {onto}
 {opposite}
 {or}
 {other}
 {out}
 {outside}
 {over}
 {past}
 {per}
 {plus}
 {round}
 {said}
 {she}
 {should}
 {since}
 {so}
 {some}
 {than}
 {that}
 {the}
 {their}
 {them}
 {then}
 {there}
 {these}
 {they}
 {they'll}
 {they're}
 {this}
 {through}
 {till}
 {times}
 {to}
 {toward}
 {towards}
 {under}
 {unlike}
 {until}
 {up}
 {upon}
 {via}
 {was}
 {we}
 {we'll}
 {we're}
 {were}
 {what}
 {when}
 {which}
 {will}
 {with}
 {within}
 {without}
 {word}
 {won't}
 {worth}
 {would}
 {you}
 {you'll}
 {you're}
 {your}
}

#####################################################
### don't need to touch the stuff below this line ###
#$###################################################


bind pubm - * checkbutt

proc hyphenate {word} {
    if {[catch {
            set h [textutil::adjust::adjust $word -hyphenate true -strictlength true -length [string length $word]]
        } excuse]} {
            set h $word
    } else {
        set h [textutil::adjust::adjust $word -hyphenate true -strictlength true -length [string length $word]]
    }
    return $h
}

#random weighted string sort, after a fashion
proc rwssort {a b} {
    if {[rand [string length $a]] > [rand [string length $b]]} {
        return -1
    } else {
        return 1
    }
}

proc tobuttornottobutt {nick} {
 global friends enemies friendfreq normalfreq
 if {[lsearch -exact $enemies $nick] != -1} {
  return 1
 } elseif {[lsearch -exact $friends $nick] != -1} {
  return [rand $friendfreq]
 } else {
  return [rand $normalfreq]
 }
}

proc buttsub {candidate} {
    set h [hyphenate $candidate]
    if {[llength $h] > 1} {
        set h [lreplace $h 0 0 "butt"]
        set h [join $h ""]
    } else {
        set h "butt"
    }
    return $h
}

proc buttify {text chan} {
    global stopwords
    set words [split $text " "]
    set repetitions [expr [llength $text] / 11]
    set longest [lrange [lsort -unique -command rwssort $words] 0 $repetitions]

    foreach word $stopwords {
        set longest [lsearch -all -inline -not -exact $longest $word]
    }

    foreach candidate $longest {
        set buttword [buttsub $candidate]
        if {$buttword != $candidate} {
            set i [lsearch $words $candidate]
            foreach j $i {
                set words [lreplace $words $j $j $buttword]
            }
        }
    }
    set buttspeak [join $words " "]
    putserv "PRIVMSG $chan :$buttspeak"
}

proc checkbutt {nick host hand chan text} {
    global botnick channel
    #make sure we're in the right channel and this isn't us talking and we should be buttifying
    if {[lsearch -exact $channel $chan] == -1 || $nick == $botnick || [tobuttornottobutt $nick] != 0} {
        return 0
    } elseif {[llength $text] > 1} {
        utimer [expr [llength [split $text]]*0.2+1] [list buttify $text $chan]
        return 0
    }
}

putlog "buttbot loaded, ready to buttify maam"
