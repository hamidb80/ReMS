import std/[json, algorithm]

import ./models
import ../../common/[types, datastructures]

# ------------------------------------------

template tableName*(t: type Board): untyped = "Board"
template tableName*(t: type Asset): untyped = "Asset"
template tableName*(t: type Note): untyped = "Note"

template columnName*(t: type Board): untyped = "board"
template columnName*(t: type Asset): untyped = "asset"
template columnName*(t: type Note): untyped = "note"

# ------------------------------------------

func hasValue*(rv: RelValueType): bool =
  rv != rvtNone

func hasValue*(t: Tag): bool =
  t.valueType != rvtNone

func isAdmin*(u: User): bool =
  u.role == urAdmin

func columnName*(vt: RelValueType): string =
  case vt
  of rvtNone: raise newException(ValueError, "'rvtNone' does not have column")
  of rvtStr: "sval"
  of rvtFloat: "fval"
  of rvtDate, rvtInt: "ival"

func isHidden*(lbl: RelMode): bool =
  lbl in rmForwarded .. rmNotification

func isInfix*(qo: QueryOperator): bool =
  qo in qoLess..qoSubStr

func `[]`*[V](s: seq[V], i: ConnectionPointKind): V =
  assert 2 == len s
  s[ord i]

func `$`*(qo: QueryOperator): string =
  case qo
  of qoExists: "??"
  of qoNotExists: "?!"
  of qoLess: "<"
  of qoLessEq: "<="
  of qoEq: "=="
  of qoNotEq: "!="
  of qoMoreEq: ">="
  of qoMore: ">"
  else: raise newException(ValueError, "invalid operator: " & $int(qo))

func `$`*(so: SortOrder): string =
  case so
  of Descending: "DESC"
  of Ascending: "ASC"

# ------------------------------------------

func newNoteData*: TreeNodeRaw[JsonNode] =
  TreeNodeRaw[JsonNode](
    name: "root",
    children: @[],
    data: newJNull())
