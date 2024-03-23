## https://andrejgajdos.com/how-to-create-a-link-preview/

import std/[xmltree, strutils, uri]

import ../database/models
import ../../common/conventions


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

                of "description", "og:description",
                        "twitter:description":
                    result.desc = val

                of "twitter:image:alt": discard
                of "article:published_time": discard
                of "twitter:card": discard
                of "og:url": discard
                else: discard
            
            else: discard

func cropHead*(htmlPage: string): string =
    let
        head = htmlPage.find "<head>"
        tail = htmlPage.findlen "</head>"
    htmlPage[head ..< tail]
