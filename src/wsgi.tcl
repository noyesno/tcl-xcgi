
#------------------------------------------------------------#
# Client/Framework                                           #
#------------------------------------------------------------#
proc application {environ reponse} {
  set status "200 OK"
  dict set headers "Content-Type" "text/plain"

  $response $status $headers

  return "Hello World!"
}


#------------------------------------------------------------#
# Server/Gateway                                             #
#------------------------------------------------------------#

namespace eval wsgi {

  proc run {application} {
    set environ [array get ::env]

    dict set environ "wsgi.input"        stdin
    dict set environ "wsgi.erros"        stderr
    dict set environ "wsgi.version"      [list 1 0]
    dict set environ "wsgi.multithread"  0
    dict set environ "wsgi.multiprocess" 1
    dict set environ "wsgi.run_once"     1

    dict set environ "wsgi.url_scheme"   "http"

    dict set environ REQUEST_METHOD   ""
    dict set environ SCRIPT_NAME      ""
    dict set environ PATH_INFO        ""
    dict set environ QUERY_STRING     ""
    dict set environ CONTENT_TYPE     ""
    dict set environ CONTENT_LENGTH   ""
    dict set environ SERVER_NAME      ""
    dict set environ SERVER_PORT      ""
    dict set environ SERVER_PROTOCOL  "HTTP/1.1"
    dict set environ HTTP_*           ""

    set result [$application $environ [namespace current]::response] 

    foreach data $result {
      write $data
    }
  }

  proc send_header {status headers} {
    puts "Status: $status"
    dict for {name value} $headers {
      puts "$name:  $value"
    }
    puts ""
    fconfigure stdout -encoding binary -translation binary
  }

  proc write {data} {
    puts -nonewline $data
    flush
  }

  proc response {status headers} {
    send_header $status $headers  
  }
}

#------------------------------------------------------------#
# Middleware                                                 #
#------------------------------------------------------------#

TODO
