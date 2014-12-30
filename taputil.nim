import macros

macro tap*(base: expr, code: stmt): stmt {.immediate.} =
  let name = gensym()
  result = newStmtList()

  result.add(newNimNode(nnkPragma).add(newIdentNode("experimental")))

  result.add(newLetStmt(name, base))

  for line in code.children:
    if line.kind == nnkCall:
      if line[0].kind == nnkDotExpr and $line[0][1] == "tap":
        line[0][0][0] = newDotExpr(name, line[0][0][0])
        result.add(line)
        continue

    result.add(newBlockStmt(newStmtList(
      newNimNode(nnkUsingStmt).add(name),
      line
    )))

