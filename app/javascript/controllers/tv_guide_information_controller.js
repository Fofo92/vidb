import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.outsideClick = event => {
      if (this.panel?.contains(event.target) || this.trigger?.contains(event.target)) return
      this.dismiss()
    }
    this.escape = event => {
      if (event.key !== "Escape" || !this.panel) return
      event.preventDefault()
      this.dismiss({ restoreFocus: true })
    }
    this.reposition = () => this.position()
    document.addEventListener("click", this.outsideClick)
    document.addEventListener("keydown", this.escape)
    window.addEventListener("resize", this.reposition)
    this.element.addEventListener("scroll", this.reposition)
  }

  disconnect() {
    this.dismiss()
    document.removeEventListener("click", this.outsideClick)
    document.removeEventListener("keydown", this.escape)
    window.removeEventListener("resize", this.reposition)
    this.element.removeEventListener("scroll", this.reposition)
  }

  open(event) {
    const trigger = this.findTrigger(event.target)
    if (!trigger || this.pinned || this.suppressOpen) return

    this.cancelClose()
    if (trigger !== this.trigger) this.show(trigger)
  }

  close(event) {
    if (!this.panel || this.pinned || this.isInside(event.relatedTarget)) return

    this.scheduleClose()
  }

  toggle(event) {
    const trigger = this.findTrigger(event.target)
    if (!trigger) return
    if (event.type === "keydown" && trigger.matches("[data-tv-guide-information]")) return

    event.preventDefault()
    event.stopPropagation()
    if (trigger === this.trigger && this.pinned) {
      this.dismiss({ restoreFocus: true })
      return
    }

    this.show(trigger, true)
    this.panel.focus({ preventScroll: true })
  }

  findTrigger(target) {
    const trigger = target.closest?.("[data-tv-guide-information], [data-tv-guide-refresh-alert]")
    return trigger && this.element.contains(trigger) ? trigger : null
  }

  show(trigger, pinned = false) {
    this.dismiss()
    this.trigger = trigger
    this.pinned = pinned
    this.programme = trigger.closest(".tv-guide-programme")
    this.moved = []
    this.panel = document.createElement("section")
    this.panel.className = "tv-guide-information-panel"
    this.panel.id = "tv-guide-information-panel"
    this.panel.tabIndex = -1
    this.panel.setAttribute("role", "dialog")
    this.panel.setAttribute("aria-label", trigger.getAttribute("aria-label"))
    this.panel.style.visibility = "hidden"
    this.buildContent()
    this.bindPanel()
    document.body.append(this.panel)
    this.position()
    this.panel.style.visibility = ""
    trigger.setAttribute("aria-expanded", "true")
    trigger.setAttribute("aria-controls", this.panel.id)
  }

  buildContent() {
    const header = document.createElement("header")
    const title = document.createElement("strong")
    title.textContent = this.programme.querySelector("[data-tv-guide-title]").textContent.trim()
    const close = document.createElement("button")
    close.type = "button"
    close.textContent = "×"
    close.setAttribute("aria-label", "Fermer les informations")
    close.addEventListener("click", () => this.dismiss({ restoreFocus: true }))
    header.append(title, close)
    this.panel.append(header)
    this.content = document.createElement("div")
    this.content.className = "tv-guide-information-panel-content"
    this.panel.append(this.content)

    const times = document.createElement("p")
    times.textContent = this.programme.querySelector(".tv-guide-programme-times").textContent.trim()
    this.content.append(times)
    this.move(this.programme.querySelector(".tv-guide-refresh-alert-detail"))
    if (this.trigger.matches("[data-tv-guide-information]")) {
      this.move(this.programme.querySelector("[data-tv-guide-secondary]"))
    }
  }

  move(node) {
    if (!node) return

    const placeholder = document.createComment("tv-guide-information")
    node.before(placeholder)
    this.moved.push({ node, placeholder })
    this.content.append(node)
  }

  bindPanel() {
    this.panel.addEventListener("mouseenter", () => this.cancelClose())
    this.panel.addEventListener("focusin", () => this.cancelClose())
    this.panel.addEventListener("mouseleave", event => this.close(event))
    this.panel.addEventListener("focusout", event => this.close(event))
    this.panel.addEventListener("submit", () => {
      this.application.getControllerForElementAndIdentifier(this.element, "tv-guide-scroll")?.remember()
    })
  }

  isInside(target) {
    return target instanceof Node &&
      (this.programme?.contains(target) || this.panel?.contains(target))
  }

  scheduleClose() {
    this.cancelClose()
    this.closeTimer = window.setTimeout(() => {
      if (!this.pinned) this.dismiss()
    }, 200)
  }

  cancelClose() {
    window.clearTimeout(this.closeTimer)
  }

  position() {
    if (!this.panel || !this.trigger) return

    const margin = 8
    const width = document.documentElement.clientWidth || window.innerWidth
    const height = window.innerHeight
    this.panel.style.width = `${Math.max(1, Math.min(384, width - 2 * margin))}px`
    this.panel.style.maxHeight = `${Math.max(1, height - 2 * margin)}px`
    const anchor = this.trigger.getBoundingClientRect()
    const bounds = this.panel.getBoundingClientRect()
    const left = Math.max(margin, Math.min(anchor.left, width - bounds.width - margin))
    const below = anchor.bottom + margin
    const preferredTop = below + bounds.height <= height - margin ? below : anchor.top - bounds.height - margin
    const top = Math.max(margin, Math.min(preferredTop, height - bounds.height - margin))
    this.panel.style.left = `${left}px`
    this.panel.style.top = `${top}px`
  }

  dismiss(options = {}) {
    const restoreFocus = options.restoreFocus || options.key === "Escape"
    this.cancelClose()
    const trigger = this.trigger
    const wasPinned = this.pinned
    this.trigger = null
    this.pinned = false
    for (const { node, placeholder } of this.moved || []) placeholder.replaceWith(node)
    this.moved = []
    this.panel?.remove()
    this.panel = null
    this.programme = null
    if (trigger) {
      trigger.setAttribute("aria-expanded", "false")
      trigger.removeAttribute("aria-controls")
      if (restoreFocus && wasPinned && trigger.isConnected) {
        this.suppressOpen = true
        trigger.focus({ preventScroll: true })
        this.suppressOpen = false
      }
    }
  }
}
