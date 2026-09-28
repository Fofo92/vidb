import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "name"]

  connect() {
    if (!this.hasImageTarget || !this.imageTarget.complete) return

    if (this.imageTarget.naturalWidth > 0) {
      this.loaded()
    } else {
      this.failed()
    }
  }

  loaded() {
    if (!this.hasImageTarget) return

    this.nameTarget.hidden = this.imageTarget.naturalWidth > 0
  }

  failed() {
    this.imageTarget.hidden = true
    this.nameTarget.hidden = false
  }
}
