# Carton

Carton provides a small import and export language for isolated Ruby packages.

## Language

**Carton**:
A logical, importable Ruby package with an isolated interior and a public surface.
_Avoid_: Package when naming the domain concept, box, plain carton, unbundled carton

**Entrypoint**:
The Ruby file selected by an Import to establish a Carton boundary. Any Ruby file may be an Entrypoint.
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

**Import**:
Loading a Carton into a Box and receiving its public surface. Only an Import crosses a Carton boundary; code loaded without one remains inside the current Carton.
_Avoid_: Require

**Imported Carton**:
A Carton imported directly by another Carton. It remains a separate boundary and exposes only its public surface to the importer.
_Avoid_: Child carton, nested carton

**Transitive Carton**:
A Carton reached indirectly through an Imported Carton.
_Avoid_: Imported carton when the relationship is indirect

**Public Surface**:
The values a Carton deliberately makes available across its boundary, including values exposed through exported behavior.
_Avoid_: Only the directly declared values

**Bare Carton**:
A Carton without declared exports. Its Box is its public surface.
_Avoid_: Unexported carton

**Export Declaration**:
A Carton's single declaration of its public surface, as either a Default Export or an Export Namespace. A Bare Carton has none.
_Avoid_: Multiple or incremental export declarations

**Default Export**:
A Carton's primary exported value, returned directly when the Carton is imported.
_Avoid_: Single export, direct export

**Export Namespace**:
A module-like public surface containing a Carton's Named Exports.
_Avoid_: Named exports or exports when referring to the whole namespace

**Named Export**:
A named member of an Export Namespace.
