const
  messangerT* = "bale"
  userPassT* = "e-mail"

when not (defined(js) or defined(frontend)):
  import std/[options, json]
  import checksums/sha1

  import mummy
  import questionable
  import ponairi
  import bale
  import jsony

  import ./database/[dbconn, models, queries]
  import ./utils/[web, sqlgen, auth]
  import ../common/[types]
  import ./[config]

  # ----- others ---------------------------------------

  # proc loginNotif*(db: DbConn, usr: Id) =
  #   db.insert Relation(
  #     user: some usr,
  #     kind: some ord nkLoginBale,
  #     timestamp: unow())

  func len[E: enum](e: type E): Natural =
    len e.low .. e.high

  # ----- db queries -----------------------------------

  proc addInviteCode*(db: DbConn, loginPlatform, code: string, info: JsonNode) =
    db.insert Auth(
        kind: loginPlatform,
        secret: code,
        info: $info,
        created_at: unow())

  proc addAuth*(db: DbConn, userId: Id, pass: SecureHash): Id =
    db.insert Auth(
      user: some userId,
      secret: $pass)

  proc getInvitation*(db: DbConn,
    secret, kind: string,
    time: Unixtime, expiresAfterSec: Positive
  ): options.Option[Auth] =

    db.find R, fsql"""
      SELECT *
      FROM Auth a
      WHERE
        secret = {secret} AND
        kind = {kind} AND
        {time} - a.created_at <= {expiresAfterSec}
      """

  proc getBaleAuth*(db: DbConn, baleUserId: int): options.Option[Auth] =
    db.find R, fsql"""
      SELECT *
      FROM Auth a
      WHERE 
        int_index = {baleUserId} AND
        kind = {messangerT}
    """

  proc activateBaleAuth*(db: DbConn, a: Auth, baleUserId, userId: int) =
    db.exec fsql"""
      UPDATE Auth
      SET 
        activated = {true},
        int_index = {baleUserId},
        user = {userId}
      WHERE 
        id = {a.id}
    """

  proc addPassAuth*(db: DbConn, uid: Id, password: string) =
    db.insert Auth(
      kind: userPassT,
      user: some uid,
      secret: $ secureHash password)

  # ----- login procs ----------------------------------

  proc loginWithInvitationCode(code: string): UserCache =
    let inv = !!<db.getInvitation(code, messangerT, unow(), 60)

    if i =? inv:
      let
        baleUser = bale.User parseJson i.info
        maybeAuth = !!<db.getBaleAuth(baleUser.id)
        uid =
          if a =? maybeAuth: get a.user
          else:
            let u = !!<db.newUser(
              messangerT & "_" & $baleUser.id,
              baleUser.firstName & baleUser.lastname.get "",
              baleUser.id in adminBaleIds,
              umReal)

            !!db.activateBaleAuth(i, baleUser.id, u)
            u

        maybeUsr = !!<db.getUser(uid)

      UserCache(account: get maybeUsr)

    else:
      raise newException(ValueError, "invalid code")

  proc loginWithUserPass(lf: LoginForm): UserCache =
    ## sign up with form is not possible, only from bale and enabeling password later
    let
      u = get !!<db.getUser(lf.username)
      a = get !!<db.getUserAuth(userPassT, u.id)

    if $(secureHash lf.password) == a.secret:
      UserCache(account: u)
    else:
      # TODO add syntax sugar for errors
      raise newException(ValueError, "password is not valid")

  # ---------------------------

  proc loginDispatcher*(req: Request) {.qparams: {kind: string}.} =
    let b = req.body
    doLogin req, case kind
      of messangerT: loginWithInvitationCode b
      of userPassT: loginWithUserPass fromJson(b, LoginForm)
      else:
        raise newException(ValueError, "invalid login method: " & kind)
