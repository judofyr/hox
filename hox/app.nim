import hox/server
import hox/router
import strtabs
import h2o

type
  Action* = proc(tx: Transaction)
  Filter* = proc(tx: Transaction): bool

  App* = object of BasicApp
    before_call*: seq[Filter]
    router*: ref Router[Action]

  Transaction* = object of BasicTransaction
    app*: ref App
    captures*: StringTableRef

proc newApp*(): ref App =
  new(result)
  result.router = newRouter[Action]()
  newSeq(result.before_call, 0)

method call(app: ref App, tx: BasicTransaction): bool =
  let
    captures = newStringTable(modeCaseSensitive)
    h2o_req = tx.h2o_req
    newTx = Transaction(app: app, h2o_req: h2o_req, captures: captures)

  for filter in app.before_call:
    if filter(newTx):
      return true

  var action: Action

  if app.router.match(action, captures, h2o_req.meth, h2o_req.path_normalized):
    action(newTx)
    return true
  else:
    return false

