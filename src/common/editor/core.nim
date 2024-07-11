import std/[tables, strutils, options, json, xmltree]
# import questionable
import ../[datastructures]
import ../../common/linear_markdown

type 
  TwActionKind = enum
    # takCreateElement

    takSetState

    takRemoveElement
    takSetInnerText

    takConvertMarkDown

    takRemoveClass
    takAddClass
    
    takSetAttr
    takRemoveAttr

    takConditional
    # takLoop

  TwValueKind = enum
    tvString
    tvDataRef

  TwValue = object
    kind: TwValueKind
    value: string

  TwAction = ref object
    kind: TwActionKind
    selector: string
    params: seq[TwValue]
    subActions: seq[TwAction]

  Twfunction = seq[TwAction]

  TwNode* = TreeNodeRaw[JsonNode]

  ComponentsTable* = TableRef[string, Component] ## components by name

  XmlEntityKind = enum
    xeText
    xeElement

  XmlEntity = object
    case kind: XmlEntityKind
    of xeText:    nil
    of xeElement:
      tag: string

  Component* = ref object
    name*: string
    entity*: XmlEntity
    
    init*: Twfunction
    
    # attachChild*: Twfunction
    # detachChild*: Twfunction

# ---------------------

# TODO add DSL
# TODO add 2-way binding for data & element

proc eval(v: TwValue, ctx: JsonNode): string = 
  case v.kind
  of tvString:  v.value
  of tvDataRef: ctx[v.value].getStr

proc toXml(
  ct: ComponentsTable,
  root: XmlNode,
  node: TwNode,
) =
  
  let 
    c = ct[node.name]
    wrapper = 
      case c.entity.kind
      of   xeText:    newText    ""
      of   xeElement: newElement c.entity.tag

  for ch in node.children:
    toXml ct, wrapper, ch

  for a in c.init:
    case a.kind
    of takSetInnerText: 
      wrapper.text = eval(a.params[0], node.data)
    else: 
      discard

  root.add wrapper



let components = @[
  Component(
    name: "root",
    entity: XmlEntity(kind: xeElement, tag: "div"),
  ),
  Component(
    name: "paragraph",
    entity: XmlEntity(kind: xeElement, tag: "p"),
  ),
  Component(
    name: "raw-text",
    entity: XmlEntity(kind: xeText),
    init: @[
      TwAction(
        selector: "",
        kind: takSetInnerText,
        params: @[
          TwValue(
            kind:  tvDataRef,
            value: "content",
          ) 
        ]
      )
    ]
  ),
  Component(
    name: "linear markdown",
    entity: XmlEntity(kind: xeElement, tag: "span"),
    init: @[
      TwAction(
        selector: "",
        kind: takSetInnerText,
        params: @[
          TwValue(
            kind:  tvDataRef,
            value: "content",
          )
        ]
      )
    ]
  ),
  Component(
    name: "image",
    entity: XmlEntity(kind: xeElement, tag: "img"),
    init: @[]
  ),

]

func toTable(cs: seq[Component]): ComponentsTable =
  result.new
  for c in cs:
    result[c.name] = c

when isMainModule:
  let
    ct = toTable components 
    tw = TwNode(
      name: "root",
      data: %* nil,
      children: @[
          TwNode(
              name: "paragraph",
              data: %*{
                  "inline": false,
                  "dir": "auto",
                  "align": "auto"
              },
              children: @[
                  TwNode(
                      name: "raw-text",
                      data: %*{
                          "content": "طرح مفهومی از یک سیستم کامپیوتری ( سخت افزار، سیستم عامل، برنامه ها، کاربر )",
                          "spaceAround": true
                      }
                  )
              ],
          ),
      ],
    )
  
  var wrapper = newElement "div"
  wrapper.attrs = toXmlAttributes {"class": "tw-content"}
  
  toXml ct, wrapper, tw
  echo wrapper
