import strutils
import strtabs

type
  Router*[T] = object
    children: seq[tuple[path: string, router: ref Router[T]]]
    param_name: string
    param_child: ref Router[T]
    targets: seq[tuple[meth: string, val: T]]

  Matcher = generic m
    $m is string
    m.len is int
    `[]`(m, int) is char
    m.substr(int) is m
    m.substr(int, int) is m
    `==`(m, string) is bool

proc newRouter*[T](): ref Router[T] =
  new(result)
  newSeq(result.children, 0)
  newSeq(result.targets, 0)

proc path*[T](self: ref Router[T], pathname: string): ref Router[T] =
  for i, child in self.children:
    if pathname == child.path:
      return child.router

  result = newRouter[T]()
  self.children.add((pathname, result))

proc param*[T](self: ref Router[T], name: string): ref Router[T] =
  if not self.param_child.isNil:
    return self.param_child

  result = newRouter[T]()
  self.param_child = result
  self.param_name = name

proc route*[T](self: ref Router[T], pattern: string): ref Router[T] =
  result = self

  var start = 0
  while start < pattern.len:
    let stop = pattern.find("/:", start)

    if stop > start:
      result = result.path(pattern.substr(start, stop-1))
      start = stop

    if stop == -1:
      result = result.path(pattern.substr(start))
      return
    else:
      var param_stop = pattern.find("/", stop+2)
      if param_stop == -1:
        param_stop = pattern.len

      result = result.param(pattern.substr(stop+2, param_stop-1))
      start = param_stop

proc to*[T](self: ref Router[T], meth: string, target: T) =
  self.targets.add((meth, target))

template deftarget(name: expr, meth: string) =
  proc `name`*[T](self: ref Router[T], target: T) =
    self.to(meth, target)

  proc `name =`*[T](self: ref Router[T], target: T) =
    self.to(meth, target)

deftarget(get, "GET")
deftarget(post, "POST")
deftarget(put, "PUT")
deftarget(delete, "DELETE")
deftarget(patch, "PATCH")

proc startsWith[T](base: T, prefix: string): bool =
  if prefix.len > base.len:
    return false

  for i in 0..prefix.len-1:
    if base[i] != prefix[i]:
      return false
  return true

proc match*[T](self: ref Router[T], res: var T, captures: StringTableRef, meth: Matcher, path: Matcher): bool =
  if path.len == 0:
    for target in self.targets:
      if meth == target.meth:
        res = target.val
        return true

  for child in self.children:
    if path.len > child.path.len:
      # Require slashes as separators
      if path[child.path.len] != '/':
        continue

    if path.startsWith(child.path):
      let rest = path.substr(child.path.len)
      if child.router.match(res, captures, meth, rest):
        return true

  if path.len < 2:
    return

  if not self.param_child.isNil:
    var i = 1
    while i < path.len:
      if path[i] == '/':
        break
      i += 1

    let
      capture = path.substr(1, i-1)
      rest = path.substr(i)
    captures[self.param_name] = $capture
    return self.param_child.match(res, captures, meth, rest)

when isMainModule:
  var r = newRouter[int]()
  r.path("/users")
    .get(1)
    .param("name")
      .get(2)

  var res: int
  var cap = newStringTable(modeCaseSensitive)
  echo r.match(res, cap, "GET", "/users/a")
  echo res
  echo cap

