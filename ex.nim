import hox/server
import hox/router
import h2o
import json
import strtabs

type
  JsonApp = object of App

  MyReq = object of BasicRequest
    captures: StringTableRef

  MyRes = object of BasicResponse

type
  Action = proc(req: MyReq, res: MyRes)

proc jsonAction(req: MyReq, res: MyRes) =
  res.status = 200

  res.add_header(TokenContentType, "application/json")

  var obj = newJObject()
  obj["message"] = newJString("Hello world!")
  res.finish($obj)

var r = newRouter[Action]()
r.path("/json")
  .get(jsonAction)

method call(self: ref JsonApp, req: BasicRequest, res: BasicResponse): bool =
  var
    action: Action
    myReq: MyReq
    myRes: MyRes

  req.copyTo(myReq)
  res.copyTo(myRes)

  myReq.captures = newStringTable(modeCaseSensitive)

  if r.match(action, myReq.captures, req.h2o_req.meth, req.h2o_req.path_normalized):
    action(myReq, myRes)
    return true
  else:
    return false

var s = newServer()
s.listen(7890)
s.root("/").mount(new(JsonApp))
s.run

