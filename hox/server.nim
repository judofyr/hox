import h2o
import net
import posix/posix
import os

export h2o.TokenList, h2o.`==`, h2o.`$`

type
  Server* = object
    config: Globalconf
    hostconf: ptr Hostconf
    listeners: seq[net.Socket]

  Root* = object
    pathconf: ptr Pathconf

  BasicRequest* = object of RootObj
    h2o_req*: ptr Req

  BasicResponse* = object of RootObj
    h2o_req*: ptr Req

  App* = object of RootObj

  AppHandler = object
    super: Handler
    app: ref App

  AppGenerator = object
    super: Generator
    req: ptr Req
    in_flight: bool
    on_proceed*: proc()

proc newServer*(): ref Server =
  new(result)

  newSeq(result.listeners, 0)

  h2o_config_init(addr(result.config))

  result.hostconf = h2o_config_register_host(addr(result.config), "default")

proc copyTo*[F,T](self: F, child: var T) =
  let p = cast[ptr F](addr(child))
  p[] = self

## Apps

method call(self: ref App, req: BasicRequest, res: BasicResponse): bool =
  return false

proc `status=`*(res: BasicResponse, code: int) =
  res.h2o_req.res.status = cint(code)
  res.h2o_req.res.reason = "OK"

proc add_header*(res: BasicResponse, name: TokenList, value: string) =
  h2o_add_header(addr(res.h2o_req.pool), addr(res.h2o_req.res.headers), tokenPtr(name), value, value.len)

proc add_header*(res: BasicRequest, name: string, value: string) =
  h2o_add_header_by_str(addr(res.h2o_req.pool), addr(res.h2o_req.res.headers), name, name.len, 0, value, value.len)

proc on_proceed(self: ptr Generator, req: ptr Req) {.cdecl.} =
  var self = cast[ptr AppGenerator](self)
  self.in_flight = false
  if not self.on_proceed.isNil:
    self.on_proceed()

proc finish*(res: BasicResponse, data: string) =
  res.h2o_req.res.content_length = data.len

  var gen: Generator
  h2o_start_response(res.h2o_req, addr(gen))

  var data = res.h2o_req.newIOVec(data)
  h2o_send(res.h2o_req, addr(data), 1, 1)

proc start_response*(res: BasicResponse): ref AppGenerator =
  new(result)
  result.super.proceed = on_proceed
  result.req = res.h2o_req
  h2o_start_response(res.h2o_req, addr(result.super))

proc start_response*(res: BasicResponse, content_length: int): ref AppGenerator =
  res.h2o_req.res.content_length = content_length
  return res.start_response()

proc send*(self: ref AppGenerator, data: string) =
  doAssert(self.in_flight == false)
  doAssert(not self.on_proceed.isNil)

  self.in_flight = true

  var data = self.req.newIOVec(data)
  h2o_send(self.req, addr(data), 1, 0)

proc finish*(self: ref AppGenerator, data: string = nil) =
  doAssert(self.in_flight == false)

  if data.isNil:
    h2o_send(self.req, nil, 0, 0)
  else:
    var data = self.req.newIOVec(data)
    h2o_send(self.req, addr(data), 1, 1)

proc on_req(self: ptr Handler, req: ptr Req): cint {.cdecl.} =
  let
    apphandler = cast[ptr AppHandler](self)
    res = BasicResponse(h2o_req: req)
    req = BasicRequest(h2o_req: req)
  if apphandler.app.call(req, res):
    return 0
  else:
    return -1

proc root*(server: ref Server, pathname: string): ref Root =
  new(result)
  result.pathconf = h2o_config_register_path(server.hostconf, pathname)

proc mount*(root: ref Root, app: ref App) =
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
    if getsockname(listener.fd, nameptr, addr(namelen)) == -1:
      raiseOSError(osLastError())

    var sock = h2o_evloop_socket_create(loop, listener.fd, nameptr, namelen, H2O_SOCKET_FLAG_IS_ACCEPT)
    sock.data = addr(ctx)
    h2o_socket_read_start(sock, on_accept)

  while true:
    discard h2o_evloop_run(loop)

