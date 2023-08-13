import std/[macros, os]


proc getProjectHome*: string = 
  result = getProjectPath()

  while not dirExists result / "src":
    result = result / ".."

const projectHome* = getProjectHome()