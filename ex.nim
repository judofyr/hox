import hox/lite
import hox/app
import hox/server
import hox/router

import h2o
import json
import strtabs
import taputil

path("/json").get =
  proc(req: Request, res: Response) =
    res.status = 200

    res.add_header(TokenContentType, "application/json")

    var obj = newJObject()
    obj["message"] = newJString("Hello world!")
    res.finish($obj)

path("/plaintext").get =
  proc(req: Request, res: Response) =
    res.status = 200
    res.add_header(TokenContentType, "text/plain")
    res.finish("Hello World!")

var s = newServer()
s.listen(7890)
s.root("/").mount(liteApp)
s.run

