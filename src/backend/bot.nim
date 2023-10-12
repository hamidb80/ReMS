import std/[options, json, sequtils, httpclient, deques]

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

proc genSendMessages(api: string): proc() =
  proc =
    while 0 < msgQueue.len:
      let m = popFirst msgQueue
      try:
        discard httpc.req api.sendMessage(int m.chid, m.content,
            reply_markup = botKeyBoard)
      except:
        addLast msgQueue, m

proc genCheckUpdates(api: string): proc() =
  var skip = 0

  proc =
    try:
      let updates = httpc.req api.getUpdates(offset = skip)

      for u in \updates:
        skip = max(skip, u.id+1)

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


proc runBaleBot*(token: string) {.raises: [], noreturn.} =
  {.cast(gcsafe).}:

    let
      api = baleBotBaseApi token
      msgSender = genSendMessages api
      updateChecker = genCheckUpdates api

    while true:
      try:
        msgSender()
        updateChecker()
        dbCheck()
      except:
        discard

when isMainModule:
  runBaleBot readfile "./bot.token"
