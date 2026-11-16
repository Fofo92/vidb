import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs/promises'

const source = await fs.readFile(new URL('../../app/javascript/controllers/encoder_launch_controller.js', import.meta.url), 'utf8')
const { default: Launch } = await import('data:text/javascript;base64,' + Buffer.from(
  source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
).toString('base64'))

function dispatch(url) {
  const calls = []
  const controller = Object.assign(new Launch(), {
    element: { ownerDocument: {
      defaultView: { location: { assign(value) { calls.push(value) } } },
      createElement() { assert.fail('No frame should be created') }
    } }
  })
  let prevented = false
  controller.open({ params: { url }, preventDefault() { prevented = true } })
  assert.equal(prevented, true)
  return calls
}

test('desktop and preparation links use the current context with the intact ticket', () => {
  for (const host of ['desktop', 'prepare']) {
    const url = 'vidb-encoder://' + host + '?ticket=signed%2Btoken&origin=https%3A%2F%2Fvidb.test'
    assert.deepEqual(dispatch(url), [url])
  }
})

test('invalid URLs and other destinations are rejected', () => {
  for (const url of ['invalid', 'https://vidb.test', 'javascript:alert(1)',
    'vidb-encoder://other', 'vidb-encoder://user@desktop']) {
    assert.deepEqual(dispatch(url), [])
  }
})
