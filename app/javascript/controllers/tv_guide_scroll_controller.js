import { Controller } from "@hotwired/stimulus"

const storageKey = "tv-guide-scroll-position"

export default class extends Controller {
  connect() {
    const storedPosition = sessionStorage.getItem(storageKey)

    if (!storedPosition) return

    sessionStorage.removeItem(storageKey)

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.restore(storedPosition)
      })
    })
  }

  remember() {
    sessionStorage.setItem(
      storageKey,
      JSON.stringify({
        left: this.element.scrollLeft,
        top: this.element.scrollTop
      })
    )
  }

  restore(storedPosition) {
    const position = JSON.parse(storedPosition)

    this.element.scrollTo({
      left: position.left,
      top: position.top
    })
  }
}
