import hox/app
import hox/server
import hox/router
import macros

var liteApp* = newApp()

proc route*(pattern: string): ref Router[Action] =
  return liteApp.router.route(pattern)

proc path*(pathname: string): ref Router[Action] =
  return liteApp.router.path(pathname)

