import test from "node:test"
import assert from "node:assert/strict"
import fs from "node:fs/promises"

const file = new URL("../../app/javascript/controllers/consolidation_selection_controller.js", import.meta.url)
const code = (await fs.readFile(file, "utf8")).replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
const { default: Selection } = await import(`data:text/javascript,${encodeURIComponent(code)}`)

function selection() {
  const result = new Selection()
  result.hasAllTarget = true
  result.allTarget = { checked: false, indeterminate: false }
  result.countTarget = { textContent: "" }
  result.caseTargets = [{ checked: false }, { checked: false }]
  return result
}

test("page selection is empty initially", () => {
  const result = selection()
  result.connect()
  assert.equal(result.allTarget.checked, false)
  assert.equal(result.countTarget.textContent, "0 propositions cochées sur cette page")
})

test("selecting a page only changes its case targets", () => {
  const result = selection()
  const anotherPage = { checked: false }
  result.allTarget.checked = true
  result.toggleAll()
  assert.deepEqual(result.caseTargets.map(input => input.checked), [true, true])
  assert.equal(anotherPage.checked, false)
  result.caseTargets[0].checked = false
  result.update()
  assert.equal(result.allTarget.indeterminate, true)
  assert.equal(result.allTarget.checked, false)
})

test("applied history has no selection controls", () => {
  const result = new Selection()
  result.hasAllTarget = false
  assert.doesNotThrow(() => result.connect())
})
