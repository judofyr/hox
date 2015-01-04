import h2o
import net
import posix/posix
import os
import tables

import hox/headers

export h2o.TokenList, h2o.`==`, h2o.`$`

const StatusCodeData = {
  100: "Continue",
  101: "Switching Protocols",
  102: "Processing",
  200: "OK",
  201: "Created",
  202: "Accepted",
  203: "Non-Authoritative Information",
  204: "No Content",
  205: "Reset Content",
  206: "Partial Content",
  207: "Multi-Status",
  208: "Already Reported",
  226: "IM Used",
  300: "Multiple Choices",
  301: "Moved Permanently",
  302: "Found",
  303: "See Other",
  304: "Not Modified",
  305: "Use Proxy",
  307: "Temporary Redirect",
  308: "Permanent Redirect",
  400: "Bad Request",
  401: "Unauthorized",
  402: "Payment Required",
  403: "Forbidden",
  404: "Not Found",
  405: "Method Not Allowed",
  406: "Not Acceptable",
  407: "Proxy Authentication Required",
  408: "Request Timeout",
  409: "Conflict",
  410: "Gone",
  411: "Length Required",
  412: "Precondition Failed",
  413: "Payload Too Large",
  414: "URI Too Long",
  415: "Unsupported Media Type",
  416: "Range Not Satisfiable",
  417: "Expectation Failed",
  422: "Unprocessable Entity",
  423: "Locked",
  424: "Failed Dependency",
  426: "Upgrade Required",
  428: "Precondition Required",
  429: "Too Many Requests",
  431: "Request Header Fields Too Large",
  500: "Internal Server Error",
  501: "Not Implemented",
  502: "Bad Gateway",
  503: "Service Unavailable",
  504: "Gateway Timeout",
  505: "HTTP Version Not Supported",
  506: "Variant Also Negotiates",
  507: "Insufficient Storage",
  508: "Loop Detected",
  510: "Not Extended",
  511: "Network Authentication Required"
}

proc buildStatusCodeArray(): array[100..599, string] =
  var table = StatusCodeData.newTable
  for i in low(result)..high(result):
    if table.hasKey(i):
      result[i] = table[i]
    else:
      result[i] = table[(i div 100) * 100]

const StatusCodes* = buildStatusCodeArray()

type
  Server* = object
    config: Globalconf
    hostconf: ptr Hostconf
    listeners: seq[net.Socket]

  Root* = object
    pathconf: ptr Pathconf

  BasicTransaction* = object of RootObj
    h2o_req*: ptr Req

  Request* = object
    h2o_req*: ptr Req

  Response* = object
    h2o_req*: ptr Req

  BasicApp* = object of RootObj

  AppHandler = object
    super: Handler
    app: ref BasicApp

  AppGenerator = object
    super: Generator
    req: ptr Req
    current_data: string
    on_proceed*: proc()

proc newServer*(): ref Server =
  new(result)

  newSeq(result.listeners, 0)

  h2o_config_init(addr(result.config))

  result.hostconf = h2o_config_register_host(addr(result.config), "default")

## Apps

method call(app: ref BasicApp, tx: BasicTransaction): bool =
  return false

proc req*(tx: BasicTransaction): Request {.inline.} =
  result.h2o_req = tx.h2o_req

proc scheme*(req: Request): IOVec {.inline.} =
  return req.h2o_req.scheme

proc authority*(req: Request): IOVec {.inline.} =
  return req.h2o_req.authority

proc meth*(req: Request): IOVec {.inline.} =
  return req.h2o_req.meth

proc path*(req: Request): IOVec {.inline.} =
  return req.h2o_req.path_normalized

proc fullpath*(req: Request): IOVec {.inline.} =
  return req.h2o_req.path

proc querystring*(req: Request): IOVec {.inline.} =
  let fullpath = req.fullpath
  for i in 0..fullpath.len-1:
    if fullpath[i] == '?':
      return fullpath.substr(i+1)

proc headers*(req: Request): HeaderReader {.inline.} =
  result.base = addr(req.h2o_req.headers)

proc res*(tx: BasicTransaction): Response {.inline.} =
  result.h2o_req = tx.h2o_req

proc `status=`*(res: Response, code: int) =
  res.h2o_req.res.status = cint(code)
  res.h2o_req.res.reason = StatusCodes[code]

proc headers*(res: Response): HeaderWriter {.inline.} =
  result.base = addr(res.h2o_req.res.headers)
  result.pool = addr(res.h2o_req.pool)

proc on_proceed(self: ptr Generator, req: ptr Req) {.cdecl.} =
  var self = cast[ptr AppGenerator](self)
  self.current_data = nil
  if not self.on_proceed.isNil:
    self.on_proceed()

proc finish*(res: Response, data: string) =
  res.h2o_req.res.content_length = data.len

  var gen: Generator
  h2o_start_response(res.h2o_req, addr(gen))

  var data = newIOVec(data)
  h2o_send(res.h2o_req, addr(data), 1, 1)

proc start_response*(res: Response): ref AppGenerator =
  new(result)
  result.super.proceed = on_proceed
  result.req = res.h2o_req
  h2o_start_response(res.h2o_req, addr(result.super))

proc start_response*(res: Response, content_length: int): ref AppGenerator =
  res.h2o_req.res.content_length = content_length
  return res.start_response()

proc send*(self: ref AppGenerator, data: string) =
  doAssert(self.current_data.isNil)
  doAssert(not self.on_proceed.isNil)

  self.current_data = data

  var data = newIOVec(data)
  h2o_send(self.req, addr(data), 1, 0)

proc finish*(self: ref AppGenerator, data: string = nil) =
  doAssert(self.current_data.isNil)

  if data.isNil:
    h2o_send(self.req, nil, 0, 0)
  else:
    var data = newIOVec(data)
    h2o_send(self.req, addr(data), 1, 1)

proc on_req(self: ptr Handler, req: ptr Req): cint {.cdecl.} =
  let
    apphandler = cast[ptr AppHandler](self)
    tx = BasicTransaction(h2o_req: req)
  if apphandler.app.call(tx):
    return 0
  else:
    return -1

proc root*(server: ref Server, pathname: string): ref Root =
  new(result)
  result.pathconf = h2o_config_register_path(server.hostconf, pathname)

proc mount*(root: ref Root, app: ref BasicApp) =
  var handler = cast[ptr AppHandler](h2o_create_handler(root.pathconf, sizeof(AppHandler)))
  handler.super.on_req = on_req
  handler.app = app
  GC_ref(app)

proc mountFileServer*(root: ref Root, path: string) =
  discard h2o_file_register(root.pathconf, path, nil, nil, 0)

## Server

proc listen*(server: ref Server, port: uint) =
  var s = newSocket()
  s.setSockOpt(OptReuseAddr, true)
  s.bindAddr(Port(port))
  s.listen
  server.listeners.add(s)

proc on_accept(listener: ptr h2o.Socket, err: cint) {.cdecl.} =
  if err == -1:
    return

  # Try to accept as much as 16 new clients before we handle them
  for i in 1..16:
    var sock = h2o_evloop_socket_accept(listener)
    if sock.isNil:
      return

    var ctx = cast[ptr Context](listener.data)
    h2o_http1_accept(ctx, sock)

proc run*(server: ref Server) =
  var loop = h2o_evloop_create()
  var ctx: h2o.Context
  h2o_context_init(addr(ctx), loop, addr(server.config))

  var name: SockaddrIn
  var namelen = sizeof(name).SockLen
  let nameptr = cast[ptr SockAddr](addr(name))

  for listener in server.listeners:
    if getsockname(listener.getFd, nameptr, addr(namelen)) == -1:
      raiseOSError(osLastError())

    var sock = h2o_evloop_socket_create(loop, listener.getFd, nameptr, namelen, H2O_SOCKET_FLAG_IS_ACCEPT)
    sock.data = addr(ctx)
    h2o_socket_read_start(sock, on_accept)

  while true:
    discard h2o_evloop_run(loop)

when declared(system.TThread):
  proc runThreads*(server: ref Server, numThreads: int) =
    var thr: seq[TThread[ref Server]]
    newSeq(thr, numThreads)
    for i in 0..numThreads-1:
      createThread(thr[i], run, server)
    joinThreads(thr)

