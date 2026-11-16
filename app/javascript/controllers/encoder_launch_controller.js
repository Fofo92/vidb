import { Controller } from "@hotwired/stimulus"

// Dispatch synchronously from the click, without navigating the page or opening a tab.
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

    this.disconnect()
    this.frame = this.element.ownerDocument.createElement("iframe")
    this.frame.hidden = true
    this.frame.title = "Lanceur video_encoder"
    this.frame.setAttribute("referrerpolicy", "no-referrer")
    this.element.appendChild(this.frame)
    this.frame.src = url.href
  }

  disconnect() {
    this.frame?.remove()
    this.frame = null
  }
}
