import { Controller } from "@hotwired/stimulus"

const REGIONS = "[data-record-live-region]"
const EDITABLE = 'input, textarea, select, [contenteditable]:not([contenteditable="false"])'

export function normalizedRegion(region) {
  const clone = region.cloneNode(true)
  clone.querySelectorAll('input[name="authenticity_token"]').forEach(node => node.remove())
  clone.querySelectorAll("details[open]").forEach(node => node.removeAttribute("open"))
  return clone.innerHTML
}

function detailKey(detail, region) {
  const owner = detail.closest("[data-video-asset], [data-record-live-child]")
  if (owner) {
    const id = owner.dataset.videoAsset || owner.dataset.recordLiveChild
    return `${owner.hasAttribute("data-video-asset") ? "asset" : "child"}:${id}:${Array.from(owner.querySelectorAll("details")).indexOf(detail)}`
  }
  const title = detail.querySelector("summary")?.textContent.trim() || ""
  const peers = Array.from(region.querySelectorAll("details")).filter(node =>
    !node.closest("[data-video-asset], [data-record-live-child]") && (node.querySelector("summary")?.textContent.trim() || "") === title)
  return `detail:${title}:${peers.indexOf(detail)}`
}

function locator(node, region) {
  if (node.id) return { id: node.id }
  if (node.matches("summary") && node.parentElement.matches("details")) {
    return { detail: detailKey(node.parentElement, region) }
  }
  const path = []
  let current = node
  while (current !== region) {
    const parent = current.parentElement
    if (!parent) return null
    path.unshift(Array.from(parent.children).indexOf(current))
    current = parent
    if (current.matches("[data-video-asset], [data-record-live-child]")) {
      return { owner: current.dataset.videoAsset || current.dataset.recordLiveChild,
        ownerType: current.hasAttribute("data-video-asset") ? "data-video-asset" : "data-record-live-child", path }
    }
  }
  return { path }
}

function locate(region, key) {
  if (!key) return null
  if (key.id) return Array.from(region.querySelectorAll("[id]")).find(node => node.id === key.id)
  if (key.detail) {
    return Array.from(region.querySelectorAll("details")).find(node => detailKey(node, region) === key.detail)?.querySelector("summary")
  }
  let node = key.owner
    ? Array.from(region.querySelectorAll(`[${key.ownerType}]`)).find(item => item.getAttribute(key.ownerType) === key.owner)
    : region
  for (const index of key.path) node = node?.children[index]
  return node
}

export function replaceRegions(root, incoming, viewport = window) {
  const regions = Array.from(root.querySelectorAll(REGIONS))
  const replacements = regions.map(region => [region,
    Array.from(incoming.querySelectorAll(REGIONS)).find(node => node.dataset.recordLiveRegion === region.dataset.recordLiveRegion)])
  if (replacements.some(([, fresh]) => !fresh)) throw new Error("Incomplete record response")
  const scroll = [viewport.scrollX, viewport.scrollY]
  const active = root.ownerDocument.activeElement
  let changed = false
  for (const [region, fresh] of replacements) {
    if (normalizedRegion(region) === normalizedRegion(fresh)) continue
    const focus = region.contains(active) ? locator(active, region) : null
    const open = new Set(Array.from(region.querySelectorAll("details[open]")).map(node => detailKey(node, region)))
    const scrolling = Array.from(region.querySelectorAll(".table-responsive"))
      .map(node => ({ key: locator(node, region), left: node.scrollLeft, top: node.scrollTop }))
    region.replaceChildren(...Array.from(fresh.childNodes))
    region.querySelectorAll("details").forEach(node => { node.open = open.has(detailKey(node, region)) })
    for (const item of scrolling) {
      const node = locate(region, item.key)
      if (node) { node.scrollLeft = item.left; node.scrollTop = item.top }
    }
    locate(region, focus)?.focus({ preventScroll: true })
    changed = true
  }
  if (changed) viewport.scrollTo(...scroll)
  return changed
}

export default class extends Controller {
  static targets = ["status"]
  static values = { url: String, version: String }

  connect() {
    this.stopped = false
    this.request = null
    this.revision = 0
    this.failures = 0
    this.lastInteraction = 0
    this.pointerHeld = false
    this.stateBusy = false
    this.dirtyForms = new Set()
    this.pendingForms = new Set()
    this.lifecycle = new AbortController()
    const listen = (target, event, callback) => target.addEventListener(event, callback, { signal: this.lifecycle.signal })
    listen(document, "visibilitychange", () => this.visibilityChanged())
    listen(document, "turbo:before-cache", () => this.stop())
    listen(this.element, "record-states:busy", event => {
      this.stateBusy = event.detail.busy
      this.revision++
    })
    for (const name of ["input", "change"]) listen(this.element, name, event => {
      if (event.target.form) this.dirtyForms.add(event.target.form)
      this.revision++
    })
    listen(this.element, "reset", event => { this.dirtyForms.delete(event.target); this.revision++ })
    listen(this.element, "turbo:submit-start", event => { this.pendingForms.add(event.target); this.revision++ })
    listen(this.element, "turbo:submit-end", event => { this.pendingForms.delete(event.target); this.revision++ })
    listen(this.element, "pointerdown", () => { this.pointerHeld = true; this.lastInteraction = Date.now() })
    listen(document, "pointerup", () => { this.pointerHeld = false; this.lastInteraction = Date.now() })
    listen(document, "pointercancel", () => { this.pointerHeld = false })
    listen(window, "blur", () => { this.pointerHeld = false })
    listen(this.element, "keydown", () => { this.lastInteraction = Date.now() })
    this.schedule()
  }

  disconnect() {
    this.stop()
    this.lifecycle?.abort()
  }

  stop() {
    this.stopped = true
    clearTimeout(this.timer)
    this.request?.abort()
  }

  visibilityChanged() {
    clearTimeout(this.timer)
    this.pointerHeld = false
    if (document.hidden) this.request?.abort()
    else this.schedule(0)
  }

  schedule(delay = 15000) {
    clearTimeout(this.timer)
    if (!this.stopped && !document.hidden) this.timer = setTimeout(() => this.poll(), delay)
  }

  busy() {
    const active = this.element.ownerDocument.activeElement
    return this.stateBusy || this.pointerHeld || this.dirtyForms.size > 0 || this.pendingForms.size > 0 ||
      (this.element.contains(active) && active.matches(EDITABLE)) ||
      Boolean(this.element.querySelector("[data-state-menu][open]")) || Date.now() - this.lastInteraction < 500
  }

  async poll() {
    if (this.stopped || document.hidden) return
    if (this.request || this.busy()) { this.schedule(); return }
    const revision = this.revision
    const lifecycle = this.lifecycle
    const request = new AbortController()
    this.request = request
    const timeout = setTimeout(() => request.abort(), 20000)
    try {
      const url = new URL(this.urlValue, window.location.href)
      url.searchParams.set("version", this.versionValue)
      const response = await fetch(url, { credentials: "same-origin", cache: "no-store",
        headers: { Accept: "application/json" }, signal: request.signal })
      if (this.stopped || document.hidden || request.signal.aborted || lifecycle !== this.lifecycle) return
      if ([401, 403, 404].includes(response.status) || response.redirected) {
        this.unavailable(response.status)
        return
      }
      if (response.status === 204 || response.status === 409) { this.failures = 0; return }
      if (!response.ok || !response.headers.get("content-type")?.includes("application/json")) throw new Error("Refresh unavailable")
      const result = await response.json()
      if (this.stopped || document.hidden || request.signal.aborted || lifecycle !== this.lifecycle || revision !== this.revision || this.busy()) return
      if (!/^[a-f0-9]{64}$/.test(result.version) || typeof result.html !== "string") throw new Error("Invalid record response")
      const incoming = new DOMParser().parseFromString(result.html, "text/html").querySelector("[data-record-live-root]")
      if (!incoming) throw new Error("Missing record response")
      if (replaceRegions(this.element, incoming)) this.statusTarget.textContent = "Fiche actualisée."
      this.versionValue = result.version
      this.failures = 0
    } catch (error) {
      if (error.name !== "AbortError" && !request.signal.aborted && lifecycle === this.lifecycle) this.failures++
    } finally {
      clearTimeout(timeout)
      if (this.request === request) this.request = null
      if (lifecycle === this.lifecycle) this.schedule(Math.min(60000, 15000 * (1 + this.failures)))
    }
  }

  unavailable(status) {
    this.stop()
    this.statusTarget.textContent = status === 404 ? "Cette fiche n’est plus disponible." : "Actualisation suspendue : reconnecte-toi, puis recharge cette fiche."
    this.statusTarget.classList.remove("record-show-sr-only")
  }
}
