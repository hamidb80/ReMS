import std/[json, options, paths]

import ponairi

import ../../common/[types, datastructures]
import ../database/[models, logic, queries]
import ../settings


type
  Theme = object
    bg, fg: string

  Palette1 = object
    name: string
    colors: seq[Theme]


proc loadColors(jsonFilePath: string): seq[ColorTheme] = 
    let 
        j = parseJson readfile jsonFilePath
        palettes = j.to(seq[Palette1])

    var allColors: seq[Theme]

    for p in palettes:
        add allColors, p.colors

    for c in allColors:
        let 
            b = parseHexColorPack c.bg
            f = parseHexColorPack c.fg
    
        add result, ColorTheme(bg: b, fg: f, st: f)

proc defaultPalette(db: DbConn) =
    db.insert Palette(
        name: "default",
        colorThemes: defaultColorThemes)

proc addAdminUser(db: DbConn) =
    let uid = db.newUser("admin", "admin user", true, umTest)
    debugecho "---------------------------"
    debugecho defaultAdminPass
    db.addSigninPass(uid, defaultAdminPass)

proc createTables(db: DbConn) =
    db.create(
        User,
        Profile,
        AuthCode,
        Asset,
        Note,
        Board,
        Tag,
        Relation,
        RelsCache,
        Palette)

proc initDb* =
    let db = open(appDbPath, "", "", "")
    createTables db
    try:
        addAdminUser   db
        defaultPalette db
    except:
        discard


when isMainModule:
    initDb()
