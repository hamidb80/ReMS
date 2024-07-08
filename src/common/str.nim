import std/strutils


func isAscii*(c: char): bool = 
  c.ord in 0 .. 127

func wrap*(s: string, c: char): string =
    if s.len == 0: $c
    else: c & s & c

func strip*(s: string, c: char): string =
    s.strip(chars = {c})

func replaceChar*(s: string, a, b: char): string = 
  for c in s:
    result.add:
      if c == a: b
      else:      c

template toStr*(smth): untyped = 
  $smth
