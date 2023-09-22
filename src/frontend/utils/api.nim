import std/[asyncjs]

import ../../backend/routes
import ../../backend/database/[models]
import ../../common/[types, datastructures]
import ../jslib/axios
import ./js


proc getPallete*(
  name: string, 
  success: proc(cts: seq[ColorTheme]),
  fail: proc() = noop,
) =
    proc done(r: AxiosResponse) =
      success cast[seq[ColorTheme]](r.data)

    getApi(get_palette_url name)
    .then(done)
    .dcatch(fail)


