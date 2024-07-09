import std/[xmltree, strutils]

import ../database/models
import ../../common/conventions


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


## https://andrejgajdos.com/how-to-create-a-link-preview/
func linkPreviewData*(xn: XmlNode): LinkPreviewData =
    for el in xn:
        if el.kind == xnElement:
            let val = el.attr"content"

            case el.tag
            of "title":
                result.title = el.innerText

            of "meta":
                case el.attr"name" or el.attr"property"
                of "og:title", "twitter:title":
                    result.title = val

                of "og:image", "twitter:image":
                    result.image = val

                of "description", "og:description", "twitter:description":
                    result.desc = val

                of "twitter:image:alt": discard
                of "article:published_time": discard
                of "twitter:card": discard
                of "og:url": discard
                else: discard
            
            else: discard

func cropHead*(htmlPage: string): string =
    let
        head = htmlPage.find "<head"
        tail = htmlPage.findlen "</head>"
    htmlPage[head ..< tail]
