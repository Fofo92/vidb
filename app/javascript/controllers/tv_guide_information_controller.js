import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    const information = event.target.closest("[data-tv-guide-information]")
    if (!information || !this.element.contains(information)) return

    information.closest(".tv-guide-programme")?.classList.add(
      "tv-guide-programme--information-open"
    )
  }

  close(event) {
    const programme = event.target.closest(".tv-guide-programme--information-open")
    if (!programme || (event.relatedTarget instanceof Node && programme.contains(event.relatedTarget))) return

    programme.classList.remove("tv-guide-programme--information-open")
  }
}
