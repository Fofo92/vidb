import { Controller } from "@hotwired/stimulus"

const storageKey = "recording-intents-scroll-position"

export default class extends Controller {
  connect() {
    const position = sessionStorage.getItem(storageKey)
    if (!position) return

    sessionStorage.removeItem(storageKey)
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        window.scrollTo({ top: Number(position), left: 0 })
      })
    })
  }

  remember() {
    sessionStorage.setItem(storageKey, String(window.scrollY))
  }
}
