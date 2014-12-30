import hox/server
import hox/router
import strtabs
import h2o

type
  Action* = proc(req: Request, res: Response)

  App* = object of BasicApp
    router*: ref Router[Action]

  Request* = object of BasicRequest
    captures*: StringTableRef

  Response* = object of BasicResponse


proc newApp*(): ref App =
  new(result)
  result.router = newRouter[Action]()

method call(self: ref App, req: BasicRequest, res: BasicResponse): bool =
  var
    action: Action
    newReq: Request
    newRes: Response

  let captures = newStringTable(modeCaseSensitive)

  if self.router.match(action, captures, req.h2o_req.meth, req.h2o_req.path_normalized):
    req.copyTo(newReq)
    res.copyTo(newRes)
    newReq.captures = captures
    action(newReq, newRes)
    return true
  else:
    return false

