# Carton

Carton is a package system for Ruby: a small import and export language for gem-sized and domain-sized units of Ruby code, with boundaries Ruby enforces at runtime.

## Language

### Cartons

**Carton**: An importable unit of Ruby code, gem-sized or domain-sized, with an Interior and a Public Surface: an Entrypoint plus the directory named after it. _Avoid_: Package, pack, unit, component, box, plain carton, unbundled carton

**Entrypoint**: The file an Import loads to establish a Carton boundary, such as `billing.rb`. A file with no directory beside it is a Carton of one file. _Avoid_: Manifest, index file, main file

**Interior**: The files under the directory beside a Carton's Entrypoint, such as `billing/invoice.rb`, including implicit-namespace subdirectories. They cannot be imported; the outermost Entrypoint above them owns them. A Carton may nest inside another Carton's tree, but not inside its Interior. _Avoid_: Internals, private files, namespace directory

**Gem-shaped Directory**: A directory such as `billing/` holding `lib/billing.rb`, which an Import of the directory resolves to as the Entrypoint. _Avoid_: Package directory, component directory

### Boxes

**Box**: A Ruby execution environment with isolated loading and definitions. Every Carton runs in its own Carton Box; the top-level application runs in the Main Box. _Avoid_: Carton instance, runtime carton, sandbox

**Root Box**: Ruby's internal Box for bootstrap and builtin code. Carton never runs code in it. _Avoid_: Main Box, Master Box

**Master Box**: Ruby's internal Box that every new Box is copied from. Carton never writes to it. _Avoid_: Template box, root box

**Main Box**: The Box in which the top-level application runs and imports Cartons. It is not itself a Carton. _Avoid_: Root Box, root carton, main carton, app box

**Optional Box**: Ruby's name for any Box created with `Ruby::Box.new`, separate from the Main Box. _Avoid_: Child box, sub-box

**Carton Box**: The Optional Box Carton creates for a Carton's first Import, where the Carton's code and gems load. Importers never receive it. _Avoid_: Child box, Import box

### Importing

**Import**: Loading a Carton into its Carton Box and receiving its Export or Namespace. Only an Import crosses a Carton boundary; code loaded without one remains inside the current Carton. _Avoid_: Require, load

**Importer**: The code that runs an Import: the application in the Main Box, or another Carton. _Avoid_: Caller, parent

**First Importer**: The Importer whose Import loads a Carton. It fixes the Carton's gem versions for the whole process. _Avoid_: Owner

**Shared Import**: An Import of a Carton already loaded in the process. It returns the same Export or Namespace as the First Importer received, so every Importer shares one Carton. _Avoid_: Cached carton, singleton carton

**Imported Carton**: A Carton an Importer imports directly. It remains a separate boundary and exposes only its Public Surface. _Avoid_: Child carton, nested carton, dependency

**Transitive Carton**: A Carton reached indirectly through an Imported Carton. _Avoid_: Imported carton when the relationship is indirect

**Second Copy**: A Carton's code loaded outside its boundary by a plain `require` of its Entrypoint or Interior. Its classes are separate objects from the Imported Carton's. _Avoid_: Duplicate load, reach-in

**Dynamic Import**: An Import whose path is computed at runtime, so static tools cannot follow it. _Avoid_: Runtime import, unchecked import

### Exporting

**Export**: The one value a Carton's Entrypoint gives `export`, returned as is when the Carton is imported: usually its root module, or a Hash from keywords. Calls in any other file, including files loaded by plain `require`, declare nothing. A Bare Carton has none. _Avoid_: Default export, named exports, export declaration

**Public Surface**: Everything a Carton deliberately makes reachable across its boundary: its Export or Namespace, and what those expose. _Avoid_: API, public API, exports

**Bare Carton**: A Carton whose Entrypoint never calls `export`. The constants and Helpers its Entrypoint defines are its Public Surface, returned as a Namespace. _Avoid_: Unexported carton, script carton

**Helper**: A top-level method a Bare Carton's Entrypoint defines, callable through its Namespace. _Avoid_: Function, Bare Carton method

**Namespace**: The `Carton::Namespace` module a Bare Carton's Importers receive, holding its constants and Helpers. _Avoid_: Exports, export namespace

### Gems and bundles

**Gem Carton**: A Carton whose Entrypoint belongs to a gem the Importer has activated, such as a path gem in the app's Gemfile. Its Carton Box gets the gem's Gem Closure at the Importer's versions. _Avoid_: Gem package

**Gem Closure**: The gem that owns a Gem Carton's Entrypoint plus the runtime dependencies the Importer has activated for it, transitively. _Avoid_: Dependency closure, dependency tree

**Carton Bundle**: A bundle a Carton sets up in its own Carton Box from its own Gemfile, separate from its Importer's. _Avoid_: Nested bundle, sub-bundle

**Undeclared Gem**: A gem a Gem Carton loads that its gemspec does not declare as a runtime dependency. It loads under a bundled Importer but fails wherever the gem is not installed. _Avoid_: Implicit dependency, transitive leak
