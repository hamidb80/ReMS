import std/[macros, os]

when not defined js:
  proc getProjectHome*: string = 
    result = getProjectPath()

    while not dirExists result / "src":
      result = result / ".."

  const projectHome* = getProjectHome()