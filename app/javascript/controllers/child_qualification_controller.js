import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selection"]

  selectAll() {
    this.selectionTargets.forEach((input) => { input.checked = true })
  }

  selectNone() {
    this.selectionTargets.forEach((input) => { input.checked = false })
  }

  toggleField(event) {
    const field = event.target.closest("[data-child-qualification-field]")
    field.querySelectorAll("[data-child-qualification-input]").forEach((input) => {
      input.disabled = !event.target.checked
    })
    const child = field.closest("[data-qualifiable-child]")
    if (event.target.checked && child) {
      child.querySelector("[data-child-qualification-target='selection']").checked = true
    }
  }
}
