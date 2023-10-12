import std/[nativesockets, threadpool, os]

import ./[server, bot, config]
import utils/db_init


when isMainModule:
    discard existsOrCreateDir appDir
    discard existsOrCreateDir appSaveDir
    initDb()

    spawn runBaleBot baleBotToken
    runWebServer Port webServerPort

