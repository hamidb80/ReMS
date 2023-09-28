## https://andrejgajdos.com/how-to-create-a-link-preview/ 

import std/[httpclient, xmltree, htmlparser, strutils]


func findlen(a, b: string): int = 
    let i = a.find b
    if i == -1: -1
    else: i + b.len

template `or`(a,b: string): untyped =
    if a == "": b
    else: a



var client = newHttpClient()
let
    body = client.getContent("https://vrgl.ir/4eVx3")
    s = body.find "<head>"
    t = body.findlen "</head>"
    h = body[s ..< t]
    x = parseHtml h

writefile "play.html", h


for el in x:
    if el.kind == xnElement:
        case el.tag
        of "title": discard
        of "meta": 
            echo el.attr"name" or el.attr"property"
        of "link": 
            # case el.attr"rel"
            # of 
            discard
        else: 
            discard

