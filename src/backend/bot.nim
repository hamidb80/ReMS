import std/[options, os, tables, random, times, json, sequtils, strutils, httpclient, macros]

import ponairi, questionable
import bale, bale/helper/stdhttpclient

import ./database/[dbconn, models, queries]
import ../common/[types]


randomize()


let
  token = getEnv "BALE_BOT_TOKEN"
  api = baleBotBaseApi token

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
  # TODO move to queries
  result = randCode rand 4..6
  !!db.insert Invitation(
      secret: result,
      timestamp: toUnixtime now(),
      data: JsonNode u)

template tryN(n: Positive, body, otherwise: untyped): untyped =
  try:
    for i in 1..n:
      try:
        body
        break
      except:
        if i == n:
          raise
  except:
    otherwise

proc main =
  var
    skip = -1
    hc = newHttpClient()

  macro `>>`(action): untyped =
    action.insert 1, ident"api"
    quote:
      hc.req `action`

  while true:
    let
      notifs = !!<db.getActiveNotifs()
      ids = notifs.mapIt(it.row_id)

    for n in notifs:
      if bid =? n.bale_chat_id:
        tryN 3:
          discard >>sendMessage(int bid, "You've logged In as: \n" & n.nickname)
        do:
          echo "WTF"

    !!db.markNotifsAsStale(ids)

    try:
      let updates = >>getUpdates(offset = skip+1)

      for u in \updates:
        skip = u.id
        if msg =? u.msg and text =? msg.text:
          let chid = msg.chat.id

          case text
          of loginD:
            let lcode = genLoginCode msg.frm
            discard >>sendMessage(chid, lcode)
            discard >>sendMessage(chid, "enter this code in the site login page")

          of startD:
            discard >>sendMessage(chid,
                "Hey Choose from keyboard",
                reply_markup = botKeyBoard)

          else:
            discard >>sendMessage(chid,
                "invalid message: ",
                reply_markup = botKeyBoard)

    except:
      echo "error: " & getCurrentExceptionMsg()


when isMainModule:
  main()
