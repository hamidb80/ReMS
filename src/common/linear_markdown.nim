## "linear markdown" is a subset of markdown that only supports these features:
##      normal text, italic, bold, under line, strike through, latex, code

# import std/jsffi


type
    LinearMarkdownMode* = enum
        lmmItalic
        lmmBold
        lmmUnderline
        lmmStrikeThrough
        lmmLatex
        lmmCode

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
        # of '\\': # escape
        of '*': # bold
            notCodeOrLatex:
                checkStack i, lmmBold

        of '_': # italic
            notCodeOrLatex:
                checkStack i, lmmItalic

        of '#': # underline
            notCodeOrLatex:
                checkStack i, lmmUnderline

        of '~': # strike through
            notCodeOrLatex:
                checkStack i, lmmStrikeThrough

        of '`': # code
            checkStack i, lmmCode

        of '$': # latex
            checkStack i, lmmLatex

        else: # not a special char
            discard

    if head <= high s:
        add result, genobj head .. high s

when isMainModule:
    let 
        t = """
            Hey *man* how are _you_?
            *~WTF~ yes* and 
            `my_cdoe` 
            $LATEX \sin$ 
            the end...
        """
        d = parseLinearMarkdown t
    
    echo t
    for p in d:
        echo p
