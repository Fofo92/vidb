import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["permission", "fields"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.fieldsTarget.disabled = this.hasPermissionTarget && !this.permissionTarget.checked
  }
}
