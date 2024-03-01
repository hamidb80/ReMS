
function randInt(min, max) { // min and max included 
    return Math.floor(Math.random() * (max - min + 1) + min)
}

function initCanvas(board) {
    // You can use either PIXI.WebGLRenderer or PIXI.CanvasRenderer
    let app = new PIXI.Application({
        width: window.innerWidth,
        height: window.innerHeight,
        backgroundAlpha: 0,
        // view: document.getElementById("boxes")
    })

    document.getElementById("ROOT").append(app.view)

    const container = new PIXI.Container()
    app.stage.addChild(container)

    //declare all letiables
    let body = document.body
    let main_layer_zoom_scale = 1
    let main_layer_zoom_scalemax = 10
    let main_layer_zoom_scalemin = 1
    let main_layer_zoom_offset_x = 0
    let main_layer_zoom_offset_y = 0


    // let stage = new PIXI.Stage()
    // let mainLayer = new PIXI.DisplayObjectContainer()
    // let graphicLayer = new PIXI.DisplayObjectContainer()

    let mousedown = false

    //Setup the stage properties
    // stage.setBackgroundColor(0xcccccc)
    // container.setBackgroundColor(0xcccccc)

    let ctx = new PIXI.Graphics()

    for (let I = 0; I < 10000; I++) {
        let x = randInt(0, 1000)
        let y = randInt(0, 1000)

        ctx.beginFill(0x000000)
        ctx.lineStyle(2, 0xFF0000)
        ctx.drawRect(x, y, 10, 10)
        console.log(I)
    }

    let mainLayer = container
    mainLayer.addChild(ctx)


    //Build object hierarchy
    // graphicLayer.addChild(ctx)
    // mainLayer.addChild(graphicLayer)
    // stage.addChild(mainLayer)

    //Animate via WebAPI
    requestAnimationFrame(animate)

    //Scale mainLayer
    mainLayer.scale.set(1, 1)

    function animate() {
        app.render()
        // Recursive animation request, disabled for performance.
        // requestAnimationFrame(animate)
    }

    window.addEventListener('mousedown', function (e) {
        //Reset clientX and clientY to be used for relative location base panning
        clientX = -1
        clientY = -1
        mousedown = true
    })

    window.addEventListener('mouseup', function (e) {
        mousedown = false
    })

    window.addEventListener('mousemove', function (e) {
        // Check if the mouse button is down to activate panning
        if (mousedown) {

            // If this is the first iteration through then set clientX and clientY to match the inital mouse position
            if (clientX == -1 && clientY == -1) {
                clientX = e.clientX
                clientY = e.clientY
            }

            // Run a relative check of the last two mouse positions to detect which direction to pan on x
            if (e.clientX == clientX) {
                xPos = 0
            } else if (e.clientX < clientX) {
                xPos = -Math.abs(e.clientX - clientX)
            } else if (e.clientX > clientX) {
                xPos = Math.abs(e.clientX - clientX)
            }

            // Run a relative check of the last two mouse positions to detect which direction to pan on y
            if (e.clientY == clientY) {
                yPos = 0
            } else if (e.clientY < clientY) {
                yPos = -Math.abs(e.clientY - clientY)
            } else if (e.clientY > clientY) {
                yPos = Math.abs(clientY - e.clientY)
            }

            // Set the relative positions for comparison in the next frame
            clientX = e.clientX
            clientY = e.clientY

            // Change the main layer zoom offset x and y for use when mouse wheel listeners are fired.
            main_layer_zoom_offset_x = mainLayer.position.x + xPos
            main_layer_zoom_offset_y = mainLayer.position.y + yPos

            // Move the main layer based on above calucalations
            mainLayer.position.set(main_layer_zoom_offset_x, main_layer_zoom_offset_y)

            // Animate the container
            requestAnimationFrame(animate)
        }
    })

    //Attach cross browser mouse wheel listeners
    body.addEventListener('mousewheel', zoom, false)     // Chrome/Safari/Opera
    body.addEventListener('DOMMouseScroll', zoom, false) // Firefox


    /**
     * Detect the amount of distance the wheel has traveled and normalize it based on browsers.
     * @param  event
     * @return integer
     */
    function wheelDistance(evt) {
        if (!evt) evt = event
        let w = evt.wheelDelta, d = evt.detail
        if (d) {
            if (w) return w / d / 40 * d > 0 ? 1 : -1 // Opera
            else return -d / 3              // Firefox         TODO: do not /3 for OS X
        } else return w / 120             // IE/Safari/Chrome TODO: /3 for Chrome OS X
    }

    /**
     * Detect the direction that the scroll wheel moved
     * @param event
     * @return integer
     */
    function wheelDirection(evt) {
        if (!evt) evt = event
        return (evt.detail < 0) ? 1 : (evt.wheelDelta > 0) ? 1 : -1
    }

    /**
     * Zoom into the DisplayObjectContainer that acts as the container
     * @param event
     */
    function zoom(evt) {

        // Find the direction that was scrolled
        let direction = wheelDirection(evt)

        // Find the normalized distance
        let distance = wheelDistance(evt)

        // Set the old scale to be referenced later
        let old_scale = main_layer_zoom_scale

        // Find the position of the clients mouse
        x = evt.clientX
        y = evt.clientY

        // Manipulate the scale based on direction
        main_layer_zoom_scale = old_scale + direction

        //Check to see that the scale is not outside of the specified bounds
        if (main_layer_zoom_scale > main_layer_zoom_scalemax) main_layer_zoom_scale = main_layer_zoom_scalemax
        else if (main_layer_zoom_scale < main_layer_zoom_scalemin) main_layer_zoom_scale = main_layer_zoom_scalemin

        // This is the magic. I didn't write this, but it is what allows the zoom to work.
        main_layer_zoom_offset_x = (main_layer_zoom_offset_x - x) * (main_layer_zoom_scale / old_scale) + x
        main_layer_zoom_offset_y = (main_layer_zoom_offset_y - y) * (main_layer_zoom_scale / old_scale) + y

        //Set the position and scale of the DisplayObjectContainer
        mainLayer.scale.set(main_layer_zoom_scale, main_layer_zoom_scale)
        mainLayer.position.set(main_layer_zoom_offset_x, main_layer_zoom_offset_y)

        //Animate the container
        requestAnimationFrame(animate)
    }
}

function fetchBoard() {
    fetch("/board.json")
    .then(r => r.json())
    .then(initCanvas)
}

console.log("hey")
fetchBoard()