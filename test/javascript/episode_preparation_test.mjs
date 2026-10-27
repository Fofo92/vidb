import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const source = readFileSync(new URL('../../app/javascript/controllers/episode_preparation_controller.js', import.meta.url), 'utf8')
  .replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
const { default: Preparation } = await import(`data:text/javascript,${encodeURIComponent(source)}`)

test('changing the episode blocks stale proposals until the loaded choice is restored', () => {
  const controller = new Preparation()
  controller.selectionTargets = [{ value: '1', defaultValue: '1' }]
  controller.proposalTargets = [{ disabled: false }]
  controller.noticeTarget = { hidden: true }
  controller.connect()
  assert.equal(controller.proposalTargets[0].disabled, false)
  controller.selectionTargets[0].value = '2'
  controller.changed()
  assert.equal(controller.proposalTargets[0].disabled, true)
  assert.equal(controller.noticeTarget.hidden, false)
  controller.selectionTargets[0].value = '1'
  controller.changed()
  assert.equal(controller.proposalTargets[0].disabled, false)
  assert.equal(controller.noticeTarget.hidden, true)
})
