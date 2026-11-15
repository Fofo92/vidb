import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = { url: String }

  toggle() {
    if (this.element.open) this.load()
  }

  urlValueChanged() {
    if (!this.hasFrameTarget) return
    if (this.element.open) this.load()
    else if (this.frameTarget.getAttribute("src") !== this.urlValue) this.frameTarget.removeAttribute("src")
  }

  load() {
    if (this.frameTarget.getAttribute("src") !== this.urlValue) this.frameTarget.src = this.urlValue
  }
}
