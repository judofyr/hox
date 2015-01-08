import hox/server
import hox/router
import strtabs
import h2o

type
  Action* = proc(tx: Transaction)

  Hook* = tuple
    before: proc(tx: var Transaction): bool {.gcsafe, closure.}
    after: proc(tx: var Transaction) {.gcsafe, closure.}

  App* = object of BasicApp
    hooks*: seq[Hook]
    router*: ref Router[Action]

  Transaction* = object of BasicTransaction
    app*: ref App
    captures*: StringTableRef
    data: pointer

proc newApp*(): ref App =
  new(result)
  result.router = newRouter[Action]()
  newSeq(result.hooks, 0)

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
  proc before(tx: var Transaction): bool =
    var data = new(T)
    init(data)
    tx.setData(data)

  proc after(tx: var Transaction) {.closure.} =
    tx.clearData(T)

  app.hooks.add((before, after))

method call(app: ref App, tx: BasicTransaction): bool =
  let
    captures = newStringTable(modeCaseSensitive)
    h2o_req = tx.h2o_req

  var action: Action
  if not app.router.match(action, captures, h2o_req.meth, h2o_req.path_normalized):
    return false

  var newTx = Transaction(app: app, h2o_req: h2o_req, captures: captures)
  result = true

  # Run hooks
  var i = 0
  while i < app.hooks.len:
    let filter = app.hooks[i].before
    if not filter.isNil:
      if filter(newTx):
        # We're done!
        break
    i += 1

  # If we managed to get through all the hooks, run the main action
  if i == app.hooks.len:
    action(newTx)

  # Now run the after-hooks in backwards order, skipping the first
  while i > 0:
    i -= 1
    let hook = app.hooks[i].after
    if not hook.isNil:
      hook(newTx)

