import std/strutils

func wrap*(s: string, c: char): string =
    if s.len == 0: $c
    else: c & s & c

func strip*(s: string, c: char): string =
    s.strip(chars = {c})
