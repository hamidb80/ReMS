## "linear markdown" is a subset of markdown that only supports these features:
##      normal text, italic, bold, under line, strike through, 
##      latex, code, spoiler, highlight

# import std/jsffi


type
    LinearMarkdownMode* = enum
        lmmItalic
        lmmBold
        lmmUnderline
        lmmStrikeThrough
        lmmLatex
        lmmCode
        # lmmSpoiler
        lmmHighlight

    LinearMarkdownNode* = object
        slice*: Slice[int]
        substr*: string
        modes*: set[LinearMarkdownMode]

func parseLinearMarkdown*(s: string): seq[LinearMarkdownNode] =
    var
        # escaped = false
        head = 0
        stack: seq[LinearMarkdownMode]
        modes: set[LinearMarkdownMode]


    template genobj(slc): untyped =
        LinearMarkdownNode(
            slice: slc,
            substr: s[slc],
            modes: modes)

    template checkStack(i, mode): untyped =
        let slice = head..<i

        if stack.len != 0 and stack[^1] == mode:
            if 0 != slice.len:
                add result, genobj slice

            head = i + 1
            discard pop stack
            excl modes, mode

        else:
            if 0 != slice.len:
                add result, genobj slice

            head = i + 1
            add stack, mode
            incl modes, mode

    template notCodeOrLatex(body): untyped =
        if lmmCode notin modes and lmmLatex notin modes:
            body


    for i, c in s:
        case c
        # TODO
        # of '\\': # escape
        of '*':
            notCodeOrLatex:
                checkStack i, lmmBold

        of '_':
            notCodeOrLatex:
                checkStack i, lmmItalic

        of '#':
            notCodeOrLatex:
                checkStack i, lmmUnderline

        of '~':
            notCodeOrLatex:
                checkStack i, lmmStrikeThrough

        of '`':
            checkStack i, lmmCode

        of '$':
            checkStack i, lmmLatex

        # of '|':
        #     notCodeOrLatex:
        #         checkStack i, lmmSpoiler

        of '=':
            notCodeOrLatex:
                checkStack i, lmmHighlight

        else: # not a special char
            discard

    if head <= high s:
        add result, genobj head .. high s

when isMainModule:
    let
        t = """
            Hey *man* how are _you_?
            _L_*e*tter by $l$=e=tter
            *~WTF~ yes* and 
            `my_cdoe` 
            $LATEX \sin$
            = roses are red = 
            | violets are blue |
            I want Palestine be free
            God make it so
        """
        d = parseLinearMarkdown t

    echo t
    for p in d:
        echo p
