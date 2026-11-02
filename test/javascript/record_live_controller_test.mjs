import test, { beforeEach, afterEach } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs/promises'

const source = await fs.readFile(new URL('../../app/javascript/controllers/record_live_controller.js', import.meta.url), 'utf8')
const { default: LiveController, replaceRegions } = await import('data:text/javascript;base64,' + Buffer.from(
  source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
).toString('base64'))
const original = Object.fromEntries(['document', 'window', 'fetch', 'setTimeout', 'clearTimeout', 'DOMParser'].map(key => [key, globalThis[key]]))
let controller, document, timers, fetches

beforeEach(() => {
  document = Object.assign(new EventTarget(), { hidden: false, activeElement: null })
  globalThis.document = document
  globalThis.window = Object.assign(new EventTarget(), { location: { href: 'https://vidb.test/records/12' } })
  timers = new Map()
  fetches = []
  globalThis.setTimeout = (callback, delay) => { const id = Symbol(); timers.set(id, { callback, delay }); return id }
  globalThis.clearTimeout = id => timers.delete(id)
  globalThis.fetch = async (...args) => { fetches.push(args); return { status: 204 } }
  const element = Object.assign(new EventTarget(), { ownerDocument: document, contains: () => false,
    querySelector: () => null, querySelectorAll: () => [] })
  controller = Object.assign(new LiveController(), { element, urlValue: '/records/12/live', versionValue: 'a'.repeat(64),
    statusTarget: { textContent: '', classList: { remove() {} } } })
  controller.connect()
})

afterEach(() => {
  controller.disconnect()
  Object.assign(globalThis, original)
})

function reply(status, result = {}) {
  return { status, ok: status === 200, redirected: false, headers: { get: () => 'application/json' }, json: async () => result }
}

function event(name, detail) {
  controller.element.dispatchEvent(new CustomEvent(name, { detail }))
}

test('polls every fifteen seconds without overlapping requests', async () => {
  assert.equal([...timers.values()][0].delay, 15000)
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve; fetches.push('request') })
  const pending = controller.poll()
  await controller.poll()
  assert.equal(fetches.length, 1)
  finish(reply(204))
  await pending
  assert.equal(controller.versionValue, 'a'.repeat(64))
})

test('hidden tabs stop polling and visible tabs resume immediately', async () => {
  document.hidden = true
  document.dispatchEvent(new Event('visibilitychange'))
  assert.equal(timers.size, 0)
  await controller.poll()
  assert.equal(fetches.length, 0)
  document.hidden = false
  document.dispatchEvent(new Event('visibilitychange'))
  assert.equal([...timers.values()][0].delay, 0)
})

test('unchanged responses do not touch the DOM or the version', async () => {
  await controller.poll()
  assert.equal(fetches.length, 1)
  const [url, options] = fetches[0]
  assert.equal(url.searchParams.get('version'), 'a'.repeat(64))
  assert.equal(options.credentials, 'same-origin')
  assert.equal(options.cache, 'no-store')
  assert.equal(controller.statusTarget.textContent, '')
})

test('pending edits, active inputs and open state menus defer updates', async () => {
  controller.dirtyForms.add({})
  await controller.poll()
  controller.dirtyForms.clear()
  document.activeElement = { matches: () => true }
  controller.element.contains = () => true
  await controller.poll()
  controller.element.contains = () => false
  controller.element.querySelector = () => ({ open: true })
  await controller.poll()
  assert.equal(fetches.length, 0)
})

test('manual state actions defer polling and invalidate an older pending response', async () => {
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve })
  const pending = controller.poll()
  event('record-states:busy', { busy: true })
  event('record-states:busy', { busy: false })
  globalThis.DOMParser = class { constructor() { assert.fail('stale response must not be parsed') } }
  finish(reply(200, { version: 'b'.repeat(64), html: '<div></div>' }))
  await pending
  assert.equal(controller.versionValue, 'a'.repeat(64))
  assert.equal(controller.failures, 0)
})

test('an active state action prevents new requests', async () => {
  event('record-states:busy', { busy: true })
  await controller.poll()
  assert.equal(fetches.length, 0)
})

test('an interaction beginning during a request prevents its application', async () => {
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve })
  const pending = controller.poll()
  controller.dirtyForms.add({})
  finish(reply(200, { version: 'b'.repeat(64), html: '<div></div>' }))
  await pending
  assert.equal(controller.versionValue, 'a'.repeat(64))
})

test('transient failures retry with a bounded delay', async () => {
  globalThis.fetch = async () => { throw new Error('offline') }
  await controller.poll()
  assert.equal([...timers.values()][0].delay, 30000)
  await controller.poll()
  await controller.poll()
  await controller.poll()
  assert.equal([...timers.values()][0].delay, 60000)
  assert.equal(controller.versionValue, 'a'.repeat(64))
})

test('a rendering race does not advance the version', async () => {
  globalThis.fetch = async () => reply(409)
  await controller.poll()
  assert.equal(controller.versionValue, 'a'.repeat(64))
  assert.equal(controller.failures, 0)
})

test('invalid JSON payloads do not advance the version', async () => {
  globalThis.fetch = async () => reply(200, { version: 'invalid', html: '<div></div>' })
  await controller.poll()
  assert.equal(controller.versionValue, 'a'.repeat(64))
  assert.equal(controller.failures, 1)
})

test('a missing record stops polling with a nonblocking notice', async () => {
  globalThis.fetch = async () => reply(404)
  await controller.poll()
  assert.equal(controller.stopped, true)
  assert.equal(timers.size, 0)
  assert.match(controller.statusTarget.textContent, /plus disponible/)
})

test('disconnect aborts requests and late responses cannot resume polling', async () => {
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve })
  const pending = controller.poll()
  const request = controller.request
  controller.disconnect()
  finish(reply(200, { version: 'b'.repeat(64), html: '<div></div>' }))
  await pending
  assert.equal(request.signal.aborted, true)
  assert.equal(timers.size, 0)
  assert.equal(controller.versionValue, 'a'.repeat(64))
})


test('a valid snapshot advances the version after region processing', async () => {
  globalThis.fetch = async () => reply(200, { version: 'b'.repeat(64), html: '<div></div>' })
  globalThis.DOMParser = class {
    parseFromString() { return { querySelector: () => ({ querySelectorAll: () => [] }) } }
  }
  await controller.poll()
  assert.equal(controller.versionValue, 'b'.repeat(64))
  assert.equal(controller.failures, 0)
})

test('an expired session stops without replacing the current page', async () => {
  globalThis.fetch = async () => reply(401)
  await controller.poll()
  assert.equal(controller.stopped, true)
  assert.match(controller.statusTarget.textContent, /reconnecte/)
})

test('hidden pending responses cannot apply and visibility resumes the loop', async () => {
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve })
  const pending = controller.poll()
  document.hidden = true
  document.dispatchEvent(new Event('visibilitychange'))
  finish(reply(200, { version: 'b'.repeat(64), html: '<div></div>' }))
  await pending
  assert.equal(controller.versionValue, 'a'.repeat(64))
  assert.equal(timers.size, 0)
  document.hidden = false
  document.dispatchEvent(new Event('visibilitychange'))
  assert.equal([...timers.values()][0].delay, 0)
})

test('Turbo cache entry stops the loop', async () => {
  document.dispatchEvent(new Event('turbo:before-cache'))
  await controller.poll()
  assert.equal(timers.size, 0)
  assert.equal(fetches.length, 0)
})


test('Turbo form submissions defer polling until completion', async () => {
  event('turbo:submit-start')
  await controller.poll()
  assert.equal(fetches.length, 0)
  event('turbo:submit-end')
  await controller.poll()
  assert.equal(fetches.length, 1)
})

test('a late response from a disconnected instance cannot interfere with reconnection', async () => {
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve })
  const pending = controller.poll()
  controller.disconnect()
  controller.connect()
  finish(reply(200, { version: 'b'.repeat(64), html: '<div></div>' }))
  await pending
  assert.equal(controller.versionValue, 'a'.repeat(64))
  assert.equal(timers.size, 1)
  assert.equal([...timers.values()][0].delay, 15000)
})


test('a late authentication error from an old connection does not stop the new loop', async () => {
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve })
  const pending = controller.poll()
  controller.disconnect()
  controller.connect()
  finish(reply(401))
  await pending
  assert.equal(controller.stopped, false)
  assert.equal(controller.statusTarget.textContent, '')
  assert.equal(timers.size, 1)
})


test('a response missing an existing region is rejected before changing the page', async () => {
  controller.element.querySelectorAll = () => [{ dataset: { recordLiveRegion: 'artwork' } }]
  globalThis.fetch = async () => reply(200, { version: 'b'.repeat(64), html: '<div></div>' })
  globalThis.DOMParser = class {
    parseFromString() { return { querySelector: () => ({ querySelectorAll: () => [] }) } }
  }
  await controller.poll()
  assert.equal(controller.versionValue, 'a'.repeat(64))
  assert.equal(controller.failures, 1)
})

test('changed regions restore disclosure, focus and scroll while unchanged regions are retained', () => {
  const detail = open => {
    const node = { open, closest: () => null, matches: name => name === 'details' }
    const summary = { textContent: 'Détails des copies', parentElement: node,
      matches: name => name === 'summary', focus: () => { summary.focused = true } }
    node.querySelector = () => summary
    return node
  }
  const oldDetail = detail(true), newDetail = detail(false)
  const oldTable = { id: 'copy-table', scrollLeft: 120, scrollTop: 6 }
  const newTable = { id: 'copy-table', scrollLeft: 0, scrollTop: 0 }
  const region = (name, html, disclosure, table) => ({
    dataset: { recordLiveRegion: name }, html, disclosure, table, replacements: 0,
    childNodes: [{ html, disclosure, table }],
    cloneNode() { return { innerHTML: this.html, querySelectorAll: () => [] } },
    contains(node) { return node === this.disclosure.querySelector('summary') },
    querySelectorAll(selector) {
      if (selector === 'details[open]') return this.disclosure.open ? [this.disclosure] : []
      if (selector === 'details') return [this.disclosure]
      if (selector === '.table-responsive' || selector === '[id]') return [this.table]
      return []
    },
    replaceChildren(payload) {
      this.replacements++
      this.html = payload.html; this.disclosure = payload.disclosure; this.table = payload.table
    }
  })
  const oldRegion = region('viewing', 'old content', oldDetail, oldTable)
  const freshRegion = region('viewing', 'new content', newDetail, newTable)
  const untouched = region('information', 'same content', detail(false), oldTable)
  const freshUntouched = region('information', 'same content', detail(false), newTable)
  const root = { ownerDocument: { activeElement: oldDetail.querySelector('summary') },
    querySelectorAll: () => [oldRegion, untouched] }
  const incoming = { querySelectorAll: () => [freshRegion, freshUntouched] }
  const viewport = { scrollX: 4, scrollY: 260, scrollTo(...values) { this.restored = values } }
  assert.equal(replaceRegions(root, incoming, viewport), true)
  assert.equal(oldRegion.replacements, 1)
  assert.equal(untouched.replacements, 0)
  assert.equal(newDetail.open, true)
  assert.equal(newDetail.querySelector('summary').focused, true)
  assert.equal(newTable.scrollLeft, 120)
  assert.equal(newTable.scrollTop, 6)
  assert.deepEqual(viewport.restored, [4, 260])
})
