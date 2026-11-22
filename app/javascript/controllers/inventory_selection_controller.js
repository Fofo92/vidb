import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["all", "item"]

  connect() {
    this.sync()
  }

  toggle() {
    for (const item of this.itemTargets) {
      item.checked = this.allTarget.checked
    }
    this.sync()
  }

  sync() {
    const total = this.itemTargets.length
    const checked = this.itemTargets.filter(item => item.checked).length
    this.allTarget.disabled = total === 0
    this.allTarget.checked = total > 0 && checked === total
    this.allTarget.indeterminate = checked > 0 && checked < total
  }
}
