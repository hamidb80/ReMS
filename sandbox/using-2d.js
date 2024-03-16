function color(hc) {
    return "#" + (hc >> 4).toString(16).padStart(6, '0')
}

function v(x, y) {
    return { x, y }
}

function geoCenter(geo) {
    return v(
        geo.x + geo.w / 2,
        geo.y + geo.h / 2
    )
}

function cpos(touch) {
    return v(touch.clientX, touch.clientY)
}

function lenOf(p1, p2) {
    return Math.hypot(p1.x - p2.x, p1.y - p2.y)
}

function distance(ts) {
    let p1 = cpos(ts[0])
    let p2 = cpos(ts[1])
    return lenOf(p1, p2)
}

// ------------------------------------------------

function drawLine(ctx, x1, y1, x2, y2, width, color) {
    ctx.strokeStyle = color
    // ctx.lineWidth = width
    ctx.moveTo(x1, y1)
    ctx.lineTo(x2, y2)
    ctx.stroke()
}

function drawRect(ctx, x, y, width, height, color) {
    ctx.fillStyle = color
    ctx.fillRect(x, y, width, height)
}

function drawText(ctx, text, x, y, size, font, color) {
    ctx.fillStyle = color
    ctx.font = `${size}px ${font}`
    ctx.fillText(text, x, y)
}

function initCanvas(board) {
    let canvas = document.getElementById("boxes")
    let ctx = canvas.getContext('2d')

    let cameraOffset = { x: window.innerWidth / 2, y: window.innerHeight / 2 }
    let cameraZoom = 1
    let MAX_ZOOM = 5
    let MIN_ZOOM = 0.1
    let SCROLL_SENSITIVITY = 0.0005

    let isDragging = false
    let dragStart = { x: 0, y: 0 }
    let initialPinchDistance = null
    let lastZoom = cameraZoom

    function draw() {
        canvas.width = window.innerWidth
        canvas.height = window.innerHeight

        // Translate to the canvas centre before zooming - so you'll always zoom on what you're looking directly at
        ctx.translate(window.innerWidth / 2, window.innerHeight / 2)
        ctx.scale(cameraZoom, cameraZoom)
        ctx.translate(-window.innerWidth / 2 + cameraOffset.x, -window.innerHeight / 2 + cameraOffset.y)
        ctx.clearRect(0, 0, window.innerWidth, window.innerHeight)

        function inside() {
            const padxf = 0.3
            const padyf = 0.2
            let geo = {}

            for (const id in board.data.objects) {
                const obj = board.data.objects[id]
                const s = obj.font.size
                const t = obj.data.text
                const f = obj.font.family
                const fg = color(obj.theme.fg)
                const bg = color(obj.theme.bg)

                const style = new PIXI.TextStyle({
                    fontFamily: f,
                    fontSize: s,
                    padding: 8
                })
                const textMetrics = PIXI.TextMetrics.measureText(t, style)
                
                const padx = padxf * s
                const pady = padyf * s
                const w = textMetrics.width + padx * 2
                const h = textMetrics.height + pady * 2
                const x = obj.position.x
                const y = obj.position.y

                geo[id] = { x, y, padx, pady, w, h, fg, bg, t, s, f }
            }

            for (const edge of board.data.edges) {
                const n1 = edge.points[0]
                const n2 = edge.points[1]
                const c1 = geoCenter(geo[n1])
                const c2 = geoCenter(geo[n2])
                const st = color(edge.config.theme.st)
                console.log(st)
                drawLine(ctx, c1.x, c1.y, c2.x, c2.y, edge.config.width / 10, st)
            }

            for (const id in geo) {
                const { x, y, padx, pady, w, h, fg, bg, t, s, f } = geo[id]
                drawRect(ctx, x, y, w, h, bg)
                drawText(ctx, t, x + padx, y + pady + h / 2, s, f, fg)
                // nodeCtx.lineStyle(s / 10, color(obj.theme.st))
            }
        }

        function test() {
            drawRect(ctx, -50, -50, 100, 100, "#991111")
            drawRect(ctx, -35, -35, 20, 20, "#eecc77")
            drawRect(ctx, 15, -35, 20, 20, "#eecc77")
            drawRect(ctx, -35, 15, 70, 20, "#eecc77")
            drawText(ctx, "Simple Pan and Zoom Canvas", -255, -100, 32, "courier", "#fff")

            ctx.rotate(-31 * Math.PI / 180)
            drawText(ctx, "Now with touch!", -110, 100, 32, "courier", `#${(Math.round(Date.now() / 40) % 4096).toString(16)}`)

            ctx.rotate(31 * Math.PI / 180)
            drawText(ctx, "Wow, you found me!", -260, -2000, 48, "courier", "#fff")
        }

        inside()
        requestAnimationFrame(draw)
    }

    // Gets the relevant location from a mouse or single touch event
    function getEventLocation(e) {
        if (e.touches && e.touches.length == 1) {
            return { x: e.touches[0].clientX, y: e.touches[0].clientY }
        }
        else if (e.clientX && e.clientY) {
            return { x: e.clientX, y: e.clientY }
        }
    }

    function onPointerDown(e) {
        isDragging = true
        dragStart.x = getEventLocation(e).x / cameraZoom - cameraOffset.x
        dragStart.y = getEventLocation(e).y / cameraZoom - cameraOffset.y
    }

    function onPointerUp(e) {
        isDragging = false
        initialPinchDistance = null
        lastZoom = cameraZoom
    }

    function onPointerMove(e) {
        if (isDragging) {
            cameraOffset.x = getEventLocation(e).x / cameraZoom - dragStart.x
            cameraOffset.y = getEventLocation(e).y / cameraZoom - dragStart.y
        }
    }

    function handleTouch(e, singleTouchHandler) {
        if (e.touches.length == 1) {
            singleTouchHandler(e)
        }
        else if (e.type == "touchmove" && e.touches.length == 2) {
            isDragging = false
            handlePinch(e)
        }
    }

    function handlePinch(e) {
        e.preventDefault()

        let touch1 = { x: e.touches[0].clientX, y: e.touches[0].clientY }
        let touch2 = { x: e.touches[1].clientX, y: e.touches[1].clientY }

        // This is distance squared, but no need for an expensive sqrt as it's only used in ratio
        let currentDistance = (touch1.x - touch2.x) ** 2 + (touch1.y - touch2.y) ** 2

        if (initialPinchDistance == null) {
            initialPinchDistance = currentDistance
        }
        else {
            adjustZoom(null, currentDistance / initialPinchDistance)
        }
    }

    function adjustZoom(zoomAmount, zoomFactor) {
        if (!isDragging) {
            if (zoomAmount) {
                cameraZoom += zoomAmount
            }
            else if (zoomFactor) {
                // console.log(zoomFactor)
                cameraZoom = zoomFactor * lastZoom
            }

            cameraZoom = Math.min(cameraZoom, MAX_ZOOM)
            cameraZoom = Math.max(cameraZoom, MIN_ZOOM)

            // console.log(zoomAmount)
        }
    }

    canvas.addEventListener('mousedown', onPointerDown)
    canvas.addEventListener('touchstart', (e) => handleTouch(e, onPointerDown))
    canvas.addEventListener('mouseup', onPointerUp)
    canvas.addEventListener('touchend', (e) => handleTouch(e, onPointerUp))
    canvas.addEventListener('mousemove', onPointerMove)
    canvas.addEventListener('touchmove', (e) => handleTouch(e, onPointerMove))
    canvas.addEventListener('wheel', (e) => adjustZoom(e.deltaY * SCROLL_SENSITIVITY))

    // Ready, set, go
    draw()
}

// ---------------------------------------------------------------------

function fetchBoard() {
    fetch("/board.json")
        .then(r => r.json())
        .then(initCanvas)
}

new FontFaceObserver("Vazirmatn")
    .load("سلام", 5000)
    .then(() => {
        new FontFaceObserver("Mooli")
            .load("wow", 5000)
            .then(fetchBoard)
    })

