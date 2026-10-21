// Every declaration in sig/carton.rbs has an entry in the API reference, with
// the same text and visibility, and the reference documents nothing else.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../../', import.meta.url);
const reference = new URL('website/src/content/docs/reference/', root);

const squish = (text) => text.replace(/\s+/g, ' ').trim();

// Each module or class header, and each member with its owner. A member's
// overloads are the lines after it that start with `|`.
export function declarations(rbs) {
  const found = [];
  let owner = null;
  let isPrivate = false;
  for (const line of rbs.split('\n')) {
    const text = line.trim();
    if (!text || text.startsWith('#')) continue;
    const header = text.match(/^(?:module|class) ([\w:]+)/);
    if (header) {
      owner = header[1];
      isPrivate = false;
      found.push({ owner, rbs: text, private: false });
    } else if (text === 'end') {
      owner = null;
    } else if (text === 'private') {
      isPrivate = true;
    } else if (text.startsWith('|')) {
      found.at(-1).rbs += ` ${text}`;
    } else {
      found.push({ owner, rbs: text, private: isPrivate });
    }
  }
  return found.map((d) => ({ ...d, rbs: squish(d.rbs) }));
}

// Every <Signature> on the reference pages, in either quoting style.
export function signatures(mdx) {
  const tag = /<Signature\s+owner="([^"]+)"(\s+private)?\s+rbs=(?:"([^"]*)"|\{`([^`]*)`\})/g;
  return [...mdx.matchAll(tag)].map(([, owner, isPrivate, quoted, template]) => ({
    owner,
    rbs: squish(quoted ?? template),
    private: Boolean(isPrivate),
  }));
}

const key = (d) => `${d.owner}: ${d.private ? 'private ' : ''}${d.rbs}`;

test('the API reference documents exactly what sig/carton.rbs declares', () => {
  const declared = declarations(readFileSync(new URL('sig/carton.rbs', root), 'utf8')).map(key);
  const documented = readdirSync(reference)
    .filter((name) => name.endsWith('.mdx'))
    .flatMap((name) => signatures(readFileSync(new URL(name, reference), 'utf8')))
    .map(key);

  assert.deepEqual(
    declared.filter((d) => !documented.includes(d)),
    [],
    'declared in sig/carton.rbs but missing from the reference',
  );
  assert.deepEqual(
    documented.filter((d) => !declared.includes(d)),
    [],
    'in the reference but not declared in sig/carton.rbs',
  );
  assert.deepEqual(
    documented.filter((d, i) => documented.indexOf(d) !== i),
    [],
    'documented more than once',
  );
});

test('declarations reads owners, visibility, and overloads', () => {
  const rbs = `module Kernel
  private

  def import: (::String path) -> untyped
end

module M
  # a comment
  def f: () -> untyped
       | (::Integer) -> untyped
end`;
  assert.deepEqual(declarations(rbs), [
    { owner: 'Kernel', rbs: 'module Kernel', private: false },
    { owner: 'Kernel', rbs: 'def import: (::String path) -> untyped', private: true },
    { owner: 'M', rbs: 'module M', private: false },
    { owner: 'M', rbs: 'def f: () -> untyped | (::Integer) -> untyped', private: false },
  ]);
});
