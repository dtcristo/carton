import assert from 'node:assert/strict';
import { test } from 'node:test';
import { exampleCode } from './example-code.mjs';

const carton = '/project/lib/carton.rb';

test('shows the installed gem load while preserving the rest of an example', () => {
  const source = `# frozen_string_literal: true

# Load Carton before importing Billing.
require_relative '../../lib/carton' # the checkout runtime
require_relative 'adapters'

Billing = import_relative 'billing'
text = <<~RUBY
require_relative '../../lib/carton'
RUBY
`;
  assert.equal(exampleCode(source, { file: '/project/examples/minimal/main.rb', carton }), `# Load Carton before importing Billing.
require 'carton' # the checkout runtime
require_relative 'adapters'

Billing = import_relative 'billing'
text = <<~RUBY
require_relative '../../lib/carton'
RUBY`);
});

test('recognizes the checkout runtime from nested files and explicit Ruby extensions', () => {
  assert.equal(exampleCode(`require 'minitest/autorun'
require_relative "../../../lib/carton.rb"`, {
    file: '/project/examples/dependency_injection/test/helper.rb', carton,
  }), `require 'minitest/autorun'
require 'carton'`);
  assert.equal(exampleCode("require_relative '../../../../../lib/carton'", {
    file: '/project/examples/rails/cartons/shop/config/boot.rb', carton,
  }), "require 'carton'");
});

test('leaves other files, comments, and string contents alone', () => {
  const file = '/project/examples/minimal/main.rb';
  for (const source of [
    "require_relative 'adapters'",
    "require_relative '../lib/carton'",
    "require_relative '../../lib/carton/version'",
    "# require_relative '../../lib/carton'",
    `text = "require_relative '../../lib/carton'"`,
    `text = <<~RUBY\nrequire_relative '../../lib/carton'\nRUBY`,
    "require 'carton'",
  ]) {
    assert.equal(exampleCode(source, { file, carton }), source);
  }
});
