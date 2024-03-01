function color(hc) {
    return hc >> 4
}

function geoCenter(geo) {
    return {
        x: geo.x + geo.w / 2,
        y: geo.y + geo.h / 2
    }
}

function initCanvas(board) {
    let body = document.body
    let mousedown = false

    let currScale = 1
    let maxScale = 10
    let minScale = 0.1
    let offX = 0
    let offY = 0

    // You can use either PIXI.WebGLRenderer or PIXI.CanvasRenderer
    let app = new PIXI.Application({
        width: window.innerWidth,
        height: window.innerHeight,
        backgroundAlpha: 0,
        antialias: true,
        view: document.getElementById("boxes")
    })

    const container = new PIXI.Container()
    app.stage.addChild(container)

    let nodeCtx = new PIXI.Graphics()
    let edgeCtx = new PIXI.Graphics()
    container.addChild(edgeCtx)
    container.addChild(nodeCtx)

    const padxf = 0.3
    const padyf = 0.2
    let geo = {}

    for (const id in board.data.objects) {
        const obj = board.data.objects[id]
        const s = obj.font.size

        const style = new PIXI.TextStyle({
            fontFamily: obj.font.family,
            fontSize: s,
            fill: color(obj.theme.fg),
        })
        const textMetrics = PIXI.TextMetrics.measureText(obj.data.text, style)

        const padx = padxf * s
        const pady = padyf * s
        const w = textMetrics.width + padx * 2
        const h = textMetrics.height + pady * 2
        const x = obj.position.x
        const y = obj.position.y

        geo[id] = { x, y, w, h }

        let t = new PIXI.Text(obj.data.text, style)
        t.position.x = obj.position.x + padx
        t.position.y = obj.position.y + pady

        nodeCtx.beginFill(color(obj.theme.bg))
        nodeCtx.lineStyle(s / 10, color(obj.theme.st))
        nodeCtx.drawRoundedRect(x, y, w, h, s * 0.35)

        container.addChild(t)
    }

    for (const edge of board.data.edges) {
        const p1 = edge.points[0]
        const p2 = edge.points[1]
        const c1 = geoCenter(geo[p1])
        const c2 = geoCenter(geo[p2])

        edgeCtx.beginFill()
        edgeCtx.lineStyle(edge.config.width / 10, color(edge.config.theme.st))
        edgeCtx.moveTo(c1.x, c1.y)
        edgeCtx.lineTo(c2.x, c2.y)
    }

    //Animate via WebAPI
    requestAnimationFrame(animate)

    //Scale container
    container.scale.set(1, 1)

    function animate() {
        app.render()
        // XXX: Recursive animation request, disabled for performance.
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
            offX = container.position.x + xPos
            offY = container.position.y + yPos

            // Move the main layer based on above calucalations
            container.position.set(offX, offY)

            // Animate the container
            requestAnimationFrame(animate)
        }
    })

    //Attach cross browser mouse wheel listeners
    body.addEventListener('mousewheel', zoom, false)     // Chrome/Safari/Opera
    body.addEventListener('DOMMouseScroll', zoom, false) // Firefox

    function wheelDirection(evt) {
        if (!evt) evt = event
        return (evt.detail < 0) ? 1 : (evt.wheelDelta > 0) ? 1 : -1
    }

    function zoom(evt) {

        // Find the direction that was scrolled
        let direction = wheelDirection(evt)

        // Set the old scale to be referenced later
        let old_scale = currScale

        // Find the position of the clients mouse
        x = evt.clientX
        y = evt.clientY

        // Manipulate the scale based on direction
        currScale = old_scale + direction * 0.1

        //Check to see that the scale is not outside of the specified bounds
        if (currScale > maxScale) currScale = maxScale
        else if (currScale < minScale) currScale = minScale

        // This is the magic. I didn't write this, but it is what allows the zoom to work.
        offX = (offX - x) * (currScale / old_scale) + x
        offY = (offY - y) * (currScale / old_scale) + y

        //Set the position and scale of the DisplayObjectContainer
        container.scale.set(currScale, currScale)
        container.position.set(offX, offY)

        //Animate the container
        requestAnimationFrame(animate)
    }
}

function fetchBoard() {
    fetch("/board.json")
        .then(r => r.json())
        .then(initCanvas)
}

fetchBoard()
