#/usr/bin/env tclsh

package require fcgi

namespace eval FastCgiApp {
  proc accept {sock clientaddr clientport} {

    fcgi::accept $sock
    fcgi::config $sock response [list FastCgiApp::response ]

    puts "DEBUG: accept $sock $clientaddr:$clientport"
    
    while {[fcgi::recv $sock]} {

      puts ".... [info cmdcount] $sock ..."
      # ...
    }

    puts "broken"
  }

  proc response {sock id data} {
    fcgi::send $sock STDOUT      $id "Content-Type: text/plain\r\n\r\n"
    fcgi::send $sock STDOUT      $id "Hello Tcl FastCGI\n"
    fcgi::send $sock STDOUT      $id "[clock format [clock seconds]]"
    fcgi::send $sock STDOUT      $id ""
    fcgi::send $sock END_REQUEST $id
  }
}


socket -server [list FastCgiApp::accept] 9000 

vwait forever
