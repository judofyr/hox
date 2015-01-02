import hox/lite
import hox/app
import hox/server
import hox/router

import h2o
import json
import strtabs
import taputil

route("/json").get =
  proc(req: Request, res: Response) =
    res.status = 200

    res.add_header(TokenContentType, "application/json")

    var obj = newJObject()
    obj["message"] = newJString("Hello world!")
    res.finish($obj)

route("/plaintext").get =
  proc(req: Request, res: Response) =
    res.status = 200
    res.add_header(TokenContentType, "text/plain")
    res.finish("Hello World!")

route("/users/:name").get =
  proc(req: Request, res: Response) =
    res.status = 200
    res.finish("Hello " & req.captures["name"])

var s = newServer()
s.listen(7890)
s.root("/").mount(liteApp)
s.runThreads(4)

