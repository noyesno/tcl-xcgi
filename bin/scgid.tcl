#!/usr/bin/env tclsh
# vim:set syntax=tcl: #

package require scgi

set config [dict create]

dict set config -use    "tpool"
dict set config -tpool  0
dict set config -thread 0


package require Thread 

set tpool [tpool::create -minworkers 3 -maxworkers 5 -idletime 3 -initcmd {
  puts "thread init ..."
  package require scgi
} -exitcmd {
  puts "thread exit ..."
}]

proc accept {sock addr port} {

  switch -- [dict get $::config -use] {
    thread {
      after 0 [list thread/accept $sock $addr $port]  
    }

    tpool {
      after 0 [list tpool/accept $sock $addr $port]  
    }
  }

  return
}

proc tpool/accept {sock addr port} {
  set master [thread::id]
  puts "master = $master"

  thread::detach $sock 

  tpool::post $::tpool [subst -nocommand {
    puts "accept with [thread::id]"

    thread::attach $sock 

    package require scgi

    source $::script

    scgi::config respond scgi::respond ;# TODO: check existence of cgi::respond
    scgi::accept $sock $addr $port

    # thread::send -async $master [list notify [thread::id] release]
    # thread::release
  }]

  #-- set timeout [expr 1000*6]
  #-- after $timeout [list notify $tid timeout]
}

proc thread/accept {sock addr port} {
  set master [thread::id]
  puts "master = $master"


  set tid [thread::create {
    thread::wait
  }]

  thread::transfer $tid $sock
  thread::send -async $tid [subst -nocommand {
    puts "accept with [thread::id]"
    package require scgi

    source $::script

    scgi::config respond scgi::respond ;# TODO: check existence of cgi::respond
    scgi::accept $sock $addr $port

    thread::send -async $master [list notify [thread::id] release]
    # thread::release
  }]

  set timeout [expr 1000*6]
  after $timeout [list notify $tid timeout]
}

proc notify {tid event args} {
  switch -- $event {
    release {
      catch {thread::release $tid} 
      after cancel [list notify $tid timeout]
    }
    timeout {
      catch {thread::release $tid} 
    }
  }

  puts "notify $tid $event $args # [thread::names] | [tpool::names]"
}

lassign $argv port script
socket -server accept $port 

vwait forever

