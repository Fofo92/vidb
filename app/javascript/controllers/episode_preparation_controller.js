import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selection", "proposal", "notice"]

  connect() {
    this.changed()
  }

  changed() {
    const dirty = this.selectionTargets.some(input => input.value !== input.defaultValue)
    this.proposalTargets.forEach(proposal => { proposal.disabled = dirty })
    this.noticeTarget.hidden = !dirty
  }
}
