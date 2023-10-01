import ../database/[models, dbconn]

when isMainModule:
    !! db.createTables()
    !! db.addAdminUser()
    !! db.defaultPalette()
