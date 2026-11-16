import { Controller } from "@hotwired/stimulus"

// Hand the protocol to the desktop from the current browsing context.
export default class extends Controller {
  open(event) {
    event.preventDefault()
    let url
    try {
      url = new URL(event.params.url)
    } catch {
      return
    }
    if (url.protocol !== "vidb-encoder:" ||
        !["desktop", "prepare"].includes(url.hostname) ||
        url.username || url.password || url.port) return

    this.element.ownerDocument.defaultView.location.assign(url.href)
  }
}
