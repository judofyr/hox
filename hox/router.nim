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
    m.charAt(int) is char
    m.substr(int) is m
    m.substr(int, int) is m
    `==`(m, string) is bool

proc newRouter*[T](): ref Router[T] =
  new(result)
  newSeq(result.children, 0)
  newSeq(result.targets, 0)

proc path*[T](self: ref Router[T], pathname: string): ref Router[T] =
  result = newRouter[T]()
  self.children.add((pathname, result))

proc param*[T](self: ref Router[T], name: string): ref Router[T] =
  result = newRouter[T]()
  self.param_child = result
  self.param_name = name

proc to*[T](self: ref Router[T], meth: string, target: T): ref Router[T] {.discardable.} =
  result = self
  self.targets.add((meth, target))

proc get*[T](self: ref Router[T], target: T): ref Router[T] {.discardable.} =
  self.to("GET", target)

proc startsWith[T](base: T, prefix: string): bool =
  for i in 0..prefix.len-1:
    if base.charAt(i) != prefix[i]:
      return false
  return true

proc match*[T](self: ref Router[T], res: var T, captures: StringTableRef, meth: Matcher, path: Matcher): bool =
  if path.len == 0:
    for target in self.targets:
      if meth == target.meth:
        res = target.val
        return true

  for child in self.children:
    let nextChar = path.charAt(child.path.len)
    if nextChar == '\0' or nextChar == '/':
      if path.startsWith(child.path):
        let rest = path.substr(child.path.len)
        if child.router.match(res, captures, meth, rest):
          return true

  if path.len < 2:
    return

  if not self.param_child.isNil:
    var i = 1
    while true:
      let thisChar = path.charAt(i)
      if thisChar == '\0' or thisChar == '/':
        let 
          capture = path.substr(1, i-1)
          rest = path.substr(i)
        captures[self.param_name] = $capture
        return self.param_child.match(res, captures, meth, rest)
      i += 1

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

