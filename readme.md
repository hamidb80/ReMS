# ReMS
Remembering management system!


## Stack
- konva
- hotkeys
- bootstrap
- font-awesome v6
- nim
- karax
- jester
- poinari

## 

## TODO

- [ ] `.PDF` spec
- [ ] Nodes with text in it
- [ ] config visual properties of nodes
- [ ] another layer for connections
- [ ] background
- [ ] nesting

## Know
- what good is learning if I don't remember it?
- active learning vs passing learning / scout young
- spatial web browsing
- [orgpad](https://orgpad.com/) -- [tech stack](https://orgpad.com/o/Cx0toaAblKpKUSZasDxsxK?token=DtN36_XBJGqKhdJk2pwl1Z)
- PDF annonator
- note taking
- https://excalidraw.com/

## Helpful contents

### convert pdf to image
user [`imagemagic`](https://linuxhint.com/imagemagick-convert-pdf-png/)

[help 1](https://stackoverflow.com/questions/32466112/imagemagick-convert-pdf-to-jpeg-failedtoexecutecommand-gswin32c-exe-pdfdel)

[help 2](https://imagemagick.org/Usage/windows/#conversion)

### store meta data
https://konvajs.org/api/Konva.Node.html#setAttr

### Icon Search
https://fontawesome.com/icons/

### Theme
https://bootswatch.com/

### Pinch Zoom
https://gist.github.com/Martin-Pitt/2756cf86dca90e179b4e75003d7a1a2b

### Touch
https://konvajs.org/docs/sandbox/Multi-touch_Scale_Stage.html

### File Uploader UI
https://design.gs.com/components/input/file-upload

### File upload with progress using Axios
https://stackoverflow.com/questions/41088022/how-to-get-onuploadprogress-in-axios
 
### Paste
- https://www.techiedelight.com/paste-image-from-clipboard-using-javascript/
- https://github.com/AlejandroAkbal/Paste-Image-to-Download

```js
function applyPasteEvent(el) {
  el.onpaste = (pasteEvent) => {
    var file = pasteEvent.clipboardData.files[0]

    if (file.type.startsWith("image")) {
      var reader = new FileReader()

      reader.onload = e => {
        fetch("/save-clipboard",
          {
            method: "POST",
            headers: { "Content-Type": "text/plain" },
            body: e.target.result,
          }
        ).then(res => {
          res.text().then(t => { el.value = t })
        })
      }

      reader.readAsDataURL(file)
    }
  }
}
```