import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["summary", "rows", "message"]
  static values = { url: String }

  async update(event) {
    event.preventDefault()
    if (this.busy) return

    const button = event.currentTarget
    const state = { field: button.dataset.field, value: button.dataset.value }
    if (button.dataset.childId) state.child_id = button.dataset.childId
    this.busy = true
    this.messageTarget.textContent = "Enregistrement…"
    this.setDisabled(true)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ state })
      })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error || "La modification a échoué.")

      this.summaryTarget.innerHTML = result.summary
      this.rowsTarget.innerHTML = result.rows
      this.element.querySelectorAll("[data-state-menu]").forEach(menu => { menu.open = false })
      this.messageTarget.textContent = `${result.count} fiche(s) mise(s) à jour.`
      const selector = state.child_id
        ? `[data-state-column="${state.field}"] [data-child-id="${state.child_id}"]`
        : `th[data-state-column="${state.field}"] summary`
      this.element.querySelector(selector)?.focus()
    } catch (error) {
      this.messageTarget.textContent = error.message || "Impossible d’enregistrer la modification."
    } finally {
      this.busy = false
      this.setDisabled(false)
    }
  }

  setDisabled(disabled) {
    this.element.querySelectorAll('button[data-action="record-states#update"]')
      .forEach(button => { button.disabled = disabled })
  }
}
