// Which parts of a line of Ruby the code-block plugin restyles.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { marks } from './expressive-code.mjs';

const keys = (text) => marks(text).map((m) => `${m.key}@${m.start}`);

test('colours Carton calls outside strings and comments', () => {
  assert.deepEqual(keys(`Billing = import_relative 'billing' # runs it`), ['call@10']);
  assert.deepEqual(keys(`export User # importers receive User itself`), ['call@0']);
  assert.deepEqual(keys(`x = "= import foo"`), []);
});

test('marks a trailing result or raised error', () => {
  assert.deepEqual(keys(`Billing.invoice(100) # => 110.0`), ['result@21']);
  assert.deepEqual(keys(`Tax                  # NameError`), ['error@21']);
  assert.deepEqual(keys(`Pricing::Internal   # NameError: private constant`), ['error@20']);
});

test('ignores a # inside a string', () => {
  assert.deepEqual(keys(`puts "# => literal"`), []);
  assert.deepEqual(keys(`puts "# NameError"`), []);
  assert.deepEqual(keys(`puts "it's #{x}" # => nil`), ['result@17']);
});
