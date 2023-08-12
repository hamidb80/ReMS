import std/jsffi

func latexToHtml*(latex: cstring, inline: bool): cstring
  {.importjs: "katex.renderToString(#, {displayMode: !#})".}
