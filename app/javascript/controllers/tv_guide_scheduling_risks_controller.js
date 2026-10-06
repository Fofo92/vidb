import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, source: Number, date: String }

  connect() {
    this.cards = Array.from(this.element.querySelectorAll("[data-tv-guide-recording-status='unselected']"))
      .map(card => ({
        id: card.dataset.tvGuideProgramme,
        button: card.querySelector("[data-tv-guide-information]"),
        detail: card.querySelector("[data-tv-guide-capacity-detail]")
      }))
    if (!this.cards.length) return
    this.cards.forEach(card => this.prepare(card))
    this.abortController = new AbortController()
    this.load()
  }

  disconnect() {
    this.abortController?.abort()
  }

  async load() {
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        },
        signal: this.abortController.signal,
        body: JSON.stringify({
          guide_source_id: this.sourceValue,
          date: this.dateValue,
          programme_ids: this.cards.map(card => card.id)
        })
      })
      if (!response.ok) throw new Error("Capacity preview failed")
      const result = await response.json()
      if (this.abortController.signal.aborted) return
      this.element.dataset.tvGuideCapacityElapsedMs = result.elapsed_ms ?? ""
      this.cards.forEach(card => this.update(card, result))
    } catch (error) {
      if (error.name === "AbortError" || this.abortController.signal.aborted) return
      this.cards.forEach(card => this.update(card, { available: false }))
    }
  }

  prepare(card) {
    if (!card.detail || !card.button) return
    card.button.dataset.capacityOriginalLabel ||= card.button.getAttribute("aria-label")
    card.button.setAttribute("aria-label", card.button.dataset.capacityOriginalLabel)
    card.button.classList.remove("tv-guide-capacity-conflict", "tv-guide-capacity-unknown")
    card.button.dataset.tvGuideCapacityRisk = "pending"
    card.detail.textContent = "Vérification de la capacité Kaffeine en cours…"
  }

  update(card, result) {
    if (!card.detail || !card.button) return
    const risk = result.risks?.[card.id]
    const level = result.available ? risk?.level : "unknown"
    card.button.classList.remove("tv-guide-capacity-conflict", "tv-guide-capacity-unknown")
    card.button.setAttribute("aria-label", card.button.dataset.capacityOriginalLabel)
    card.button.dataset.tvGuideCapacityRisk = level || "clear"
    if (level) {
      card.button.classList.add(`tv-guide-capacity-${level}`)
      card.button.setAttribute("aria-label", `${card.button.getAttribute("aria-label")} ; alerte de capacité multiplex`)
    }
    const message = result.available
      ? risk?.message || "Capacité suffisante, qui sera contrôlée à la programmation."
      : result.message || "Capacité non vérifiée : consultation de Kaffeine impossible."
    card.detail.classList.add("tv-guide-capacity-detail")
    card.detail.dataset.level = level || "clear"
    this.renderDetail(card.detail, message, risk?.details || [], Boolean(level))
  }

  renderDetail(container, message, schedules, warning) {
    const summary = document.createElement("p")
    summary.textContent = message
    container.replaceChildren(summary)
    if (schedules.length) {
      const heading = document.createElement("p")
      heading.textContent = "Enregistrements chevauchant cette capture :"
      container.append(heading)
      const list = document.createElement("ul")
      schedules.forEach(schedule => list.append(this.scheduleItem(schedule)))
      container.append(list)
    }
    if (warning) {
      const reminder = document.createElement("p")
      reminder.className = "text-body-secondary"
      reminder.textContent = "Capacité contrôlée à nouveau à la programmation."
      container.append(reminder)
    }
  }

  scheduleItem(schedule) {
    const item = document.createElement("li")
    if (typeof schedule === "string") {
      item.textContent = schedule
      return item
    }
    const title = document.createElement("strong")
    title.textContent = schedule.title
    const information = document.createElement("div")
    information.textContent = `${schedule.channel} · ${schedule.starts_at} – ${schedule.ends_at}`
    item.append(title, information)
    return item
  }
}
