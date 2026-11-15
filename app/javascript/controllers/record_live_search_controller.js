import { Controller } from "@hotwired/stimulus"

// Keep typing outside the Turbo results frame; Turbo cancels superseded requests.
export default class extends Controller {
  static targets = ["input", "submit", "status"]
  static values = { frame: String, delay: { type: Number, default: 300 } }

  connect() {
    this.composing = false
    this.timer = null
  }

  disconnect() {
    this.cancel()
  }

  cancel() {
    clearTimeout(this.timer)
    this.timer = null
  }

  queue(event) {
    if (event.target !== this.inputTarget || event.isComposing || this.composing) return
    this.cancel()
    this.timer = setTimeout(() => {
      this.timer = null
      if (this.element.isConnected) {
        this.submitTarget.disabled = false
        this.element.requestSubmit(this.submitTarget)
      }
    }, this.delayValue)
  }

  compositionStarted() {
    this.composing = true
    this.cancel()
  }

  compositionEnded(event) {
    this.composing = false
    this.queue(event)
  }

  submitted() {
    this.cancel()
    this.status("Recherche…")
  }

  rendered(event) {
    if (event.target.id !== this.frameValue) return
    this.status("Résultats actualisés.")
    const context = event.target.querySelector("[data-live-search-context]")
    if (!context) return

    const document = this.element.ownerDocument
    const create = document.querySelector("[data-record-new-link]")
    if (create) create.href = context.dataset.newRecordUrl
    const menu = document.querySelector(".record-search-menu")
    menu?.setAttribute("data-record-search-menu-url-value", context.dataset.searchMenuUrl)
  }

  status(message, visible = false) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("visually-hidden", !visible)
  }

  failed(event) {
    if (event.target === this.element || event.target.id === this.frameValue) {
      this.status("Recherche indisponible : utilise Rechercher.", true)
    }
  }
}
