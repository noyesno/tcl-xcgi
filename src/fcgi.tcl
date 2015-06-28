
package provide fcgi 0.1


namespace eval fcgi {
  variable config  [dict create]
  variable clients [dict create]

  variable FCGI_LISTENSOCK_FILENO 0
  variable FCGI_HEADER_LEN  8 
  variable FCGI_VERSION 1


  #/** Values for FCGI_Header.type */#
  variable FCGI_BEGIN_REQUEST       1
  variable FCGI_ABORT_REQUEST       2
  variable FCGI_END_REQUEST         3
  variable FCGI_PARAMS              4
  variable FCGI_STDIN               5
  variable FCGI_STDOUT              6
  variable FCGI_STDERR              7
  variable FCGI_DATA                8
  variable FCGI_GET_VALUES          9
  variable FCGI_GET_VALUES_RESULT  10
  variable FCGI_UNKNOWN_TYPE       11
  variable FCGI_MAXTYPE            11
  variable FCGI_MINTYPE             1

  #/** Value for FCGI_Header.requestId */#
  variable FCGI_NULL_REQUEST_ID     0

  #/** Mask for FCGI_BeginRequestBody.flags */#
  variable FCGI_KEEP_CONN        1
  #/** Values for FCGI_BeginRequestBody.role */#
  variable FCGI_RESPONDER        1
  variable FCGI_AUTHORIZER       2
  variable FCGI_FILTER           3

  #/** Values for FCGI_EndRequestBody.protocolStatus */#
  variable FCGI_REQUEST_COMPLETE 0
  variable FCGI_CANT_MPX_CONN    1
  variable FCGI_OVERLOADED       2
  variable FCGI_UNKNOWN_ROLE     3

  #/** Variable names for FCGI_GET_VALUES / FCGI_GET_VALUES_RESULT records */#
  variable FCGI_MAX_CONNS  "FCGI_MAX_CONNS"
  variable FCGI_MAX_REQS   "FCGI_MAX_REQS"
  variable FCGI_MPXS_CONNS "FCGI_MPXS_CONNS"


  dict set config $FCGI_MAX_CONNS  1
  dict set config $FCGI_MAX_REQS   1
  dict set config $FCGI_MPXS_CONNS 0

  #---------------------------------------------------------------#
  proc config {sock key args} {
    variable clients

    set argc [llength $args]

    if {$argc == 0} {
      return [dict get $clients $sock $key]
    } elseif {$argc == 1} {
      set value [lindex $args 0]
      dict set clients $sock $key $value
    }
    # TODO: check error
  }

  proc accept {sock} {
    variable clients

    dict set clients $sock sock $sock

    fconfigure $sock -encoding binary -translation binary
  }

  proc destroy {sock} {
    variable clients

    dict unset clients $sock
  }
  #---------------------------------------------------------------#


  proc send {sock type id {data ""}} {
    variable FCGI_VERSION

    if {![string is integer $type]} {
      set type [set [namespace current]::FCGI_$type]
    }

    set contentData   $data
    set contentLength [string length $contentData]

    set paddingData   ""
    set paddingLength [expr {(8 - $contentLength&0x07)&0x07}]

    set reserved 0

    set packet [binary format "c c Su Su c c a$contentLength a$paddingLength" \
          $FCGI_VERSION $type $id $contentLength $paddingLength $reserved \
          $contentData $paddingData]

    puts -nonewline $sock $packet
    flush $sock
  }

  proc send/$FCGI_UNKNOWN_TYPE {sock id type} {
    variable FCGI_UNKNOWN_TYPE

    puts "DEBUG: FCGI_UNKNOWN_TYPE = $type"
    set data [binary format {cu a7} $type ""]
    send $sock $id $FCGI_UNKNOWN_TYPE
  }

  proc recv {sock} {
    set bytes [read $sock 8]

    if {[eof $sock]} {
      puts "DEBUG: closed"
      destroy $sock
      return 0
    }

    binary scan $bytes {c c Su Su cu c} version type id contentLength paddingLength reserved 

    set contentData [read $sock $contentLength]
    set paddingData [read $sock $paddingLength]

    puts "DEBUG: recv $version $type $id $contentLength $paddingLength"

    variable FCGI_MAXTYPE
    variable FCGI_MINTYPE
    if {$type > $FCGI_MAXTYPE || $type < $FCGI_MINTYPE} {
      send $sock UNKNOWN_TYPE $id $type
      return 1
    }

    recv/$type $sock $id $contentData $contentLength

    return 1
  }

  proc data2dict {data} {
    puts "DEBUG: data2dict ..."
    set skip 0
    set size [string length $data]

    set result [dict create]

    while {$skip < $size} {

      #-- binary scan $data "x$skip H64 H64 H64" hex1 hex2 hex3
      #-- puts "... hex = $hex1 $hex2 $hex3"

      binary scan $data "x$skip cu" nameLength
      if {$nameLength & 0x80} {
        binary scan $data "x$skip Iu" nameLength
        set nameLength [expr {$nameLength & 0x7fffffff}]
        incr skip 4
      } else {
        incr skip 1
      }

      binary scan $data "x$skip cu" valueLength
      if {$valueLength & 0x80} {
        binary scan $data "x$skip Iu" valueLength
        set valueLength [expr {$valueLength & 0x7fffffff}]
        incr skip 4
      } else {
        incr skip 1
      }

      binary scan $data "x$skip a$nameLength a$valueLength" name value
      dict set result $name $value
      #--# puts "DEBUG: ... $skip < $size, $nameLength, $valueLength $name = $value"

      incr skip $nameLength
      incr skip $valueLength
    }

    return $result
  }

  proc recv/$FCGI_BEGIN_REQUEST {sock id data args} {
    variable FCGI_RESPONDER
    variable FCGI_AUTHORIZER
    variable FCGI_FILTER

    binary scan $data {Su cu} role flags


    if {$role == $FCGI_RESPONDER} {
      puts "DEBUG: BEGIN_REQUEST = RESPONDER  (flags = $flags)"
    } elseif {$role == $FCGI_AUTHORIZER} {
      puts "DEBUG: BEGIN_REQUEST = AUTHORIZER (flags = $flags)"
    } elseif {$role == $FCGI_FILTER} {
      puts "DEBUG: BEGIN_REQUEST = FILTER (flags = $flags)"
    } else {
      puts "WARN: Unknow Request Role $role"
    }

    return 
  }

  proc recv/$FCGI_ABORT_REQUEST {sock id data args} {
    # TODO: send FCGI_END_REQUEST
    puts "DEBUG: abort_request = $role, $flags"
  }

  proc send/$FCGI_END_REQUEST {sock id} {
    variable FCGI_END_REQUEST
    variable FCGI_REQUEST_COMPLETE

    set appStatus 0
    set protocolStatus $FCGI_REQUEST_COMPLETE 
    puts "DEBUG: end_request = $appStatus, $protocolStatus"

    set data [binary format {Iu cu} $appStatus $protocolStatus]
    send $sock $FCGI_END_REQUEST $id $data
  }


  proc recv/$FCGI_PARAMS {sock id data args} {
    dict for {name value} [data2dict $data] {
      puts "DEBUG: PARARM $name = $value"
    }
  }


  proc recv/$FCGI_STDIN {sock id data size} {
    puts "DEBUG: STDIN  = $data"

    if {$size == 0} {
      [config $sock response] $sock $id $data
    }
  }

  proc recv/$FCGI_DATA {sock id data size} {
    puts "DEBUG: DATA = $data"
  }

  proc send/$FCGI_STDOUT {sock id data} {
    variable FCGI_STDOUT

    puts "DEBUG: STDOUT = $data"
    send $sock $FCGI_STDOUT $id $data
  }

  proc send/$FCGI_STDERR {sock id data} {
    puts "DEBUG: STDERR = $data"
  }



  proc recv/$FCGI_GET_VALUES {sock id data args} {
    variable config

    set query [data2dict $data]
    set result [dict create]

    dict for {name value} $query {
      puts "DEBUG: VALUES $name = $value"

      if {[dict exists $config $name]} {
        dict set result $name [dict get $config $name]
      }
    }
    
    # dict2data $result 
    # send ...
  }

}

return

FastCGI Record Type
-------------------

  * A discrete record: contains a meaningful unit of data all by itself.
  * A stream record: zero or more non-empty record (length!=0), plus an empty record (length=0).


  * FCGI_MAX_CONNS: maximum number of concurrent transport connections, e.g. "1" or "10".
  * FCGI_MAX_REQS: maximum number of concurrent requests, e.g. "1" or "50".
  * FCGI_MPXS_CONNS: "0" if does not multiplex connections, "1" otherwise.


  * The `appStatus` is an application-level status code. Each role documents its usage of appStatus.
  * The `protocolStatus` is a protocol-level status code; possible values are:
    * FCGI_REQUEST_COMPLETE: normal end of request.
    * FCGI_CANT_MPX_CONN: rejecting a new request. 
      e.g. sends concurrent requests to FCGI_MAX_REQS=1.
    * FCGI_OVERLOADED: rejecting a new request. 
      This happens when the application runs out of some resource, e.g. database connections.
    * FCGI_UNKNOWN_ROLE: rejecting a new request. 
      This happens when the Web server has specified a role that is unknown to the application.

