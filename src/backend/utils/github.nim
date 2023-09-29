import std/[strutils]

import ../database/models


func htmlUnescape*(str: string): string =
  str.multiReplace ("\\\"", "\""), ("\\n", "\n"), ("\\/", "/")

func parseGithubJsFile*(content: string): GithubCodeEmbed =
  ## as of 2023/10/22 the Github embed `script.js` is in pattern of:
  ##
  ## LINE_NUMBER| TEXT
  ## 1| document.write('<link rel="stylesheet" href="<CSS_FILE_URL">')
  ## 2| document.write('escaped string of HTML content')
  ## 3|

  const
    linkStamps = "href=\"" .. "\">')"
    codeStamps = "document.write('" .. "')"

  let
    parts = splitlines content
    cssLinkStart = parts[0].find linkStamps.a
    cssLinkEnd = parts[0].rfind linkStamps.b
    htmlCodeEnd = parts[1].rfind codeStamps.b

  result.styleLink = parts[0][(cssLinkStart + linkStamps.a.len) ..< cssLinkEnd]
  result.htmlCode = htmlUnescape parts[1][codeStamps.a.len ..< htmlCodeEnd]
