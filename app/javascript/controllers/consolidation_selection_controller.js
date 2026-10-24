import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["case", "all", "count"]

  connect() {
    this.update()
  }

  toggleAll() {
    this.caseTargets.forEach(input => { input.checked = this.allTarget.checked })
    this.update()
  }

  update() {
    if (!this.hasAllTarget) return

    const count = this.caseTargets.filter(input => input.checked).length
    this.allTarget.checked = count > 0 && count === this.caseTargets.length
    this.allTarget.indeterminate = count > 0 && count < this.caseTargets.length
    this.countTarget.textContent = `${count} ${count === 1 ? "proposition cochée" : "propositions cochées"} sur cette page`
  }
}
