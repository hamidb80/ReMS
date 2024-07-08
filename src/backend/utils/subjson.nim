import std/[tables, options, strutils]
import pretty


type
  SubJsonKind* = enum
    sjLeaf
    sjBranch

  SubJson*[T] = ref object
    ## a subset of JSON which only has int..int
    case kind*: SubJsonKind
    of sjLeaf:    
        val*:     T
    of sjBranch: 
        entries*: Table[string, SubJson[T]]


func splitKey(nestedKey: string): seq[string] = 
    nestedKey.split '.'


func initBranch*[T]: SubJson[T] = 
    SubJson[T](kind: sjBranch)

func initLeaf[T](val: T): SubJson[T] = 
    SubJson[T](kind: sjLeaf, val: val)


func `{}`*[T](sj: SubJson[T], nestedKey: string): Option[T] =
    var curr = sj

    for k in splitKey nestedKey:
        if k in curr.entries:
            curr = curr.entries[k]
        else:
            return
    
    some curr.val

func `[]`*[T](sj: SubJson[T], nestedKey: string): T =
    get sj{nestedKey}

proc `[]=`*[T](sj: SubJson[T], nestedKey: string, val: T)  =
    var curr  = sj
    let parts = splitKey nestedKey

    for i, k in parts:
        if i == parts.high: 
            curr.entries[k] = initLeaf val

        elif k notin curr.entries:
            curr.entries[k] = initBranch[T]()

        curr = curr.entries[k]


when isMainModule:
    var root = initBranch[string]()

    for (k, v) in {
        "form": "sign up",
        "profile.name.first": "hamid",
        "profile.name.last": "bluri",
        "profile.age": "25"
    }:
        root[k] = v

    print root
    