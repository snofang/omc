export default DownloadFile = {
  mounted() {
    this.handleEvent("download-file", (event) => {
      var element = document.createElement('a');
      element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(event.text));
      element.setAttribute('download', event.filename);
      element.style.display = 'none';
      document.body.appendChild(element);
      element.click();
      document.body.removeChild(element);
    });
  }};
