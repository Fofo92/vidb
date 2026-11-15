import test, { beforeEach, afterEach } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs/promises'

async function controller(name) {
  const source = await fs.readFile(new URL(`../../app/javascript/controllers/${name}_controller.js`, import.meta.url), 'utf8')
  return (await import('data:text/javascript;base64,' + Buffer.from(
    source.replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
  ).toString('base64'))).default
}
const LiveSearch = await controller('record_live_search')
const SearchMenu = await controller('record_search_menu')
const original = { setTimeout: globalThis.setTimeout, clearTimeout: globalThis.clearTimeout }
let timers, live, submissions, input, submit

beforeEach(() => {
  timers = new Map()
  submissions = []
  globalThis.setTimeout = (callback, delay) => { const id = Symbol(); timers.set(id, { callback, delay }); return id }
  globalThis.clearTimeout = id => timers.delete(id)
  input = { value: '', selectionStart: 0, selectionEnd: 0 }
  submit = { auto: true, disabled: true }
  live = Object.assign(new LiveSearch(), {
    element: { isConnected: true, requestSubmit(button) { submissions.push({ button, value: input.value }) } },
    inputTarget: input, submitTarget: submit, statusTarget: { textContent: '', classList: { toggle() {} } },
    delayValue: 300, frameValue: 'record_search_results'
  })
  live.connect()
})

afterEach(() => {
  live.disconnect()
  Object.assign(globalThis, original)
})

function flush() {
  const callbacks = [...timers.values()]
  timers.clear()
  callbacks.forEach(timer => timer.callback())
}

test('a burst of characters produces one GET submission with the latest text and leaves the input in place', () => {
  for (const value of ['F', 'Fu', 'Fury']) {
    input.value = value
    input.selectionStart = input.selectionEnd = value.length
    live.queue({ target: input })
  }
  assert.equal(timers.size, 1)
  assert.equal([...timers.values()][0].delay, 300)
  assert.equal(submissions.length, 0)
  flush()
  assert.deepEqual(submissions, [{ button: submit, value: 'Fury' }])
  assert.equal(submit.disabled, false)
  assert.equal(live.inputTarget, input)
  assert.equal(input.selectionStart, 4)
})

test('composition does not submit an unfinished accented or IME character', () => {
  live.compositionStarted()
  input.value = 'é'
  live.queue({ target: input, isComposing: true })
  assert.equal(timers.size, 0)
  live.compositionEnded({ target: input })
  flush()
  assert.equal(submissions.length, 1)
  assert.equal(submissions[0].value, 'é')
})

test('clearing the field also updates results but unrelated inputs do not start a search', () => {
  input.value = ''
  live.queue({ target: { value: 'other field' } })
  assert.equal(timers.size, 0)
  live.queue({ target: input })
  flush()
  assert.equal(submissions[0].value, '')
})

test('leaving the page or submitting manually cancels the outstanding timer', () => {
  live.queue({ target: input })
  live.submitted()
  assert.equal(timers.size, 0)
  live.queue({ target: input })
  live.disconnect()
  flush()
  assert.equal(submissions.length, 0)
})

test('only the matching results frame updates creation and global search links', () => {
  const create = { href: '/records/new' }
  const attributes = {}
  const menu = { setAttribute(key, value) { attributes[key] = value } }
  live.element.ownerDocument = { querySelector: selector => selector === '[data-record-new-link]' ? create : menu }
  const context = { dataset: { newRecordUrl: '/records/new?search_context=signed', searchMenuUrl: '/record_search?q=Fury' } }
  const target = { id: 'other', querySelector: () => context }
  live.rendered({ target })
  assert.equal(create.href, '/records/new')
  target.id = live.frameValue
  live.rendered({ target })
  assert.equal(create.href, context.dataset.newRecordUrl)
  assert.equal(attributes['data-record-search-menu-url-value'], context.dataset.searchMenuUrl)
  assert.equal(live.statusTarget.textContent, 'Résultats actualisés.')
})

test('a failed request leaves an explicit message without touching the input', () => {
  input.value = 'Fury'
  live.failed({ target: live.element })
  assert.match(live.statusTarget.textContent, /indisponible/)
  assert.equal(input.value, 'Fury')
})

test('the closed global menu retains the new URL without loading old results', () => {
  const attributes = { src: '/record_search?q=old' }
  let loads = 0
  const frame = {
    getAttribute: key => attributes[key],
    removeAttribute(key) { delete attributes[key] },
    set src(value) { attributes.src = value; loads++ }
  }
  const menu = Object.assign(new SearchMenu(), {
    element: { open: false }, hasFrameTarget: true, frameTarget: frame, urlValue: '/record_search?q=new'
  })
  menu.urlValueChanged()
  assert.equal(loads, 0)
  assert.equal(attributes.src, undefined)
  menu.element.open = true
  menu.toggle()
  assert.equal(loads, 1)
  assert.equal(attributes.src, menu.urlValue)
  menu.toggle()
  assert.equal(loads, 1)
})
