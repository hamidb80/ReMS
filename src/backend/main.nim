import std/[nativesockets, threadpool]

import ./[server, bot, config]


when isMainModule:
    echo "Run on port: ", webServerPort
    spawn runBaleBot baleBotToken
    runWebServer Port webServerPort

