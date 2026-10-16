# Root Box vs Main Box

## Finding

Use **Main Box** for the top-level application's Ruby environment.

- The **Root Box** is Ruby's bootstrap/builtin-code environment
- The **Main Box** is the user box in which the command-line program runs
- `Ruby::Box.current == Ruby::Box.main` in ordinary top-level user code
- Ruby's top-level receiver named `main` is an object inside that environment; it is not another box

Ruby exposes both terms deliberately through `Ruby::Box.root` and
`Ruby::Box.main`. The Ruby 4.0 docs assign the user's main program and `-r`
loads to the Main Box, while the tests assert that the current box in the main
program is `Ruby::Box.main`.

Sources:

- [Ruby 4.0.6 box documentation](https://github.com/ruby/ruby/blob/v4.0.6/doc/language/box.md#L69-L85)
- [Ruby 4.0.6 command-line `-r` loading](https://github.com/ruby/ruby/blob/v4.0.6/ruby.c#L801-L818)
- [Ruby 4.0.6 main-program tests](https://github.com/ruby/ruby/blob/v4.0.6/test/ruby/test_box.rb#L44-L49)

## Important Ruby 4.0 version split

Ruby 4.0.0 through 4.0.5 and Ruby 4.0.6 do not have the same copy source.

### Ruby 4.0.0-4.0.5

The Main Box is created after the prelude. Both it and later optional boxes copy
the Root Box. Therefore a Root Box load-path mutation is inherited by a later
`Ruby::Box.new`; a Main Box mutation is not.

This matches the installed Ruby 4.0.5 probe:

```text
root path inherited: true
main path inherited: false
```

Sources:

- [Ruby 4.0.5 box model](https://github.com/ruby/ruby/blob/v4.0.5/doc/language/box.md#L69-L80)
- [Ruby 4.0.5 optional-box initialization](https://github.com/ruby/ruby/blob/v4.0.5/box.c#L130-L153)
- [Ruby 4.0.5 boot order](https://github.com/ruby/ruby/blob/v4.0.5/ruby.c#L1829-L1835)

### Ruby 4.0.6

Ruby added an internal **Master Box** as the immutable copy source. Root, Main,
and optional boxes copy Master; Root and Main are initialized before the prelude
and load prelude state in their own environments. Master runs no code.

This was explicitly intended to stop box contents depending on when a box was
created. It does not change which box owns the user's main program: Main Box.

Sources:

- [change introducing Master Box](https://github.com/ruby/ruby/commit/276f0d9b3efbabe46e74510e5e3585924b37772c)
- [Ruby 4.0.6 optional-box initialization](https://github.com/ruby/ruby/blob/v4.0.6/box.c#L157-L185)
- [Ruby 4.0.6 Root/Main initialization](https://github.com/ruby/ruby/blob/v4.0.6/box.c#L961-L989)
- [Ruby 4.0.6 boot order](https://github.com/ruby/ruby/blob/v4.0.6/ruby.c#L1846-L1879)

The generated Ruby 4.0 prose still says Main is created at bootstrap's end,
which reflects the older implementation. For boot-order and inheritance claims,
the tagged source is authoritative.

## Carton terminology

Define **Main Box** as the host environment that imports Cartons. Do not call it
the Root Box: upstream Ruby reserves that term for bootstrap and builtin code.
This recommendation survives the 4.0.5-to-4.0.6 implementation change.

Carton targets Ruby 4.0.6 or later. Its technical docs therefore use Master as
the copy source, Root for bootstrap/builtins, Main for the top-level
application, and optional Boxes for imported Cartons.
