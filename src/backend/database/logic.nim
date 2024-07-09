import std/[json, algorithm, strutils, options]

import ./models
import ../../common/[types, datastructures, conventions]

# ------------------------------------------

template tableName*(t: type Board): untyped = "Board"
template tableName*(t: type Asset): untyped = "Asset"
template tableName*(t: type Note): untyped  = "Note"

template columnName*(t: type Board): untyped = "board"
template columnName*(t: type Asset): untyped = "asset"
template columnName*(t: type Note): untyped  = "note"

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
  of qoExists:    "??"
  of qoNotExists: "?!"
  of qoLess:      "<"
  of qoLessEq:    "<="
  of qoEq:        "=="
  of qoNotEq:     "!="
  of qoMoreEq:    ">="
  of qoMore:      ">"
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


const defaultColorThemes* = @[
    ColorTheme(bg: 0xffffff_0, fg: 0x889bad_a, st: 0xa5b7cf_a), # transparent
    c(0xffffff, 0x889bad, 0xa5b7cf), # white
    c(0xecedef, 0x778696, 0x9eaabb), # smoke
    c(0xdfe2e4, 0x617288, 0x808fa6), # road
    c(0xfef5a6, 0x958505, 0xdec908), # yellow
    c(0xffdda9, 0xa7690e, 0xe99619), # orange
    c(0xffcfc9, 0xb26156, 0xff634e), # red
    c(0xfbc4e2, 0xaf467e, 0xe43e97), # peach
    c(0xf3d2ff, 0x7a5a86, 0xc86fe9), # pink
    c(0xdac4fd, 0x7453ab, 0xa46bff), # purple
    c(0xd0d5fe, 0x4e57a3, 0x7886f4), # purpleLow
    c(0xb6e5ff, 0x2d7aa5, 0x399bd3), # blue
    c(0xadefe3, 0x027b64, 0x00d2ad), # diomand
    c(0xc4fad6, 0x298849, 0x25ba58), # mint
    c(0xcbfbad, 0x479417, 0x52d500), # green
    c(0xe6f8a0, 0x617900, 0xa5cc08), # lemon
    c(0x424242, 0xececec, 0x919191), # dark
]

func defaultTag*(name: Str): Tag = Tag(
  label: name,
  icon: "fa-hashtag",
  show_name: true,
  theme: defaultColorThemes[1])

# ------------------------------------------

func setRelValue*(rel: var Relation, value: string) {.noJs.} =
  let cleaned = strip value
  if cleaned != "":
    rel.sval = some cleaned
    safeFail:
      rel.fval = some parseFloat cleaned
      rel.ival = some parseInt cleaned
