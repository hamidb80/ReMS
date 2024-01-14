import std/[os, strutils]


proc getEnvSafe(varname: string): string =
    result = getEnv varname
    if isEmptyOrWhitespace result:
        raise newException(ValueError, "the enviroment variable '" & varname & "' is not set")

let
    appDir* = getEnvSafe "APP_DIR"
    appSaveDir* = appDir / "resources"
    appDbPath* = appDir / "db.sqlite3"

    defaultAdminPass* = getEnvSafe "DEFAULT_ADMIN_PASS"

    jwtSecret* = getEnvSafe "JWT_KEY"
    webServerPort* = parseInt getEnvSafe "WEB_SERVER_PORT"

    baleBotToken* = getEnvSafe "BALE_BOT_TOKEN"
    adminBaleIds* = [
        1939572971,
        1395715069]
