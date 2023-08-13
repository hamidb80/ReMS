import mummy/routers
import ./views

var router*: Router

router.notFoundHandler = notFoundHandler
router.get("/", indexHandler)
router.get("/dist/", staticFileHandler)