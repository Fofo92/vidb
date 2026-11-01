import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

// No browser dependency: exercise scrolling without modifying selected options.
const filename = new URL("../../app/javascript/controllers/encoder_choices_controller.js", import.meta.url)
const source = fs.readFileSync(filename, "utf8")
  .replace('import { Controller } from "@hotwired/stimulus"', "")
  .replace("export default class", "globalThis.Choices = class")
const context = vm.createContext({ Controller: class {}, requestAnimationFrame: fn => fn(), cancelAnimationFrame() {},
  getComputedStyle: () => ({ paddingTop: "0", paddingBottom: "0" }) })
vm.runInContext(source, context)

const options = Array.from({ length: 12 }, (_, index) => ({
  value: String(index), index, selected: [4, 8].includes(index), getBoundingClientRect: () => ({ height: 20 })
}))
const controller = new context.Choices()
controller.element = { options, size: 3, clientHeight: 60, scrollTop: 0 }
controller.firstValue = "8"
controller.connect()
assert.equal(controller.element.scrollTop, 140)
assert.deepEqual(options.filter(option => option.selected).map(option => option.value), ["4", "8"])
controller.firstValue = "missing"
controller.center()
assert.equal(controller.element.scrollTop, 60)
options.forEach(option => { option.selected = false })
controller.element.scrollTop = 0
controller.center()
assert.equal(controller.element.scrollTop, 0)
console.log("Three-row selector centering and selections: OK")
