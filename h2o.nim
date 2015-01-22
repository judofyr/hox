{.link:"libh2o.a".}
{.passL:"-lssl -lcrypto".}

import posix/posix
import net

type
  Vector*[T] = object
    entries: ptr T
    size: csize
    capacity: csize

  SocketCb = proc(sock: ptr Socket, err: cint) {.cdecl.}

  LinkList = object
    next: ptr LinkList
    prev: ptr LinkList

  IOVec* = object
    base: ptr cchar
    len*: csize

  Globalconf* = object
    hosts: Vector[Hostconf]
    configurations: LinkList
    server_name: IOVec
    max_request_entity_size: csize
    req_timeout: uint64
    upgrade_to_http2: int
    idle_timeout: uint64
    max_concurrent_requests_per_connection: csize
    max_streams_for_priority: csize
    num_config_slots: csize

  Hostconf* = object
    global: ptr Globalconf
    hostname: IOVec
    paths: Vector[Pathconf]
    fallback_path: Pathconf

  Pathconf* = object
    host: ptr Hostconf
    path: IOVec
    handlers: Vector[ptr Handler]
    filters: Vector[ptr Filter]
    loggers: Vector[ptr Logger]

  TimeoutEntry = object
    registered_at: uint64
    cb: pointer
    link: LinkList

  Timeout* = object
    timeout: uint64
    link: LinkList
    entries: LinkList

  Token = object
    buf: IOVec
    a, b, c: cchar

  Loop* = object
  Socket* = object
    data*: pointer

  Context* = object
    loop: ptr Loop
    zero_timeout: Timeout
    globalconf: ptr Globalconf
    req_timeout: Timeout
    idle_timeout: Timeout
    module_configs: ptr pointer
    uv_now_at: uint64
    tv_at: Timeval
    value: pointer

  Header* = object
    name*: ptr IOVec
    value*: IOVec

  Headers* = Vector[Header]

  Timestamp = object
    at: Timeval
    str: pointer

  Conn* = object
  MemPool = object
    chunks: pointer
    chunk_offset: csize
    shared_refs: pointer
    directs: pointer

  MemPoolPtr* = ptr MemPool

  Res* = object
    status*: cint
    reason*: cstring
    content_length*: csize
    headers*: Headers

  Req* = object
    conn: ptr Conn
    pathconf: ptr Pathconf
    authority*: IOVec
    meth*: IOVec
    path*: IOVec
    path_normalized*: IOVec
    scheme*: IOVec
    version*: cint
    headers*: Headers
    entity*: IOVec
    processed_at: Timestamp
    res*: Res
    bytes_sent: csize
    http1_is_persistent: cint
    upgrade: IOVec
    generator: ptr Generator
    ostr_top: pointer
    ostr_init_index: csize
    timeout_entry: TimeoutEntry
    pool*: MemPool

  Generator* = object
    proceed*: proc(self: ptr Generator, req: ptr Req) {.cdecl.}
    stop*: proc(self: ptr Generator, req: ptr Req) {.cdecl.}

  Handler* = object
    config_slot: csize
    on_context_init: proc(self: ptr Handler, ctx: ptr Context): pointer {.cdecl.}
    on_context_dispose: proc(self: ptr Handler, ctx: ptr Context) {.cdecl.}
    dispose: proc(self: ptr Handler) {.cdecl.}
    on_req*: proc(self: ptr Handler, req: ptr Req): cint {.cdecl.}

  Filter* = object
    config_slot: csize

  Logger* = object
    config_slot: csize

const
  H2O_SOCKET_FLAG_IS_ACCEPT* = 0x20

proc h2o_config_init*(config: ptr Globalconf) {.importc.}
proc h2o_config_register_host*(config: ptr Globalconf, hostname: cstring): ptr Hostconf {.importc.}
proc h2o_config_register_path*(hostconf: ptr Hostconf, pathname: cstring): ptr Pathconf {.importc.}
proc h2o_create_handler*(pathconf: ptr Pathconf, sz: csize): ptr Handler {.importc.}
proc h2o_file_register*(pathconf: ptr Pathconf, path: cstring, index_files: ptr cstring, mimemap: pointer, flags: cint): pointer {.importc.}

proc h2o_strdup*(pool: ptr MemPool, s: cstring, len: csize): IOVec {.importc.}

proc h2o_evloop_create*(): ptr Loop {.importc.}
proc h2o_evloop_socket_create*(loop: ptr Loop, fd: SocketHandle, address: ptr Sockaddr, addrlen: SockLen, flags: cint): ptr Socket {.importc.}
proc h2o_evloop_socket_accept*(sock: ptr Socket): ptr Socket {.importc.}
proc h2o_socket_read_start*(sock: ptr Socket, cb: SocketCb) {.importc.}
proc h2o_evloop_run*(loop: ptr Loop):cint {.importc.}

proc h2o_context_init*(ctx: ptr Context, loop: ptr Loop, config: ptr Globalconf) {.importc.}

proc h2o_http1_accept*(ctx: ptr Context, sock: ptr Socket) {.importc.}
proc h2o_start_response*(req: ptr Req, generator: ptr Generator) {.importc.}
proc h2o_find_header*(headers: ptr Headers, name: ptr Token, cursor: int): int {.importc.}
proc h2o_add_header*(pool: ptr MemPool, headers: ptr Headers, name: ptr Token, value: cstring, valuelen: csize) {.importc.}
proc h2o_add_header_by_str*(pool: ptr MemPool, headers: ptr Headers, name: cstring, namelen: csize, maybe_token: cint, value: cstring, valuelen: csize) {.importc.}
proc h2o_send*(req: ptr Req, bufs: ptr IOVec, bufcnt: csize, is_final: cint) {.importc.}

proc `+`[T](base: ptr T, x: int): ptr T=
  let address = cast[int](base) + sizeof(T) * x
  return cast[ptr T](address)

proc `[]`[T](base: ptr T, x: int): T =
  return (base + x)[]

proc `[]`*[T](vec: Vector[T], x: int): T =
  return (vec.entries + x)[]

proc len*(vec: Vector): int = vec.size

proc `$`*(str: IOVec): string =
  result = newString(str.len)
  for i in 0..str.len-1:
    result[i] = str.base[i]

proc `==`*(x: IOVec, y: string): bool =
  if x.len != y.len:
    return false

  for i in 0..x.len-1:
    if x.base[i] != y[i]:
      return false

  return true

proc `[]`*(str: IOVec, idx: int): char =
  # TODO: Bounds checking
  return str.base[idx]

proc substr*(str: IOVec, first: int): IOVec =
  result.base = str.base + first
  result.len = str.len - first

proc substr*(str: IOVec, first: int, last: int): IOVec =
  result.base = str.base + first
  result.len = last - first + 1

proc newIOVec*(req: ptr Req, data: string): IOVec =
  return h2o_strdup(addr(req.pool), cstring(data), data.len)

proc newIOVec*(data: string): IOVec =
  return IOVec(base: cast[ptr cchar](cstring(data)), len: data.len)

type
  TokenList* = enum
    TOKEN_AUTHORITY, TOKEN_METHOD, TOKEN_PATH, TOKEN_SCHEME, TOKEN_STATUS,
    TOKEN_ACCEPT, TOKEN_ACCEPT_CHARSET, TOKEN_ACCEPT_ENCODING,
    TOKEN_ACCEPT_LANGUAGE, TOKEN_ACCEPT_RANGES,
    TOKEN_ACCESS_CONTROL_ALLOW_ORIGIN, TOKEN_AGE, TOKEN_ALLOW,
    TOKEN_AUTHORIZATION, TOKEN_CACHE_CONTROL, TOKEN_CONNECTION,
    TOKEN_CONTENT_DISPOSITION, TOKEN_CONTENT_ENCODING, TOKEN_CONTENT_LANGUAGE,
    TOKEN_CONTENT_LENGTH, TOKEN_CONTENT_LOCATION, TOKEN_CONTENT_RANGE,
    TOKEN_CONTENT_TYPE, TOKEN_COOKIE, TOKEN_DATE, TOKEN_ETAG, TOKEN_EXPECT,
    TOKEN_EXPIRES, TOKEN_FROM, TOKEN_HOST, TOKEN_HTTP2_SETTINGS,
    TOKEN_IF_MATCH, TOKEN_IF_MODIFIED_SINCE, TOKEN_IF_NONE_MATCH,
    TOKEN_IF_RANGE, TOKEN_IF_UNMODIFIED_SINCE, TOKEN_LAST_MODIFIED, TOKEN_LINK,
    TOKEN_LOCATION, TOKEN_MAX_FORWARDS, TOKEN_PROXY_AUTHENTICATE,
    TOKEN_PROXY_AUTHORIZATION, TOKEN_RANGE, TOKEN_REFERER, TOKEN_REFRESH,
    TOKEN_RETRY_AFTER, TOKEN_SERVER, TOKEN_SET_COOKIE,
    TOKEN_STRICT_TRANSPORT_SECURITY, TOKEN_TRANSFER_ENCODING, TOKEN_UPGRADE,
    TOKEN_USER_AGENT, TOKEN_VARY, TOKEN_VIA, TOKEN_WWW_AUTHENTICATE

var tokens {.importc:"h2o__tokens".}: Token

proc tokenPtr*(token: TokenList): ptr Token =
  addr(tokens) + int(token)

