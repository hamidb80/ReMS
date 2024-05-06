import std/[options, json, sequtils, httpclient, deques, os]

import questionable
import bale, bale/helper/stdhttpclient

import ../database/[dbconn, models, queries]
import ../auth
import ../utils/[random]
import ../../common/[types]


type
  Msg = object
    chid: Id
    content: string


const
  loginD = "/login"
  startD = "/start"
  mychatidtD = "/my_chat_id"

let
  botKeyBoard = some ReplyKeyboardMarkup(
    keyboard: some @[@[
    KeyboardButton(text: loginD),
    KeyboardButton(text: mychatidtD)]])

var
  httpc = newHttpClient()
  # msgQueue = initDeque[Msg](100)


proc registerLoginCode(code: string, u: bale.User) =
  !!db.addInviteCode(messangerT, code, JsonNode u)

template sendMsg(chatId, msg): untyped {.dirty.} =
  discard req(httpc, 
    sendMessage(api, int chatid, msg, reply_markup = botKeyBoard))

# template qTextMsg(i, c): untyped =
#   addLast msgQueue, Msg(chid: i, content: c)

# proc notifCheck =
#   let
#     notifs = !!<db.getActiveNotifs()
#     ids = notifs.mapIt(it.row_id)

#   for n in notifs:
#     if bid =? n.bale_chat_id:
#       qTextMsg bid, "You've logged In as: \n" & n.nickname

#   !!db.markNotifsAsStale(ids)

# proc genSendMessages(api: string): proc() =
#   proc =
#     while 0 < msgQueue.len:
#       let m = popFirst msgQueue
#       try:
#         discard httpc.req api.sendMessage(int m.chid, m.content,
#             reply_markup = botKeyBoard)
#       except:
#         addLast msgQueue, m

proc genCheckUpdates(api: string): proc() =
  var skip = 0

  proc =
    try:
      let updates = httpc.req api.getUpdates(offset = skip)
      if ok updates:
        for u in \updates:
          skip = max(skip, u.id+1)

          if msg =? u.msg and text =? msg.text:
            let chid = msg.chat.id

            case text
            of startD:
              sendMsg chid, "Welcome! choose from keyboard"

            of loginD:
              let code = randCode 4..6
              registerLoginCode code, msg.frm
              sendMsg chid, code
              sendMsg chid, "Enter this code in the login page"

            of mychatidtD:
              sendMsg chid, "your chat id in Bale is: " & $chid

            else:
              sendMsg chid, "invalid message, choose from keyboard"

    except:
      echo "[Bale Bot error]: " & getCurrentExceptionMsg()


proc runBaleBot*(token: string) {.raises: [], noreturn.} =
  {.cast(gcsafe).}:

    let
      api = baleBotBaseApi token
      # msgSender = genSendMessages api
      updateChecker = genCheckUpdates api

    while true:
      try:
        # msgSender()
        updateChecker()
        # notifCheck()
      except:
        discard

when isMainModule:
  runBaleBot readfile "./bot.token"
