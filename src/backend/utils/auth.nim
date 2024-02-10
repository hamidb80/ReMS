import std/[json, options, times]

import cookiejar
import quickjwt
import mummy
import jsony
import webby

import ../database/[models]
import ../config

include ../database/jsony_fix


## https://community.auth0.com/t/rs256-vs-hs256-jwt-signing-algorithms/58609
const jwtKey* = "auth"

proc appendJwtExpire(ucj: sink JsonNode, expire: int64): JsonNode =
  ucj["exp"] = %expire
  ucj

const expireDays = 10

proc toJwt(uc: UserCache): string =
  sign(
    header = %*{
      "typ": "JWT",
      "alg": "HS256"},
    claim = appendJwtExpire(parseJson toJson uc, toUnix getTime() +
        expireDays.days),
    secret = jwtSecret)

proc jwtCookieSet(token: string): HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, token, now() + expireDays.days, path = "/")

proc jwt*(req: Request): Option[string] =
  try:
    if "Cookie" in req.headers:
      let ck = initCookie req.headers["Cookie"]
      if ck.name == jwtKey:
        return some ck.value
  except:
    discard

proc logoutCookieSet*: HttpHeaders =
  result["Set-Cookie"] = $initCookie(jwtKey, "", path = "/")

proc doLogin*(req: Request, uc: UserCache) =
  if uc.account.mode != umTest or defined loginTestUser:
    {.cast(gcsafe).}:
      respond req, 200, jwtCookieSet toJwt uc
  else:
    raise newException(ValueError, "User is only available at test")
