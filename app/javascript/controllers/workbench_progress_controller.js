import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timer = window.setInterval(() => {
      if (document.visibilityState === "visible") this.element.reload()
    }, 5000)
  }

  disconnect() {
    window.clearInterval(this.timer)
  }
}
