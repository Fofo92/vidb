import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs/promises'

const source = await fs.readFile(new URL('../../app/javascript/controllers/encoder_launch_controller.js', import.meta.url), 'utf8')
const { default: Launch } = await import('data:text/javascript;base64,' + Buffer.from(
  source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
).toString('base64'))

function launcher() {
  const frames = []
  const removed = []
  const element = {
    ownerDocument: {
      createElement(tag) {
        assert.equal(tag, 'iframe')
        return { setAttribute() {}, remove() { removed.push(this) } }
      }
    },
    appendChild(frame) { frames.push(frame) }
  }
  const controller = Object.assign(new Launch(), { element })
  return { controller, frames, removed }
}

function click(controller, url) {
  let prevented = false
  controller.open({ params: { url }, preventDefault() { prevented = true } })
  assert.equal(prevented, true)
}

test('all desktop commands and record preparations use a hidden frame and retain their signed URL', () => {
  const { controller, frames } = launcher()
  for (const host of ['desktop', 'prepare']) {
    const url = 'vidb-encoder://' + host + '?ticket=signed%2Btoken&origin=https%3A%2F%2Fvidb.test'
    click(controller, url)
    assert.equal(frames.at(-1).src, url)
    assert.equal(frames.at(-1).hidden, true)
  }
})

test('repeated identical clicks dispatch again and leaving the page removes the frame', () => {
  const { controller, frames, removed } = launcher()
  const url = 'vidb-encoder://desktop?ticket=queue'
  click(controller, url)
  click(controller, url)
  assert.equal(frames.length, 2)
  assert.deepEqual(removed, [frames[0]])
  controller.disconnect()
  assert.deepEqual(removed, frames)
  assert.equal(controller.frame, null)
})

test('malformed URLs and other destinations never navigate or create a frame', () => {
  const { controller, frames } = launcher()
  for (const url of ['invalid', 'https://vidb.test', 'javascript:alert(1)',
    'vidb-encoder://other', 'vidb-encoder://user@desktop']) click(controller, url)
  assert.equal(frames.length, 0)
})
