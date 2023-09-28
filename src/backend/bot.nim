import std/[asyncdispatch, options, os, tables]
import bale


let
    token = getEnv "BALE_BOT_TOKEN"
    bot = newBaleBot token

template forever(body): untyped =
    while true:
        body

let botKeyBoard = some ReplyKeyboardMarkup(
    keyboard: some @[@[
    KeyboardButton(text: "login code")]])

proc main =
    var skip = -1

    forever:
        try:
            let updates = waitFor bot.getUpdates(offset = skip+1)
            echo (updates.len, skip)

            for u in updates:
                skip = u.id
                if u.msg.isSome:
                    let
                        msg = u.msg.get
                        chid = msg.chat.id

                    discard waitFor bot.sendMessage(chid, "wow",
                            reply_markup = botKeyBoard)

        except:
            echo "error"

when isMainModule: main()
