// https://stackoverflow.com/questions/62262777/how-to-download-text-file-in-readable-format-using-blob-in-javascript-unable-to
function download(data, type = 'text/plain') {
  const element = document.createElement('a')
  const file = new Blob([data], { type })
  element.href = URL.createObjectURL(file)
  element.download = 'errorDetails.txt'
  element.click()
}

function downloadUrl(name, dataurl) {
  const link = document.createElement("a")
  link.href = dataurl
  link.download = name
  link.click()
}

function imageDataUrl(file) {
  return new Promise((resolve, reject) => {
    var reader = new FileReader()
    reader.onload = e => resolve(e.target.result)
    reader.onerror = reject
    reader.onabort = reject
    reader.readAsDataURL(file)
  })
}

document.onpaste = (pasteEvent) => {
  var file = pasteEvent.clipboardData.files[0]

  if (file && file.type.startsWith("image")) {
    imageDataUrl(file).then(onPasteOnScreen)
  }
  else {
    console.log("WTF")
  }
}
