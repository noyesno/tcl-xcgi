#!/path/to/scgi.tm

proc scgi::respond {sock header body} {

  if {[dict exist $header SCRIPT_FILENAME]} {
    set script_file [dict get $header SCRIPT_FILENAME]

    set interp [interp create]

    dict for {key value} $header {
      array set ::env [list $key $value]
    }

    $interp alias puts   scgi::print   $sock
    $interp alias header scgi::println $sock

    $interp eval source $script_file

    dict for {key value} $header {
      array unset ::env $key
    }

    interp delete $interp

    return
  }

  scgi::println $sock "HTTP/1.1 200 OK"
  #scgi::println $sock "Status: 200 OK"
  #scgi::println $sock "Date: Wed, 09 Sep 2015 07:13:51 GMT"
  scgi::println $sock "Content-Type: text/plain"
  scgi::println $sock "Connection: close"

  scgi::println $sock ""
  scgi::println $sock $header
  scgi::println $sock "hello [clock seconds]"
}

