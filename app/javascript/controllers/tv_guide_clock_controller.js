import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["marker", "label"]
  static values = { start: String, positions: Array }

  connect() {
    this.update()
    this.timer = setInterval(() => this.update(), 15000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  update() {
    const now = Date.now()
    this.updateMarker(now)
    this.element.querySelectorAll("[data-tv-guide-ends-at]").forEach(programme => {
      const ended = Date.parse(programme.dataset.tvGuideEndsAt) <= now
      programme.classList.toggle("tv-guide-programme--past", ended)
      programme.querySelectorAll("[data-tv-guide-schedule-action], [data-tv-guide-recording-toggle]").forEach(button => {
        const cancelling = button.matches("[data-tv-guide-recording-toggle]") &&
          programme.dataset.tvGuideRecordingStatus === "selected"
        button.disabled = ended && !cancelling
      })
    })
  }

  updateMarker(now) {
    const minute = (now - Date.parse(this.startValue)) / 60000
    const positions = this.positionsValue
    const visible = minute >= 0 && minute < positions.length - 1
    this.markerTarget.hidden = !visible
    if (!visible) return

    const index = Math.floor(minute)
    const top = positions[index] + (positions[index + 1] - positions[index]) * (minute - index)
    const axis = this.element.querySelector(".tv-guide-time-axis-body")
    const grid = this.element.querySelector("[data-tv-guide-grid]")
    const heading = axis.getBoundingClientRect().top - grid.getBoundingClientRect().top
    this.markerTarget.style.top = `${heading + top}px`
    this.labelTarget.textContent = new Intl.DateTimeFormat("fr-FR", {
      timeZone: "Europe/Paris", hour: "2-digit", minute: "2-digit"
    }).format(now)
  }
}
