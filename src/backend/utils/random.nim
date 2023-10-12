import std/random

randomize()

proc randCode(size: Positive): string =
  for _ in 1..size:
    add result, rand '0'..'9'

proc randCode*(sizeRange: Slice[int]): string =
  randCode rand sizeRange
