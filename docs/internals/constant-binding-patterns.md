# Binding constants in pattern matching

Can Ruby grow a pattern form that defines constants, so Carton could write
`import('billing') => { Billing: }`? Research notes, checked against Ruby
4.0.7 (Prism 1.9.0) and the bug tracker.

## Summary

- Today the form is a SyntaxError in both parsers. Patterns bind only local
  variables; a bare constant in a pattern is a value pattern checked with
  `===`.
- No tracker issue asks for constant binding in patterns. Matz has rejected
  non-local pattern targets twice: instance variables in
  [#16372](https://bugs.ruby-lang.org/issues/16372) (2019) and
  [#18408](https://bugs.ruby-lang.org/issues/18408) (filed 2021), where he wrote
  "we will decide not to support anything but local variables".
- The grammar change is small. The semantics are not: `{ Billing: }` reads
  naturally as "match against `Billing`", by analogy with the hash literal
  `{ X: }`, which reads constant `X`.
- Chances upstream are low. Carton covers the common case with
  `export_default`, and plain constant assignment covers the rest.

## Current behavior on Ruby 4.0.7

```ruby
h => { Billing: }             # SyntaxError: key must be valid as local variables
h => { k: Integer => B }      # SyntaxError: expected an identifier after the `=>` operator
1 => Foo                      # NameError: Foo is a value pattern, evaluated then ===
{ Foo: 1 } => { Foo: Foo }    # matches if Foo === 1
{ Foo: 1 } => { Foo: foo }    # binds local foo; works today
X = 1; { X: }                 # => {X: 1}; the hash literal shorthand reads the constant
A, B = 1, 2                   # multiple assignment to constants works outside methods
def m; A, B = 1, 2; end       # SyntaxError: dynamic constant assignment
```

Both `--parser=prism` (default) and `--parser=parse.y` reject the key-only
form with the same message.

## 1. Tracker history

| Issue | Topic | Outcome |
| --- | --- | --- |
| [#14709](https://bugs.ruby-lang.org/issues/14709), [#14912](https://bugs.ruby-lang.org/issues/14912) | Original pattern matching design (ktsj) | Constants are value patterns: "pattern === object". Binding is for variables; constant binding never discussed. |
| [#16372](https://bugs.ruby-lang.org/issues/16372) | Bind instance variables in patterns | Rejected by Matz (#3): non-local targets "more complex and confusing". |
| [#15921](https://bugs.ruby-lang.org/issues/15921) | Rightward assignment `expr => x` (nobu, 2019) | Accepted (Matz: "I choose `=>`"), committed April 2020. Examples are all locals or attribute writers. |
| [#17260](https://bugs.ruby-lang.org/issues/17260) | Promote pattern matching for 3.0 | Plain rightward assignment dropped; `=>` became a one-line pattern match ([NEWS-3.0.0](https://github.com/ruby/ruby/blob/v4.0.7/doc/NEWS/NEWS-3.0.0.md#L42-L48)). nobu (#4) noted this "disallows assignments to other than local variables". |
| [#18408](https://bugs.ruby-lang.org/issues/18408) | `42 => @v` (Dan0042) | Rejected by Matz (#19): the limit "is intentional". ktsj and Eregon objected to side effects visible to other threads and to values left behind by failed matches. baweaver (#4) asked about "Globals, constants, class variables?" and sketched an import-like `Either => Left:, Right:`, calling it "a _very_ edge case". Nobody pursued it. |
| [#14579](https://bugs.ruby-lang.org/issues/14579) | `{ x: }` hash and keyword shorthand (shugo) | Rejected in 2018, accepted in 2021 for Ruby 3.1 ([NEWS-3.1.0](https://github.com/ruby/ruby/blob/v4.0.7/doc/NEWS/NEWS-3.1.0.md#L91-L97)). shugo (#23): "Note that constants are also allowed", e.g. `p(X:)`. The shorthand reads a constant, a local, or calls a method; it never binds. |
| [#10320](https://bugs.ruby-lang.org/issues/10320), [#19024](https://bugs.ruby-lang.org/issues/19024) | `require` into a module; "Import Modules" (shioyama) | #19024 closed 2023 without changing `require`. Examples bind imports with plain constant assignment (`AR = active_record::ActiveRecord`). No name-selection syntax proposed. |

No issue proposes constant binding in hash patterns, and none discusses
capitalized keys in patterns; the key restriction dates from the original
pattern matching implementation. Multiple assignment to constants
(`A, B = ...`) is long-standing, unremarkable syntax with no open debate.

## 2. Where the error comes from

### parse.y (ruby/ruby v4.0.7)

- [`p_kw`, L5726-L5742](https://github.com/ruby/ruby/blob/v4.0.7/parse.y#L5726-L5742):
  for a key with no sub-pattern, `if ($1 && !is_local_id($1)) yyerror1(...
  "key must be valid as local variables")`, then `assignable(p, $1, ...)`.
- [`assignable`, L13556-L13558](https://github.com/ruby/ruby/blob/v4.0.7/parse.y#L13556-L13558)
  already returns `NODE_CDECL` for an `ID_CONST` outside `def` and reports
  "dynamic constant assignment" inside one. Dropping the `is_local_id` check
  would therefore build a constant-assignment node.
- [`p_as`, L5473](https://github.com/ruby/ruby/blob/v4.0.7/parse.y#L5473) is
  `p_expr tASSOC p_variable`, and
  [`p_variable`, L5802](https://github.com/ruby/ruby/blob/v4.0.7/parse.y#L5802)
  accepts only `tIDENTIFIER`. A `tCONSTANT` after `=>` is not a target.
- [`p_const`, L5836](https://github.com/ruby/ruby/blob/v4.0.7/parse.y#L5836)
  makes `tCONSTANT`, `::C` and `A::B` value patterns.
- The one-line forms are
  [`arg tASSOC p_top_expr_body`, L3468](https://github.com/ruby/ruby/blob/v4.0.7/parse.y#L3468)
  (`=>`, raises) and the following `arg keyword_in` rule (returns a boolean).

### Prism

- Message: `PM_ERR_PATTERN_HASH_KEY_LOCALS` in
  [config.yml L239](https://github.com/ruby/prism/blob/v1.9.0/config.yml#L239)
  and
  [diagnostic.c.erb L321](https://github.com/ruby/prism/blob/v1.9.0/templates/src/diagnostic.c.erb#L321).
- Raised in
  [`parse_pattern_hash_implicit_value`, src/prism.c L16415-L16424](https://github.com/ruby/prism/blob/v1.9.0/src/prism.c#L16415-L16424)
  when `pm_slice_is_valid_local` fails. The function always creates a
  `LocalVariableTargetNode`. Same code in ruby/ruby at
  [prism/prism.c L16434-L16443](https://github.com/ruby/ruby/blob/v4.0.7/prism/prism.c#L16434-L16443).
- `=> name` in a pattern:
  [`expect1(..., PM_TOKEN_IDENTIFIER, PM_ERR_PATTERN_IDENT_AFTER_HROCKET)`, L16951](https://github.com/ruby/prism/blob/v1.9.0/src/prism.c#L16951).

### Compilers

- compile.c
  [`iseq_compile_pattern_each`](https://github.com/ruby/ruby/blob/v4.0.7/compile.c#L7290)
  treats `NODE_CONST`/`NODE_COLON2` as value patterns
  ([L7840](https://github.com/ruby/ruby/blob/v4.0.7/compile.c#L7840)),
  binds only `NODE_LASGN`/`NODE_DASGN`
  ([L7866](https://github.com/ruby/ruby/blob/v4.0.7/compile.c#L7866)), and
  fails on anything else
  ([L7981](https://github.com/ruby/ruby/blob/v4.0.7/compile.c#L7981)).
- prism_compile.c
  [`pm_compile_pattern`](https://github.com/ruby/ruby/blob/v4.0.7/prism_compile.c#L2559)
  binds `PM_LOCAL_VARIABLE_TARGET_NODE`
  ([L3034](https://github.com/ruby/ruby/blob/v4.0.7/prism_compile.c#L3034)),
  treats constant reads as values
  ([L3088](https://github.com/ruby/ruby/blob/v4.0.7/prism_compile.c#L3088)),
  and calls `rb_bug` on unknown nodes
  ([L3211-L3215](https://github.com/ruby/ruby/blob/v4.0.7/prism_compile.c#L3211-L3215)).
- Ordinary constant assignment compiles to `putspecialobject CONST_BASE;
  setconstant` ([compile.c L10504](https://github.com/ruby/ruby/blob/v4.0.7/compile.c#L10504)),
  i.e. the lexical cref.

### What a change touches

1. parse.y `p_kw` (and `p_variable` for `=> Const`), ripper events.
2. Prism: the implicit-value function, the `=>` target parser, probably reuse
   of `ConstantTargetNode` (already used for `A, B = ...`), new
   diagnostics, serialization, and the Ruby/Java/JS/Rust bindings that ship
   from ruby/prism.
3. Both compilers: a constant-target case in the pattern compiler, with the
   same "dynamic constant assignment" rule inside `def`.
4. `doc/syntax/pattern_matching.rdoc` and its grammar appendix.

## 3. Semantics a proposal must settle

- **Meaning of `{ Billing: }`.** In a hash literal `{ X: }` reads constant
  `X`. In a pattern, the parallel reading is `{ Billing: Billing }`, a value
  match, which already works. Making the shorthand *define* `Billing` gives
  the same token two opposite meanings depending on whether the constant
  exists or whether you are in a pattern. This is the strongest objection.
- **Explicit rename.** Hash patterns already rename locals with
  `{ Money: currency }`, but there the value position is a pattern, so
  `{ Money: Currency }` means "match `Currency === value`". A constant
  rename needs a new target form, e.g. `{ Money: _ => Currency }`, which
  requires `p_variable` to accept `tCONSTANT` and makes `=> Const` the only
  place where a constant after `=>` is written rather than read.
- **Which cref.** Constant assignment targets the lexical cref (the
  innermost `class`/`module` body, or `Object` at top level), not
  `self`'s class. Blocks passed to `module_eval` still use the lexical cref
  ([modules and classes, Constants](https://docs.ruby-lang.org/en/4.0/syntax/modules_and_classes_rdoc.html#label-Constants)).
  Inside `def` it must remain a SyntaxError.
- **Redefinition.** Ordinary reassignment warns "already initialized
  constant". A re-run import in the same cref would warn each time unless
  the proposal special-cases identical values.
- **Failed matches.** The docs leave bindings from an unmatched pattern
  undefined
  ([Appendix B](https://docs.ruby-lang.org/en/4.0/syntax/pattern_matching_rdoc.html#label-Appendix+B.+Some+undefined+behavior+examples)).
  For locals that is tolerable; a constant is visible to other threads and
  files, which is exactly why ktsj and Eregon opposed ivars in #18408. A
  proposal would need all-or-nothing assignment after the whole pattern
  matches.
- **`case/in` vs `=>`.** `case/in` and `expr in pat` try alternatives;
  defining constants from a branch that later fails, or from `in` used as a
  boolean, is a side effect in a conditional. Restricting constant targets
  to the top-level `=>` form would avoid that but adds a rule found nowhere
  else in patterns. Bindings inside alternatives (`[a] | [b]`) are already rejected.
- **Hooks.** Each constant would fire
  [`Module#const_added`](https://docs.ruby-lang.org/en/4.0/Module.html#method-i-const_added)
  (Ruby 3.2, [NEWS](https://github.com/ruby/ruby/blob/v4.0.7/doc/NEWS/NEWS-3.2.0.md#L233)),
  as `A, B = ...` does, mid-pattern unless assignment is deferred.

## 4. Prior art

- **ECMAScript**: `import { a as b } from "m"`
  ([ImportSpecifier](https://tc39.es/ecma262/multipage/ecmascript-language-scripts-and-modules.html#prod-ImportSpecifier)).
  Import bindings are "immutable indirect" bindings
  ([CreateImportBinding](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-createimportbinding)),
  and an unresolvable name throws `SyntaxError` at link time
  ([InitializeEnvironment](https://tc39.es/ecma262/multipage/ecmascript-language-scripts-and-modules.html#sec-source-text-module-record-initialize-environment)).
  It is a dedicated declaration, not destructuring; object destructuring
  (`const { a: b } = obj`) is the separate, run-time form.
- **Python**: `from m import y as z` stores the attribute in the current
  namespace and raises `ImportError` if it is missing
  ([the import statement](https://docs.python.org/3/reference/simple_stmts.html#the-import-statement)).
- **Elixir**: `alias Foo.{Bar, Baz}` and `alias Foo.Bar, as: Baz` are
  lexically scoped special forms
  ([alias/2](https://elixir.hexdocs.pm/Kernel.SpecialForms.html#alias/2)).
  Capitalized names in Elixir patterns are atoms, never bindings.
- **Rust**: `use a::{b, c as d};`
  ([use declarations](https://doc.rust-lang.org/reference/items/use-declarations.html)).

Every one of these is a dedicated import declaration. None reuses its
pattern or destructuring syntax to bind module-level names.

## 5. A minimal upstream proposal

- **Motivation**: module systems built on `Ruby::Box` return export
  namespaces; selecting constants needs a repeated name
  (`Billing = import('billing')::Billing`).
- **Syntax**: allow `tCONSTANT` as a key-only hash pattern key and as the
  target of `=>` in patterns.
- **Compatibility**: both forms are SyntaxErrors in parse.y and Prism today,
  so no valid program changes meaning.
- **Semantics**: assign to the lexical cref; SyntaxError inside `def`;
  assign only after the whole pattern matches; allowed only in top-level
  `expr => pattern`, or also in `case/in` with the above deferral.

**Assessment: unlikely.** Matz's stated line is local variables only
(#16372, #18408), and constants are more global than ivars. The shorthand
also conflicts with the established reading of `{ X: }` as a constant
reference and of bare constants in patterns as value checks. The motivating
use is a single library's API, which Ruby can already express with
`Billing = ...`. A proposal would at best be told to use assignment.

## 6. Relation to Carton

Carton briefly had name selection (`Money, Tax = import 'pricing', :Money,
:Tax`), designed to map 1:1 onto this pattern form. Given the low odds
above, it was dropped in favour of a smaller API that already reads well:

```ruby
Billing = import 'billing'                 # a Carton whose Entrypoint calls export_default Billing
Pricing = import 'pricing'                 # a namespace of named exports
Money = import('pricing')::Money           # one constant from a namespace
import('math') => { add:, PI: pi }         # locals via patterns, including capitalized keys
```

Ordinary constant assignment already gives the cref, the `def`
restriction, redefinition warnings, and `const_added` behavior that a
pattern proposal would have to specify.

## Sources

- Ruby tracker: [#14579](https://bugs.ruby-lang.org/issues/14579),
  [#14709](https://bugs.ruby-lang.org/issues/14709),
  [#14912](https://bugs.ruby-lang.org/issues/14912),
  [#15921](https://bugs.ruby-lang.org/issues/15921),
  [#16372](https://bugs.ruby-lang.org/issues/16372),
  [#17260](https://bugs.ruby-lang.org/issues/17260),
  [#18408](https://bugs.ruby-lang.org/issues/18408),
  [#10320](https://bugs.ruby-lang.org/issues/10320),
  [#19024](https://bugs.ruby-lang.org/issues/19024)
- ruby/ruby v4.0.7: [parse.y](https://github.com/ruby/ruby/blob/v4.0.7/parse.y),
  [compile.c](https://github.com/ruby/ruby/blob/v4.0.7/compile.c),
  [prism_compile.c](https://github.com/ruby/ruby/blob/v4.0.7/prism_compile.c),
  [prism/prism.c](https://github.com/ruby/ruby/blob/v4.0.7/prism/prism.c),
  NEWS [3.0.0](https://github.com/ruby/ruby/blob/v4.0.7/doc/NEWS/NEWS-3.0.0.md),
  [3.1.0](https://github.com/ruby/ruby/blob/v4.0.7/doc/NEWS/NEWS-3.1.0.md),
  [3.2.0](https://github.com/ruby/ruby/blob/v4.0.7/doc/NEWS/NEWS-3.2.0.md)
- ruby/prism v1.9.0: [src/prism.c](https://github.com/ruby/prism/blob/v1.9.0/src/prism.c),
  [config.yml](https://github.com/ruby/prism/blob/v1.9.0/config.yml)
- Ruby docs: [pattern matching](https://docs.ruby-lang.org/en/4.0/syntax/pattern_matching_rdoc.html),
  [modules and classes](https://docs.ruby-lang.org/en/4.0/syntax/modules_and_classes_rdoc.html),
  [Module#const_added](https://docs.ruby-lang.org/en/4.0/Module.html#method-i-const_added)
- Other languages: [ECMA-262 modules](https://tc39.es/ecma262/multipage/ecmascript-language-scripts-and-modules.html),
  [Python import](https://docs.python.org/3/reference/simple_stmts.html#the-import-statement),
  [Elixir alias/2](https://elixir.hexdocs.pm/Kernel.SpecialForms.html#alias/2),
  [Rust use](https://doc.rust-lang.org/reference/items/use-declarations.html)
