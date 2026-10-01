import { Controller } from "@hotwired/stimulus"

const openClass = "tv-guide-programme--information-open"
const pinnedAlertClass = "tv-guide-refresh-alert--pinned"

export default class extends Controller {
  open(event) {
    const information = event.target.closest("[data-tv-guide-information]")
    if (!information || !this.element.contains(information)) return

    information.closest(".tv-guide-programme")?.classList.add(openClass)
  }

  close(event) {
    const programme = event.target.closest(`.${openClass}`)
    if (!programme || programme === this.pinnedProgramme) return
    if (event.relatedTarget instanceof Node && programme.contains(event.relatedTarget)) return

    programme.classList.remove(openClass)
  }

  toggle(event) {
    const alert = event.target.closest("[data-tv-guide-refresh-alert]")
    if (alert && this.element.contains(alert)) {
      if (event.target.closest(".tv-guide-refresh-alert-detail")) return

      event.preventDefault()
      event.stopPropagation()
      const wasPinned = alert === this.pinnedAlert
      this.dismiss()
      if (wasPinned) return

      this.pinnedAlert = alert
      alert.classList.add(pinnedAlertClass)
      alert.setAttribute("aria-expanded", "true")
      return
    }
    if (event.type === "keydown") return

    const information = event.target.closest("[data-tv-guide-information]")
    if (!information || !this.element.contains(information)) {
      if ((this.pinnedProgramme && !this.pinnedProgramme.contains(event.target)) ||
          (this.pinnedAlert && !this.pinnedAlert.contains(event.target))) this.dismiss()
      return
    }

    event.preventDefault()
    event.stopPropagation()

    const programme = information.closest(".tv-guide-programme")
    const wasPinned = programme === this.pinnedProgramme
    this.dismiss()
    if (wasPinned) return

    this.pinnedProgramme = programme
    programme.classList.add(openClass)
    information.setAttribute("aria-expanded", "true")
  }

  dismiss() {
    if (this.pinnedAlert) {
      this.pinnedAlert.classList.remove(pinnedAlertClass)
      this.pinnedAlert.setAttribute("aria-expanded", "false")
      this.pinnedAlert = null
    }
    if (!this.pinnedProgramme) return

    this.pinnedProgramme.classList.remove(openClass)
    this.pinnedProgramme.querySelector("[data-tv-guide-information]")?.setAttribute("aria-expanded", "false")
    this.pinnedProgramme = null
  }
}
