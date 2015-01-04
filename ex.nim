import hox/lite
import hox/app
import hox/server
import hox/router
import hox/headers

import h2o
import json
import strtabs
import taputil

route("/json").get =
  proc(tx: Transaction) =
    tx.res.status = 200
    tx.res.headers.ContentType = "application/json"

    var obj = newJObject()
    obj["message"] = newJString("Hello world!")
    tx.res.finish($obj)

route("/plaintext").get =
  proc(tx: Transaction) =
    tx.res.status = 200
    tx.res.headers.ContentType = "text/plain"
    tx.res.finish("Hello World!")

route("/users/:name").get =
  proc(tx: Transaction) =
    tx.res.status = 200
    tx.res.finish("Hello " & tx.captures["name"])

import posix
signal(SIGPIPE, SIG_IGN)

var s = newServer()
s.listen(7890)
s.root("/").mount(liteApp)
s.run

