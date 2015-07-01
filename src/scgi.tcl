

#======================================================================#
# SCGI: A Simple Common Gateway Interface alternative                  #
#======================================================================#

namespace eval scgi {

  proc print {sock data} {
    puts -nonewline $sock $data
  }

  proc println {sock data} {
    puts -nonewline $sock "$data\r\n"
  }

  proc netstring {data} {
    return [format "%s:%s," [string length $data] $data]
  }

  proc accept {sock application} {
    #-- upvar $headvar header
    #-- upvar $bodyvar body

    set buffer [read $sock 1024]
    set idx [string first ":" $buffer]

    set header_length [string range $buffer 0 $idx-1]
    set header_read   [expr {[string length $buffer] - $idx - 1}]

    #  include the trailing char ','
    if {$header_read <= $header_length} {
      append buffer [read $sock [expr {$header_length - $header_read + 1}]]
    }

    incr idx
    set header [dict create]
    foreach {name value} [split [string range $buffer $idx $idx+$header_length] "\0"] {
      if {$name eq ","} break

      dict set header $name $value
    }

    incr idx $header_length
    incr idx
    set buffer [string range $buffer $idx end]

    set body_length [dict get $header CONTENT_LENGTH]
    set body_read   [string length $buffer]

    if {$body_read < $body_length} {
      append buffer [read $sock [expr {$body_length - $body_read}]]
    }

    set body $buffer

    $application $header $body

    close $sock

    return 1
  }

  proc request {sock header body} {
    set buffer ""

    append buffer "CONTENT_LENGTH" [string length $body]
    append buffer "SCGI"           "1"

    dict foreach {name value} $header {
      append buffer $name "\0" $valuue "\0"
    }


    print $sock [netstring $buffer]

    print $sock $body

    return
  }

  proc response {sock header body} {

    dict foreach {name value} $header {
      println $sock "$name: $value"
    }

    println ""

    print   $body
    
    return
  }

}

return

#=================================================================================#
# Notes                                                                           #
#=================================================================================#

  * Duplicate names are not allowed in the headers. 
  * The first header must be "CONTENT_LENGTH"
  * Must have header with the name "SCGI" and a value of "1".
  * Standard CGI environment variables should be provided as SCGI headers.

  * close the connection after response
