#!/usr/bin/env tclsh
# vim:set syntax=tcl: #

#======================================================================#
# SCGI: A Simple Common Gateway Interface alternative                  #
#======================================================================#

package provide scgi 0.1


namespace eval scgi {
  variable config [dict create]
  
  proc log {level args} {
    # TODO: check level
    set datetime [clock format [clock seconds] -format  "%Y%m%d %T %z"]
    puts [format "%s # %s: %s" $datetime $level [uplevel ::subst [concat $args]]]
  }

  proc reset {} {
    variable config

    dict set config SCRIPT_FILENAME ""
    dict set config respond         ""
    dict set config max_body_size   [expr "1024*1024*10"]  ;# 10M 
    dict set config max_head_size   4096                   ;# 4K
  }

  proc @ {args} { }

  proc config {key args} {
    variable config

    if [llength $args] {
      dict set config $key {*}$args
      return
    }

    set value ""

    catch {
      set value [dict get $config $key]
    }

    return $value 
  }

  proc debug {data} {
    puts "debug: $data"
  }

  proc print {sock data} {
    puts -nonewline $sock $data
  }

  proc println {sock data} {
    puts -nonewline $sock "$data\r\n"
  }

  proc netstring {data} {
    return [format "%s:%s," [string length $data] $data]
  }

  proc accept {sock args} {
    #-- upvar $headvar header
    #-- upvar $bodyvar body

    fconfigure $sock -translation binary -encoding binary

    fconfigure $sock -blocking    0
    set buffer [read $sock 1024]     ;# header length should not > 1024
    fconfigure $sock -blocking 1
    set idx [string first ":" $buffer]

    set header_length [string range $buffer 0 $idx-1]
    set header_read   [expr {[string length $buffer] - $idx - 1}]

    # check header length
    if {$header_length > [config max_head_size]} {
      puts "alert: max_head_size check fail # $header_length > [config max_head_size]"
      close $sock
    } 

    #  include the trailing char ','
    if {$header_read <= $header_length} {
      append buffer [read $sock [expr {$header_length - $header_read + 1}]]
    }

    incr idx
    set header [dict create]
    #debug $buffer 
    foreach {name value} [split [string range $buffer $idx $idx+$header_length] "\0"] {
      if {$name eq ","} break

      log debug "$name = $value"
      dict set header $name $value
    }

    # debug $header

    incr idx $header_length
    incr idx
    set buffer [string range $buffer $idx end]

    set body_length [dict get $header CONTENT_LENGTH]
    set body_read   [string length $buffer]

    if {$body_length > [config max_body_size]} {
      puts "alert: max_body_size check fail # $body_length > [config max_body_size]"
      close $sock
    }

    if {$body_read < $body_length} {
      append buffer [read $sock [expr {$body_length - $body_read}]]
    }

    set body $buffer

    set request_uri [dict get $header REQUEST_URI]
    log debug "request = $request_uri + [string length $body]"
    log debug {body = $body}


    set respond [config respond]

    if {$respond ne ""} {
      $respond $sock $header $body
    } else {
      source [config SCRIPT_FILENAME] 
    }

    log debug "close sock $sock after scgi reply"
    close $sock

    return 1
  }

  proc request {sock header body} {
    set buffer ""

    append buffer "CONTENT_LENGTH" [string length $body]
    append buffer "SCGI"           "1"

    dict foreach {name value} $header {
      append buffer $name "\0" $value "\0"
    }


    print $sock [netstring $buffer]

    print $sock $body

    return
  }

  @ proc respond {sock header body} {

    dict foreach {name value} $header {
      println $sock "$name: $value"
    }

    println ""

    print   $body
    
    return
  }

}

scgi::reset

proc scgi::listen {port} {

  if {[config "respond"] ne ""} {
    # ...
  } elseif {[info command respond] ne ""} {
    config "respond" [namespace which respond]
  } else {
    config "respond" ""
  }

  puts "respond = [config respond]"

  socket -server [list [namespace which accept]] $port 

  return
}


if {![info exist ::argv0] || [file normalize $::argv0] ne [file normalize [info script]]} {
  return
}


lassign $argv script port

scgi::config SCRIPT_FILENAME $script 
source $script

scgi::listen $port

vwait scgi::forever

#=================================================================================#
# Notes                                                                           #
#=================================================================================#

  * Duplicate names are not allowed in the headers. 
  * The first header must be "CONTENT_LENGTH"
  * Must have header with the name "SCGI" and a value of "1".
  * Standard CGI environment variables should be provided as SCGI headers.

  * close the connection after response

