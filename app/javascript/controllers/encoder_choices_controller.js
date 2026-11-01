import { Controller } from "@hotwired/stimulus"

// Scroll only: all choices and selections remain intact, with no focus stealing.
export default class extends Controller {
  static values = { first: String }

  connect() {
    this.frame = requestAnimationFrame(() => this.center())
  }

  disconnect() {
    cancelAnimationFrame(this.frame)
  }

  center() {
    const select = this.element
    const options = Array.from(select.options)
    const first = options.find(option => option.value === this.firstValue && option.selected)
      || options.find(option => option.selected)
    if (!first) return
    const styles = getComputedStyle(select)
    const innerHeight = select.clientHeight - parseFloat(styles.paddingTop || 0) - parseFloat(styles.paddingBottom || 0)
    const rowHeight = first.getBoundingClientRect().height || innerHeight / select.size
    select.scrollTop = Math.max(0, (first.index - Math.floor(select.size / 2)) * rowHeight)
  }
}
