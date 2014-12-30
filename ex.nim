import hox/app
import hox/server
import hox/router

import h2o
import json
import strtabs
import taputil

var ex = newApp()

proc jsonAction(req: Request, res: Response) =
  res.status = 200

  res.add_header(TokenContentType, "application/json")

  var obj = newJObject()
  obj["message"] = newJString("Hello world!")
  res.finish($obj)

proc showProfile(req: Request, res: Response) =
  res.status = 200
  res.add_header(TokenContentType, "text/plain")
  res.finish("Welcome: " & req.captures["user_id"])

ex.router.tap:
  path("/users").tap:
    param("user_id").tap:
      get(showProfile)

  path("/json").tap:
    get(jsonAction)

var s = newServer()
s.listen(7890)
s.root("/").mount(ex)
s.run

