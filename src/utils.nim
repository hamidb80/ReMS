import std/macros
import macroplus


macro caster*(def): untyped =
  ## support for cast in args,
  ##
  ## for example below procedure
  ## should treat `ev` as an `KonvaClickEvent` rather `JsObject`
  ## it is specially useful in event handling scenarios.
  ##
  ## proc callback(ev: JsObject as KonvaClickEvent) {.caster.} = ...

  var before = newStmtList()
  result = def

  for i, p in def.params:
    if i != 0: # return type
      for id in p[IdentDefNames]:
        let t = p[IdentDefType]
        if t.matchInfix "as":
          echo "changed ... ", id.strVal
          before.add newLetStmt(id, newTree(nnkCast, t[InfixRightSide], id))
          result.params[i][IdentDefType] = t[InfixLeftSide]

  result.body = newStmtList(before, result.body)
