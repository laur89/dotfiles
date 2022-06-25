var os = require('os')

module.exports = Franz =>
  class Gmail extends Franz {
    // this method added by me, from https://github.com/getferdi/ferdi/issues/321#issuecomment-668207379
	// reason for overriding was being able to left-click links in gmail to open urls via browser
    overrideUserAgent() {
      if (os.platform() == 'linux')
        //return "Mozilla/5.0 (X11; Linux x86_64; rv:72.0) Gecko/20100101 Firefox/72.0"
		return "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/80.0.3987.163 Chrome/80.0.3987.163 Safari/537.36";
      else
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.89 Safari/537.36"
        // return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:72.0) Gecko/20100101 Firefox/72.0";
    },
	modifyRequestHeaders() {
      return [
        {
          headers: {
            //'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36',
            'user-agent': window.navigator.userAgent.replace(/(Ferdi|Electron)\/\S+ \([^)]+\)/g,"").trim(),
          },
          requestFilters: {
            urls: ['*://*/*'],
          }
        }
      ]
    }
  };
