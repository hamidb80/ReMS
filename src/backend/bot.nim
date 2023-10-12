import std/[options, os, json, sequtils, strutils,
    deques, httpclient]

import questionable
import bale, bale/helper/stdhttpclient

import ./database/[dbconn, models, queries]
import ../common/[types]
import ./utils/[random]


type
  Msg = object
    chid: Id
    content: string


const
  loginD = "/login"
  startD = "/start"
  mychatidtD = "/my_chat_id"

let
  token = getEnv "BALE_BOT_TOKEN"
  api = baleBotBaseApi token
  botKeyBoard = some ReplyKeyboardMarkup(
    keyboard: some @[@[
    KeyboardButton(text: loginD),
    KeyboardButton(text: mychatidtD)]])

var
  httpc = newHttpClient()
  msgQueue = initDeque[Msg](100)


proc registerLoginCode(code: string, u: bale.User) =
  !!db.newInviteCode(code, JsonNode u)

template qTextMsg(i, c): untyped =
  addLast msgQueue, Msg(chid: i, content: c)


proc dbCheck =
  let
    notifs = !!<db.getActiveNotifs()
    ids = notifs.mapIt(it.row_id)

  for n in notifs:
    if bid =? n.bale_chat_id:
      qTextMsg bid, "You've logged In as: \n" & n.nickname

  !!db.markNotifsAsStale(ids)

proc sendMessages(n: Positive) =
  for i in 1..n:
    if msgQueue.len != 0:
      let m = popFirst msgQueue
      try:
        discard httpc.req api.sendMessage(int m.chid, m.content,
            reply_markup = botKeyBoard)
      except:
        addLast msgQueue, m

proc checkUpdates(skip: Natural): Natural =
  result = skip
  try:
    let updates = httpc.req api.getUpdates(offset = skip)

    for u in \updates:
      result = u.id + 1
      if msg =? u.msg and text =? msg.text:
        let chid = msg.chat.id

        case text
        of startD:
          qTextMsg chid, "Welcome! choose from keyboard"

        of loginD:
          let code = randCode 4..6
          registerLoginCode code, msg.frm
          qTextMsg chid, code
          qTextMsg chid, "Enter this code in the login page"

        of mychatidtD:
          qTextMsg chid, "your chat id in Bale is: " & $chid

        else:
          qTextMsg chid, "invalid message, choose from keyboard"

  except:
    echo "error: " & getCurrentExceptionMsg()


proc startBaleBot* {.raises: [].} =
  var skip = 0

  while true:
    try:
      sendMessages(20)
      skip = checkUpdates(skip)
      dbCheck()
    except:
      discard

when isMainModule:
  main()
