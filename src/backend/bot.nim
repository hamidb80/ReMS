import std/[asyncdispatch, options, os, tables, random, times, json]

import ./database/[dbconn, models]
import ../common/[types]
import ponairi

import bale
import questionable

# XXX save tokens in sqlite database

randomize()

let
    token = getEnv "BALE_BOT_TOKEN"
    bot = newBaleBot token

template forever(body): untyped =
    while true:
        body

const
    loginD = "/login"
    startD = "/start"

let botKeyBoard = some ReplyKeyboardMarkup(
    keyboard: some @[@[
    KeyboardButton(text: loginD)]])

proc randCode(size: Positive): string = 
    for _ in 1..size:
        add result, rand '0'..'9'

proc genLoginCode(u: bale.User): string = 
    result = randCode 6
    !!db.insert Invitation(
        secret: result, 
        timestamp: toUnixtime now(), 
        data: JsonNode u)

proc main =
    var skip = -1

    forever:
        try:
            let updates = waitFor bot.getUpdates(offset = skip+1)
            echo (updates.len, skip)

            for u in updates:
                skip = u.id
                if msg =? u.msg and text =? msg.text:
                    let chid = msg.chat.id

                    case text
                    of loginD:
                        let lcode = genLoginCode msg.frm
                        discard waitFor bot.sendMessage(chid, lcode)
                        discard waitFor bot.sendMessage(chid, "enter this code in the site login page")

                    of startD:
                        discard waitFor bot.sendMessage(chid,
                            "Hey Choose from keyboard",
                            reply_markup = botKeyBoard)

                    else:
                        discard

        except:
            echo "error"

when isMainModule: 
    main()
