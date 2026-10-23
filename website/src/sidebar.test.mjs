import assert from 'node:assert/strict';
import test from 'node:test';
import { parseHTML } from 'linkedom';
import { initSidebar } from './sidebar.mjs';

function fixture() {
  const { document } = parseHTML(`
    <main><h1>Importing</h1><a id="anchor" href="#imports">Imports</a></main>
    <carton-sidebar>
      <nav class="section-tabs" hidden>
        <button aria-controls="guides" aria-pressed="true">Guides</button>
        <button aria-controls="reference" aria-pressed="false">Reference</button>
      </nav>
      <section id="guides"><h2 data-section-heading>Guides</h2><details open><summary>Start here</summary><a href="/guides/getting-started/">Getting started</a></details><details open><summary>Concepts</summary><a href="/guides/importing/" aria-current="page">Importing</a></details></section>
      <section id="reference"><h2 data-section-heading>Reference</h2><a href="/reference/carton/">Carton</a></section>
    </carton-sidebar>
  `);
  const root = document.querySelector('carton-sidebar');
  initSidebar(root);
  return { document, root, buttons: [...root.querySelectorAll('button')] };
}

test('initially shows the current document section', () => {
  const { root, buttons } = fixture();
  assert.equal(root.querySelector('.section-tabs').hidden, false);
  assert.deepEqual(buttons.map((button) => button.getAttribute('aria-pressed')), ['true', 'false']);
  assert.deepEqual([...root.querySelectorAll('section')].map((panel) => panel.hidden), [false, true]);
});

test('section switches preserve the document, current page link, and expanded tree', () => {
  const { document, root, buttons } = fixture();
  const content = document.querySelector('main');
  const before = content.outerHTML;
  const current = root.querySelector('[aria-current="page"]');
  const concepts = root.querySelector('#guides details:last-of-type');
  concepts.removeAttribute('open');

  for (const index of [1, 0, 0]) {
    buttons[index].click();
    assert.deepEqual(buttons.map((button) => button.getAttribute('aria-pressed')), buttons.map((_, i) => String(i === index)));
    assert.deepEqual([...root.querySelectorAll('section')].map((panel) => panel.hidden), buttons.map((_, i) => i !== index));
    assert.equal(document.querySelector('main'), content);
    assert.equal(content.outerHTML, before);
    assert.equal(root.querySelector('[aria-current="page"]'), current);
    assert.equal(concepts.hasAttribute('open'), false);
  }
});
