import std/[os, nativesockets, threadpool]
import ./[server, bot, config]



when isMainModule:
    # var tport: Thread[Port]
    # var tbale: Thread[string]

    # createThread tport, runWebServer, Port webServerPort
    # createThread tbale, runBaleBot, baleBotToken

    # joinThreads tport
    # joinThreads tbale

    spawn runBaleBot baleBotToken
    runWebServer Port webServerPort

