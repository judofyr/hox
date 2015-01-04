import hox/server
import hox/router
import strtabs
import h2o

type
  Action* = proc(tx: Transaction)
  Filter* = proc(tx: var Transaction): bool

  App* = object of BasicApp
    before_call*: seq[Filter]
    after_call*: seq[Filter]
    router*: ref Router[Action]

  Transaction* = object of BasicTransaction
    app*: ref App
    captures*: StringTableRef
    data: pointer

proc newApp*(): ref App =
  new(result)
  result.router = newRouter[Action]()
  newSeq(result.before_call, 0)
  newSeq(result.after_call, 0)

proc data*(tx: Transaction, T: typedesc): ref T =
  return cast[ref T](tx.data)

proc clearData(tx: var Transaction, T: typedesc) =
  if not tx.data.isNil:
    let thing = cast[ref T](tx.data)
    GC_unref(thing)

proc setData[T](tx: var Transaction, thing: ref T) =
  tx.clearData(T)
  GC_ref(thing)
  tx.data = cast[pointer](thing)

proc setupData*[T](app: ref App, init: proc(data: ref T)) =
  app.before_call.add proc(tx: var Transaction): bool =
    var data = new(T)
    init(data)
    tx.setData(data)

  app.after_call.add proc(tx: var Transaction): bool =
    tx.clearData(T)

method call(app: ref App, tx: BasicTransaction): bool =
  let
    captures = newStringTable(modeCaseSensitive)
    h2o_req = tx.h2o_req

  var
    newTx = Transaction(app: app, h2o_req: h2o_req, captures: captures)

  for filter in app.before_call:
    if filter(newTx):
      return true

  var action: Action

  if app.router.match(action, captures, h2o_req.meth, h2o_req.path_normalized):
    action(newTx)

    for filter in app.after_call:
      if filter(newTx):
        return true

    return true
  else:
    return false

