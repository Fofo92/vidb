import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.outsideClick = event => {
      if (!this.panel?.contains(event.target) && !this.trigger?.contains(event.target)) this.dismiss()
    }
    this.escape = event => {
      if (event.key === "Escape" && this.panel) {
        event.preventDefault()
        this.dismiss(true)
      }
    }
    this.closeOnMove = () => this.dismiss()
    document.addEventListener("click", this.outsideClick)
    document.addEventListener("keydown", this.escape)
    window.addEventListener("resize", this.closeOnMove)
    this.scroller = this.element.closest("[data-tv-guide-scroll]")
    this.scroller?.addEventListener("scroll", this.closeOnMove)
  }

  disconnect() {
    this.dismiss()
    document.removeEventListener("click", this.outsideClick)
    document.removeEventListener("keydown", this.escape)
    window.removeEventListener("resize", this.closeOnMove)
    this.scroller?.removeEventListener("scroll", this.closeOnMove)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const trigger = event.currentTarget
    if (this.trigger === trigger) return this.dismiss(true)
    this.dismiss()
    this.trigger = trigger
    this.panel = document.createElement("section")
    this.panel.className = "tv-guide-multiplex-panel"
    this.panel.setAttribute("role", "dialog")
    this.panel.setAttribute("aria-label", "Charge des multiplex")
    this.panel.tabIndex = -1
    this.appendContent(trigger)
    document.body.append(this.panel)
    trigger.setAttribute("aria-expanded", "true")
    this.position()
    this.panel.focus({ preventScroll: true })
  }

  appendContent(trigger) {
    const header = document.createElement("header")
    const title = document.createElement("strong")
    title.textContent = "Sélections, marges comprises"
    const close = document.createElement("button")
    close.type = "button"
    close.textContent = "×"
    close.setAttribute("aria-label", "Fermer")
    close.addEventListener("click", () => this.dismiss(true))
    header.append(title, close)
    const content = document.createElement("div")
    content.textContent = trigger.getAttribute("title")
    this.panel.append(header, content)
  }

  position() {
    const rect = this.trigger.getBoundingClientRect()
    const width = this.panel.offsetWidth
    const height = this.panel.offsetHeight
    this.panel.style.left = `${Math.max(8, Math.min(rect.right + 8, window.innerWidth - width - 8))}px`
    this.panel.style.top = `${Math.max(8, Math.min(rect.top, window.innerHeight - height - 8))}px`
  }

  dismiss(restoreFocus = false) {
    const trigger = this.trigger
    this.panel?.remove()
    this.panel = null
    this.trigger = null
    trigger?.setAttribute("aria-expanded", "false")
    if (restoreFocus) trigger?.focus({ preventScroll: true })
  }
}
