# Carton

Carton is a package system for Ruby: a small import and export language for gem-sized and domain-sized units of Ruby code, with boundaries Ruby enforces at runtime.

## Language

**Carton**:
An importable unit of Ruby code, gem-sized or domain-sized, with an isolated interior and a public surface: an Entrypoint plus the directory named after it.
_Avoid_: Package when naming the domain concept, box, plain carton, unbundled carton

**Entrypoint**:
The file an Import loads to establish a Carton boundary, such as `billing.rb`. Files under the `billing/` directory beside it, including implicit-namespace subdirectories, are inside the Carton and cannot be imported themselves. A file with no such directory is a Carton of one file. A Carton may nest inside another Carton's tree, but not inside its namespace directory.
_Avoid_: Manifest, package directory

**Box**:
A Ruby execution environment with isolated loading and definitions. Cartons run in optional Boxes; the top-level application runs in the Main Box.
_Avoid_: Carton instance, runtime carton

**Main Box**:
The user Box in which the top-level application runs and imports Cartons. It is not itself a Carton.
_Avoid_: Root Box, root carton, main carton

**Optional Box**:
A user Box created for an Import and hosting one Carton. It is separate from the Main Box.
_Avoid_: Carton box, child box

**Master Box**:
Ruby's internal Box that every new Box is copied from. Carton never writes to it.
_Avoid_: Template box, root box

**Import**:
Loading a Carton into a Box and receiving its public surface. Only an Import crosses a Carton boundary; code loaded without one remains inside the current Carton.
_Avoid_: Require

**Shared Import**:
An Import of a Carton already loaded in the process. It returns the same public surface as the first Import of that Entrypoint, whichever Box asked first.
_Avoid_: Cached carton, singleton carton

**Imported Carton**:
A Carton imported directly by another Carton. It remains a separate boundary and exposes only its public surface to the importer.
_Avoid_: Child carton, nested carton

**Transitive Carton**:
A Carton reached indirectly through an Imported Carton.
_Avoid_: Imported carton when the relationship is indirect

**Public Surface**:
The values a Carton deliberately makes available across its boundary, including values exposed through exported behavior.
_Avoid_: Only the directly declared values

**Gem Carton**:
A Carton whose Entrypoint belongs to a gem the importer has activated, such as a path gem in the app's Gemfile. Its Box gets that gem's dependencies at the importer's versions.
_Avoid_: Gem package

**Bare Carton**:
A Carton whose Entrypoint never calls `export`. The constants and top-level helpers its Entrypoint defines are its public surface, returned as a `Carton::Namespace`; importers never receive its Box.
_Avoid_: Unexported carton

**Export**:
The one value a Carton's Entrypoint gives `export`, returned as is when the Carton is imported: usually its root module, or a Hash from keywords. Calls in any other file, including files loaded by plain `require`, declare nothing. A Bare Carton has none.
_Avoid_: Default export, named exports, export declaration

**Namespace**:
The `Carton::Namespace` module a Bare Carton's importers receive, holding its constants and top-level helpers.
_Avoid_: Exports, export namespace
