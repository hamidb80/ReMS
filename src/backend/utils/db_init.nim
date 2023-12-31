import std/[json, sha1, options]

import ponairi

import ../../common/[types, datastructures]
import ../database/[models, queries]
import ../config

type
  Theme = object
    bg, fg: string

  Palette1 = object
    name: string
    colors: seq[Theme]


# proc loadColors(jsonFilePath: string): seq[ColorTheme] = 
#     let 
#         j = parseJson readfile jsonFilePath
#         palettes = j.to(seq[Palette1])

#     var allColors: seq[Theme]

#     for p in palettes:
#         add allColors, p.colors

#     for c in allColors:
#         let 
#             b = parseHexColorPack c.bg
#             f = parseHexColorPack c.fg
    
#         add result, ColorTheme(bg: b, fg: f, st: f)

proc defaultPalette*(db: DbConn) =
    db.insert Palette(
        name: "default",
        colorThemes: @[
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
    ])

proc addAdminUser*(db: DbConn) =
    let uid = db.newUser("admin", "admin user", true)

    db.insert Auth(
        user: uid,
        hashed_pass: some secureHash defaultAdminPass)

proc addCommonTags*(db: DbConn) =
    db.insert commonTags()

proc createTables*(db: DbConn) =
    db.create(
        User,
        Invitation,
        Auth,
        Asset,
        Note,
        Board,
        Tag,
        Relation,
        RelationsCache,
        Palette)

proc initDb* =
    let db = open(appDbPath, "", "", "")
    createTables db
    try:
        addAdminUser db
        defaultPalette db
        addCommonTags db
    except:
        discard

when isMainModule:
    initDb()
