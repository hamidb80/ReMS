## https://andrejgajdos.com/how-to-create-a-link-preview/

import std/[xmltree, strutils]

import ../../common/conventions


type
    LinkPreviewData* = object
        title*: string
        desc*: string
        image*: string
        timestamp*: string # TODO
        # cardType twitter:card


func linkPreviewData*(xn: XmlNode): LinkPreviewData =
    for el in xn:
        if el.kind == xnElement:
            case el.tag
            of "title":
                result.title = el.attr"content"
            of "meta":
                case el.attr"name" or el.attr"property"
                of "og:title", "twitter:title": discard
                of "og:image", "twitter:image": discard
                of "twitter:image:alt": discard
                of "description", "og:description",
                        "twitter:description": discard
                of "article:published_time": discard
                of "twitter:card": discard
                of "og:url": discard
                else: discard

            else:
                discard

func cropHead*(htmlPage: string): string =
    let
        head = htmlPage.find "<head>"
        tail = htmlPage.findlen "</head>"
    htmlPage[head ..< tail]
