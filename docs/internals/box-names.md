# Box names

Carton's Box names follow upstream Ruby's. This page records Ruby's terms, where they come from, and the one name Carton adds.

## Ruby's terms

`doc/language/box.md` names three kinds of Box ([v4.0.7](https://github.com/ruby/ruby/blob/v4.0.7/doc/language/box.md#ruby-box-types)):

- The **master box** is "the 'master copy' of all boxes". Every Box is created as a copy of it, and "no code runs in the master box".
- The **root box** is "just a single box in a Ruby process". Ruby bootstrap runs there, and "all builtin classes/modules are defined and run in the root box".
- **User boxes** "run user-written programs and libraries". The **main box** is the user box where "the user's main program (specified by the `ruby` command line argument)" runs, and `-r` files load there too. `Ruby::Box.new` creates an **optional box**, "a user, non-main box, technically equal to the main box".

`box.c` uses the same split. `Ruby::Box#inspect` labels each Box with these words, and `internal/box.h` defines a main box as a user box that is not optional ([v4.0.7](https://github.com/ruby/ruby/blob/v4.0.7/internal/box.h)). On Ruby 4.0.7:

```text
Ruby::Box.master # => #<Ruby::Box:1,master>
Ruby::Box.root   # => #<Ruby::Box:2,root>
Ruby::Box.main   # => #<Ruby::Box:3,user,main>
Ruby::Box.new    # => #<Ruby::Box:4,user,optional>
```

With `RUBY_BOX=1`, Ruby defines `Ruby::Box.master`, `.root`, and `.main`, and `#master?`, `#root?`, and `#main?` ([v4.0.7 box.c](https://github.com/ruby/ruby/blob/v4.0.7/box.c)). It defines no `user?` or `optional?`.

## How the names were chosen

- **Box, not Namespace.** The feature was called Namespace while it was developed. [Misc #21385](https://bugs.ruby-lang.org/issues/21385) renamed it, because classes and modules already are Ruby's namespaces.
- **Master, not source.** [Bug #21881](https://bugs.ruby-lang.org/issues/21881) split the copy source out of the root box. Its first proposal renamed root to "source" and the bootstrap Box to root, and then kept "root" for the bootstrap Box "because the name and idea of the root box is known by Ruby users". The copy source became "master" (master copy), since "the word 'source' is used everywhere both in CRuby and Ruby code". The [change](https://github.com/ruby/ruby/commit/276f0d9b3efbabe46e74510e5e3585924b37772c) first shipped in Ruby 4.0.6.

## Carton's names

Carton capitalizes Ruby's terms as glossary terms: Master Box, Root Box, User Box, Main Box, and Optional Box. It adds one more:

- A **Carton Box** is the Optional Box Carton creates for a Carton's first Import. Ruby has no word for a Box a library creates, and Carton needs one to tell its own Boxes from Boxes other code creates with `Ruby::Box.new`.

Carton avoids these names:

- **Root Box for the Main Box.** Upstream keeps "root" for bootstrap and builtin code, so the application that imports Cartons runs in the Main Box.
- **Template Box for the Master Box.** A Template Box is the support Carton asks Ruby for ([dtcristo/carton#25](https://github.com/dtcristo/carton/issues/25)): a Box that other Boxes start from, carrying a shared baseline such as Active Support's core extensions. Master is Ruby's internal copy source, which apps are not meant to write.
- **`main` for the Main Box.** Ruby's top-level receiver named `main` is an object inside the Main Box, not another Box.

## Ruby 4.0 version split

Ruby 4.0.0 through 4.0.5 and Ruby 4.0.6 do not have the same copy source.

### Ruby 4.0.0-4.0.5

The Main Box is created after the prelude. Both it and later Optional Boxes copy the Root Box. Therefore a Root Box load-path mutation is inherited by a later `Ruby::Box.new`; a Main Box mutation is not.

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

Ruby added the Master Box as the copy source. Root, Main, and Optional Boxes copy Master; Root and Main are initialized before the prelude and load prelude state in their own environments. Ruby intends no code to run in Master, though on 4.0.7 it can; see [how-boxes-work.md](how-boxes-work.md#the-master-box-on-ruby-407).

This was explicitly intended to stop Box contents depending on when a Box was created. It does not change which Box owns the user's main program: Main Box.

Sources:

- [change introducing Master Box](https://github.com/ruby/ruby/commit/276f0d9b3efbabe46e74510e5e3585924b37772c)
- [Ruby 4.0.6 optional-box initialization](https://github.com/ruby/ruby/blob/v4.0.6/box.c#L157-L185)
- [Ruby 4.0.6 Root/Main initialization](https://github.com/ruby/ruby/blob/v4.0.6/box.c#L961-L989)
- [Ruby 4.0.6 boot order](https://github.com/ruby/ruby/blob/v4.0.6/ruby.c#L1846-L1879)
- [Ruby 4.0.6 main-program tests](https://github.com/ruby/ruby/blob/v4.0.6/test/ruby/test_box.rb#L44-L49), which assert that the main program's current Box is `Ruby::Box.main`

### Ruby 4.0.7

The copy model is unchanged. The gem prelude now skips `ENV["BUNDLER_SETUP"]` outside Main Box, so creating an Optional Box under `bundle exec` no longer runs Bundler setup in it. See [Bug #22123](https://bugs.ruby-lang.org/issues/22123) and [the commit](https://github.com/ruby/ruby/commit/e9bccf88c1).

## Stale upstream docs

On v4.0.7 and master:

- `doc/language/box.md` still says Main is "created at the end of Ruby's bootstrap". That describes 4.0.5; for boot-order and inheritance claims, the tagged source is authoritative.
- The same section opens with an unfinished sentence, "Ruby bootstrap runs in the root box, and a".
- The `Ruby::Box` class docs list only `current`, `enabled?`, and `new` as class methods, not `master`, `root`, or `main`, since Ruby defines those only when Boxes are enabled.

Fixing these is listed in [upstream.md](upstream.md).
