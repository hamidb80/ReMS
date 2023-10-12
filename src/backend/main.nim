import std/[os, nativesockets, threadpool]

import ./[server, bot, config]
import utils/db_init


when isMainModule:
    initDb()
    spawn runBaleBot baleBotToken
    runWebServer Port webServerPort

