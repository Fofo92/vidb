import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  open() {
    const input = this.inputTarget
    if (typeof input.showPicker === "function") {
      try {
        input.showPicker()
        return
      } catch (_) {
        // Use the input directly when the browser does not allow showPicker.
      }
    }

    input.focus()
    input.click()
  }
}
