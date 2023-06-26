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
