import assert from 'node:assert/strict'
import fs from 'node:fs'
const path = new URL('../../app/javascript/controllers/tv_guide_clock_controller.js', import.meta.url)
const source = fs.readFileSync(path, 'utf8').replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
const { default: Clock } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'))
function clock(start, positions) {
 const c = new Clock()
 c.startValue = start; c.positionsValue = positions
 c.markerTarget = { hidden: true, style: {} }; c.labelTarget = {}
 c.element = { querySelector: s => ({ getBoundingClientRect: () => ({ top: s.startsWith('.') ? 140 : 100 }) }) }
 return c
}
const c = clock('2026-10-18T00:00:00+02:00', [0, 1, 24, 25])
c.updateMarker(Date.parse(c.startValue) + 90000)
assert.equal(c.markerTarget.style.top, '52.5px')
assert.equal(c.labelTarget.textContent, '00:01')
assert.equal(c.markerTarget.hidden, false)
c.updateMarker(Date.parse(c.startValue) - 1); assert.equal(c.markerTarget.hidden, true)
c.updateMarker(Date.parse(c.startValue) + 180000); assert.equal(c.markerTarget.hidden, true)
for (const [start, minutes, end] of [
 ['2026-03-29T00:00:00+01:00', 1380, '2026-03-30T00:00:00+02:00'],
 ['2026-10-25T00:00:00+02:00', 1500, '2026-10-26T00:00:00+01:00']
]) {
 const d = clock(start, Array.from({ length: minutes + 1 }, (_, i) => i))
 d.updateMarker(Date.parse(end) - 60000); assert.equal(d.markerTarget.hidden, false)
 d.updateMarker(Date.parse(end)); assert.equal(d.markerTarget.hidden, true)
}
console.log('Clock projection, day boundaries and both Paris DST transitions: passed')
