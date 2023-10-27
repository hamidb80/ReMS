## "linear markdown" is a subset of markdown that only supports these features:
##      normal text, italic, bold, under line, strike through, latex, code

import std/jsffi


type
    LinearMarkdownMode* = enum
        lmmItalic
        lmmBold
        lmmUnderline
        lmmStrikeThrough
        lmmLatex
        lmmCode

    LinearMarkdownNode* = object
        slices: Slice[int]
        modes*: set[LinearMarkdownMode]

func parseLinearMarkdown(s: string): seq[LinearMarkdownNode] =
    var
        escaped = false
        stack: seq[LinearMarkdownMode]

    template checkStack(mode, matched, failed): untyped =
        if stack.len != 0 and stack[^1] == mode:
            discard pop stack
        else:
            add stack, mode
            failed

    for c in s:
        case c
        of '\\': # escape
            # if notin latex or code
            if escaped:
                escaped = false
                # add the char
            else:
                escaped = true

        of '*': # bold
            checkStack lmmBold:
                discard
            do:
                discard

        of '_': # italic
            checkStack lmmItalic:
                discard
            do:
                discard

        of '#': # underline
            checkStack lmmUnderline:
                discard
            do:
                discard

        of '~': # strike through
            checkStack lmmStrikeThrough:
                discard
            do:
                discard

        of '`': # code
            checkStack lmmCode:
                discard
            do:
                discard

        of '$': # latex
            checkStack lmmLatex:
                discard
            do:
                discard

        else: # not a special char
            discard

# func 