tcl-xcgi: Tcl and Web Gateway Interface
=======================================

Explain and implementation with Tcl for CGI / FastCGI / SCGI / WSGI protocols.

## CGI

CGI = Common Gateway Interface

CGI make it possible to provide dynamic response through separate process.

Web server pass HTTP headers to CGI process through `%ENV` - environment variables.


## FastCGI

FastCGI appeared in mid-1990 to solve the performance issue of CGI that need spawn process for each request.

FastCGI do it by start CGI process once and use a stream to accept and serve multiple request.

## SCGI

SCGI = SimpleCGI = Simple Common Gateway Interface

SCGI is similar as FastCGI to use long-running process to serve mutiple request.

It's designed to be easier to parse. SCGI appeared in 2001.

## WSGI

WSGI = WEb Server Gateway Interface

WSGI appeared to define an interface for Python based web applications.


