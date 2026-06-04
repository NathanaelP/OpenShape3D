# OpenShape — System Specification

**Project "OpenShape"** — An open, perpetually-owned direct + parametric CAD modeler.

Modeled as a near 1:1 functional replacement for Shapr3D, with Fusion 360–style non-linear timeline editing.

**Version 0.1 — Draft · June 2026**

> This is the plain-text companion to `OpenShape_System_Spec.docx`. The `.docx` is the human-readable copy; this Markdown file is the version tools (and Claude Code) read, and it diffs cleanly in Git. Keep the two in sync — if you edit one, edit the other.

---

## 1. Purpose & Scope

OpenShape is a cross-platform, desktop-first 3D CAD application. Its goal is to reproduce the modeling experience of Shapr3D as closely as is practical with open-source technology, while adding a Fusion 360–style fully non-linear feature timeline. The driving motivation is ownership: this is a tool you build once and keep, free of subscription dependency.

The defining experience to replicate is direct, intuitive solid modeling — push/pull on faces, an adaptive context-sensitive UI, and precise dimensional control — layered on top of a true B-rep solid kernel rather than a mesh. Shapr3D itself achieves this on the commercial Siemens Parasolid kernel; OpenShape targets the open-source OpenCASCADE Technology (OCCT) kernel instead, which is the same kernel FreeCAD is built on. This single substitution is the most consequential decision in the spec and is called out wherever it changes behavior.

### 1.1 Primary goals

- Desktop-first on Windows, Linux, and macOS from a single codebase.
- True solid (B-rep) modeling with precise, watertight geometry suitable for 3D printing and CNC.
- Direct modeling feel (Shapr3D-style push/pull) combined with a parametric feature history.
- Fully non-linear timeline: roll back to any feature, edit its parameters, and rebuild forward — Fusion 360 style.
- Switchable units between metric and imperial at any time, with per-document defaults.
- Broad import/export parity with Shapr3D's neutral formats.

### 1.2 Explicit non-goals (for v1)

- No cloud sync, no account system, no collaboration server — fully offline, local files.
- No reproduction of Shapr3D's proprietary .shapr file format (closed format; not feasible or legal to clone).
- No Parasolid-native formats (X_T / X_B). These are tied to the commercial kernel — see §7.
- No assemblies / mating constraints in v1 (planned later).
- Android is a deliberate later phase, not part of the v1 desktop target.

> **Reality check:** A CAD application is one of the most demanding categories of desktop software, and the geometry kernel underneath it represents decades of specialized engineering. OpenShape does not reimplement that kernel — it wraps OCCT. Even so, this is a multi-month, milestone-driven build, not a single-session project. The spec is structured so that each milestone produces a genuinely usable tool.

---

## 2. System Architecture

OpenShape is organized into four layers. Keeping these strictly separated is what makes the later Android port an adaptation of the top layer rather than a rewrite.

| Layer | Responsibility | Technology |
|-------|----------------|------------|
| UI / Presentation | Windows, panels, the adaptive toolbar, the timeline sidebar, input handling | Qt 6 (Widgets + Quick), C++ |
| Application / Document | Document model, undo/redo, unit system, selection state, the feature timeline | C++ (custom) |
| Geometry Engine | All solid/surface math: primitives, booleans, fillets, lofts, tessellation | OpenCASCADE Technology (OCCT) |
| I/O | Import/export, file (de)serialization of the native document | OCCT data exchange + custom serializer |

### 2.1 Why Qt + OpenCASCADE

This pairing is the established, proven stack for open desktop CAD — it is essentially the combination FreeCAD uses, which means abundant reference material and a well-understood integration path.

- **Qt 6** — handles cross-platform desktop UI (Windows, Linux, macOS) from one codebase, and has a documented mobile deployment path for the eventual Android phase.
- **OpenCASCADE (OCCT)** — a mature open-source B-rep kernel providing NURBS surfaces, boolean operations, filleting, and neutral-format data exchange. This is what makes OpenShape a true solid modeler rather than a mesh editor.
- **C++** — the lingua franca tying Qt and OCCT together; both libraries are C++ native.

### 2.2 The central design tension

Shapr3D is famous for a near-invisible UI driven by direct manipulation, yet it later added a history tree. OpenShape must serve both instincts from day one: the timeline is always recording, but it can be collapsed and ignored by users who just want to push and pull. The architecture must therefore treat every direct edit as a recordable, replayable feature — this is covered in §5 and is the most architecturally important requirement in the document.

### 2.3 Hardware baseline

CAD on a real B-rep kernel is resource-hungry. As a realistic target (Plasticity recommends the same ballpark), assume a baseline of 16 GB RAM and a dedicated GPU for working comfortably with dense models. OpenShape should still run on less for light work, but this is the expected developer/user baseline rather than a minimum-spec promise.

---

## 3. Core Subsystems

### 3.1 Viewport & navigation

- Real-time 3D viewport rendering the OCCT model via its visualization layer (or a custom renderer over the tessellated B-rep).
- Orbit, pan, zoom; configurable navigation presets (the ability to match Fusion 360, SolidWorks, or Shapr3D navigation styles is a strong nicety).
- Standard named views (top, front, right, isometric) and a navigation cube / view gizmo.
- Selection of vertices, edges, faces, and bodies with clear hover highlighting — Shapr3D's hover feedback is part of what makes it feel intuitive and should be matched.
- Section / cross-section view for inspecting internal geometry.

### 3.2 Adaptive UI

Shapr3D's signature interface trait is that it is context-sensitive: it surfaces only the tools relevant to the current selection, which is a large part of why it feels approachable. OpenShape should replicate this.

- Toolbar contents change based on what is selected (nothing / sketch / face / edge / body).
- On-screen prompts guide the user through multi-step operations.
- Keyboard shortcuts for every common tool, with a user-editable shortcut map.
- Optional 'classic' mode where the full toolset is always visible, for power users.

### 3.3 Sketching (2D)

Sketches are the foundation of parametric features. A robust constraint solver is required — this is one of the harder subsystems and a candidate for an existing open-source solver rather than a from-scratch build (see §8).

- Primitives: line, polyline, rectangle, circle, arc, ellipse, spline, point, slot.
- Constraints: coincident, parallel, perpendicular, tangent, horizontal/vertical, equal, concentric, symmetric, fixed.
- Dimensions: linear, angular, radial, diameter — driving (parametric) dimensions, not just annotations.
- Goal: 'fully defined' sketches, where the solver reports when a sketch is unambiguously constrained.
- Trim, extend, offset, mirror, pattern within the sketch.
- Sketch on any plane or planar face; project existing edges into the active sketch.

### 3.4 3D modeling tools

These are the core solid operations. The first set mirrors Shapr3D's fundamental toolset; together they cover the large majority of real modeling work.

| Tool | Description | Milestone |
|------|-------------|-----------|
| Extrude | Push a sketch profile into a solid; new body, add (union), cut, or intersect | M3 |
| Push/Pull | Direct manipulation of a face to add or remove material — the Shapr3D signature | M3 |
| Revolve | Rotate a profile about an axis | M4 |
| Sweep | Drive a profile along a path | M5 |
| Loft | Blend between two or more profiles | M5 |
| Shell | Hollow a solid to a wall thickness | M4 |
| Fillet / Chamfer | Round or bevel edges | M4 |
| Boolean | Union, subtract, intersect between bodies | M4 |
| Draft | Apply angled draft to faces | M6 |
| Move / Rotate / Scale | Transform bodies, faces, or sketch elements | M3 |
| Mirror / Pattern | Linear, circular, and mirror patterns of features or bodies | M6 |

### 3.5 Surfacing & continuity (aspirational — inspired by Plasticity)

> **Difficulty warning:** This is arguably the hardest area in the entire spec — harder than topological naming. Plasticity's curvature-perfect surfacing rests on the commercial Parasolid kernel plus the commercial xNURBS component (historically a high-cost add-on even for Rhino and SolidWorks). OCCT can do NURBS surfaces and some continuity work, but matching this polish on an open kernel is genuinely difficult. These features are aspirational, not near-term milestones.

Plasticity is the most relevant comparison for OpenShape's direct-modeling feel, and its signature strength is high-quality surfacing. The following are targets to approach over time, with eyes open about kernel limits:

- Curvature-continuous (G2) fillets and edge control — fillets that blend smoothly rather than just rounding, Plasticity's headline strength.
- Surface blending across continuity levels: G0 (touching), G1 (tangent), G2 (curvature-continuous).
- Surface continuity inspection — visually report G0/G1/G2 between adjacent faces so the user can validate smoothness.
- Class A surfacing as a long-term aspiration for surfaces that must reflect light cleanly (industrial/product design).

Honest posture: ship basic fillet/chamfer first (M4), and treat true curvature-continuous surfacing as a research track that may never fully match Plasticity on OCCT. Be transparent about this in user-facing docs rather than implying parity.

### 3.6 Measurement & inspection

- Measure distance, angle, radius between any selected entities.
- Mass properties: volume, surface area, center of mass, bounding box.
- Live readout respecting the active unit system (§6).
- **Live dimensioning (Plasticity-inspired):** dimensions update in real time as you model, not just as a separate annotation step. This pairs directly with the numeric-input-while-dragging idea in §8 — start a drag, see the dimension live, type an exact value to commit it.

---

## 4. Document & Data Model

The document is the in-memory representation of everything in a project. Its design is dominated by one requirement: every operation must be replayable so the timeline can rebuild the model from any point (§5).

### 4.1 Object hierarchy

- **Document** — the root; owns the unit system, the feature timeline, and all top-level items.
- **Body** — a solid or surface result, backed by an OCCT shape (TopoDS_Shape).
- **Sketch** — a 2D profile on a plane, with its geometry, constraints, and dimensions.
- **Feature** — one recorded operation (an extrude, a fillet, an import). Features are the entries in the timeline.
- **Plane / Axis / Point** — reference (datum) geometry used to position sketches and features.
- **Instance (Plasticity-inspired)** — a lightweight reference to an existing body rather than a full copy. Many instances of the same geometry stay cheap in memory and update together. Distinct from a pattern (which generates features); an instance is a managed reference for dense models.

### 4.2 Key data structures

| Structure | Holds | Notes |
|-----------|-------|-------|
| Feature | Type, parameters, references to inputs, cached result | The atomic unit of the timeline; must serialize fully |
| FeatureTimeline | Ordered list of features + a 'rollback marker' | See §5; the heart of non-linear editing |
| Selection | Currently selected entities + their owning bodies | Drives the adaptive UI |
| UnitContext | Active unit system, precision, display format | Queried by every dimension field |
| TopoRef | Stable reference to a face/edge across rebuilds | The hardest problem — see §5.3 |

### 4.3 Native file format

Because the .shapr format is closed, OpenShape defines its own native format — proposed extension `.oshape`. It must store not just the final geometry but the entire feature timeline, so a saved file reopens fully editable.

- Container: a ZIP archive (like most modern document formats).
- Inside: a JSON (or similar) manifest describing the timeline, features, parameters, units, and references.
- Plus: a serialized OCCT representation (BREP) of cached body results so reopening is fast and does not require a full rebuild.
- Versioned schema from day one, so future format changes can migrate old files.

---

## 5. Non-Linear Feature Timeline (Fusion 360–style)

> **This is the headline feature you asked for, and the most technically demanding part of the system.** It is what separates a simple direct editor from a real parametric CAD tool. Everything in §4 exists to make this section work.

### 5.1 The core concept

The model is not stored as a static shape. It is stored as an ordered recipe of features. The visible geometry is the result of replaying that recipe from start to finish. Shapr3D's own history works this way: each step is recorded every time you make an edit, every step has editable parameters, and steps can be reordered.

Fusion 360 extends this with a timeline at the bottom of the screen and a 'rollback marker' you can drag backward in time. When you roll back, edit a feature, and roll forward, the entire model rebuilds with your change applied. OpenShape adopts this exact model.

### 5.2 Required behaviors

1. Every operation (including direct push/pull edits) creates a feature entry in the timeline.
2. The user can scrub a rollback marker to any point; geometry created after that point is temporarily suppressed.
3. The user can select any individual feature, open it, and edit its parameters — the exact request: change one feature in place and let everything downstream rebuild around it.
4. Features can be reordered by dragging them earlier or later in the timeline (e.g. moving a shell to before an extrude changes the result — a documented Shapr3D capability).
5. Features can be renamed from generic auto-names (Fillet034) to meaningful labels.
6. Features can be suppressed/unsuppressed individually without deletion.
7. Deleting a feature triggers a rebuild and reports any downstream features that can no longer resolve.

### 5.2a Direct-modeling mode (collapsed timeline) — the Plasticity contrast

Plasticity deliberately rejects the history tree, offering pure direct modeling with no recorded recipe. OpenShape does NOT adopt that philosophy — the timeline above remains the architectural core. However, Plasticity's appeal points to a useful UI option.

- OpenShape offers an optional mode where the timeline sidebar is collapsed and the user simply pushes, pulls, and edits geometry directly — the fast, low-friction feel Plasticity is loved for.
- **Critical distinction:** even in this collapsed mode the timeline is STILL recording every operation underneath. This is a hidden view, not a history-free mode. The user can expand the timeline at any moment and all rollback/edit capability is intact.
- This gives both audiences what they want: artists get Plasticity-style flow; engineers get Fusion 360–style rollback — from the same always-recording model.

### 5.3 The hard problem: persistent topological references

This deserves its own section because it is the single biggest source of difficulty in parametric CAD, and OpenShape inherits it directly from using OCCT.

When a fillet says 'round edge #7', and an earlier feature is edited so the body is rebuilt, the kernel may renumber its edges — 'edge #7' might now be a different edge, or might not exist. Naively storing integer indices produces the infamous 'broken history tree' that plagues parametric CAD users. The system needs a stable naming scheme (often called 'persistent naming' or 'topological naming') that re-identifies the same logical face/edge after a rebuild.

- OCCT does not solve this for you out of the box; FreeCAD has fought this exact issue for years (its 'topological naming problem').
- Mitigation: store geometric fingerprints (position, normal, adjacency) for referenced entities and re-match them after each rebuild, rather than relying on kernel indices.
- This subsystem should be prototyped early (a slice of it in M4) because it affects the reliability of every downstream feature.

> **Honest expectation:** Shapr3D's robustness here rests on the maturity of Parasolid. Matching it exactly on OCCT is genuinely hard, and some edge cases that 'just work' in Shapr3D may need workarounds in OpenShape. This is the area most likely to consume time — budget for it.

### 5.4 Rebuild engine

- A dependency graph links features to the entities they consume, so a rebuild only recomputes what is affected (not always the whole tree).
- Rebuilds run off the UI thread where possible to keep the viewport responsive.
- Cached results per feature avoid recomputing unchanged upstream features.

---

## 6. Units of Measurement

Units must be switchable between metric and imperial at any time, as requested. Internally this is handled by storing one canonical unit and converting only at the display/input boundary.

- **Canonical internal unit: millimeters, stored as double precision.** All geometry math happens in this single unit — never store values in the user's display unit.
- Display/input layer converts to the active unit (mm, cm, m, in, ft) on the way out and back on the way in.
- Per-document default unit, set on creation and changeable later without altering the geometry — only its presentation.
- Configurable display precision and rounding.
- Dimension input fields accept unit suffixes and simple math (e.g. typing 1/2" or 25.4mm) regardless of the active default.
- Grid and snap settings respect the active unit.

---

## 7. Import & Export

You asked for the same import/export coverage as Shapr3D. The table below maps Shapr3D's documented formats to what OpenShape can realistically support on OCCT. The honest gaps are all consequences of the kernel substitution and are flagged plainly.

### 7.1 Shapr3D's documented format support (reference)

For grounding, Shapr3D supports import/export of neutral formats including STEP, IGES, and (via its Parasolid kernel) X_T/X_B; it exports STL, 3MF, OBJ, DWG, DXF, and 2D image/vector formats (PDF, JPEG, PNG, SVG), imports image references (PNG, JPG, TIFF, PDF, BMP, etc.), and at the Enterprise tier handles native formats from CATIA, Creo, Solid Edge, NX, and SolidWorks. Its design space is bounded at roughly 1 km³.

### 7.2 OpenShape target format support

| Format | Import | Export | Notes vs. Shapr3D |
|--------|--------|--------|-------------------|
| STEP (.step/.stp) | Yes | Yes | Primary neutral B-rep format; OCCT has solid support. Full parity. |
| IGES (.iges/.igs) | Yes | Yes | Supported by OCCT. Full parity. |
| BREP (.brep) | Yes | Yes | OCCT-native exchange format — OpenShape's lossless interchange (the role X_T plays for Shapr3D). |
| STL (.stl) | Yes (ref) | Yes | Mesh export for 3D printing. Parity. |
| 3MF (.3mf) | Optional | Yes | Export for modern 3D printing. Shapr3D is import-only for 3MF. |
| OBJ (.obj) | Yes | Optional | Mesh interchange. Shapr3D is import-only for OBJ. |
| DXF (.dxf) | Yes | Yes | 2D sketches/drawings. Parity (library-assisted). |
| DWG (.dwg) | Maybe | Maybe | Proprietary; needs a third-party library (e.g. ODA). Possible licensing cost — flagged. |
| X_T / X_B (Parasolid) | No | No | Tied to the commercial Parasolid kernel. Not available — the main honest gap. |
| SLDPRT / CATIA / Creo / NX | No | No | Vendor-native; Shapr3D only does these at Enterprise tier via licensed components. |
| Images (PNG/JPG/PDF...) | Yes (ref) | — | Reference underlays for tracing. Parity on common types. |
| PDF / SVG (2D out) | — | Yes | Vector drawing export. Parity. |

### 7.3 Honest gaps summary

- **Parasolid formats (X_T/X_B) are off the table.** This is the clearest functional difference from Shapr3D and is unavoidable without licensing Parasolid. BREP and STEP serve as the lossless interchange substitute.
- **Vendor-native CAD formats** (SolidWorks, CATIA, Creo, NX) are not feasible to read directly; rely on STEP as the bridge, exactly as most interoperability does in practice.
- **DWG** may require a paid third-party library. DXF (open) covers most 2D needs without that cost.

---

## 8. Blender-Inspired Additions

You asked which Blender features would be nice additions. Blender is a mesh/artist tool rather than a precision CAD tool, so not everything maps cleanly — but several ideas would meaningfully enhance OpenShape without compromising its CAD precision. They are grouped by how well they fit.

### 8.1 Strong fits (recommended)

- **Modifier-stack thinking** — Blender's non-destructive modifier stack is conceptually a cousin of your feature timeline. Borrowing its clarity (mirror, array, and 'solidify'/shell as stackable, reorderable, toggleable modifiers) reinforces the non-linear design in §5.
- **Workspaces / configurable layouts** — Blender's saved screen layouts per task (Modeling, Rendering) would suit switching between sketching, modeling, and inspection.
- **Numeric input while dragging** — Blender lets you start a move/rotate and type an exact value mid-gesture. This pairs beautifully with CAD precision and the unit system in §6.
- **Customizable keymap & pie menus** — Blender's deeply user-editable shortcuts (and radial pie menus) would make the adaptive UI fast for power users.
- **Snapping system** — Blender's flexible snap targets (vertex, edge, face, midpoint, grid) are excellent and directly applicable.

### 8.2 Nice-to-have (later)

- **PBR material preview / rendering** — Shapr3D itself added physics-based rendering for presentation. A Blender-style material preview viewport would be a strong later addition for design validation.
- **Python scripting console** — Blender's embedded Python is a huge productivity multiplier. A scripting API over the document model (also how FreeCAD works) would let you automate repetitive modeling — and fits your programming background.
- **Annotations / grease-pencil-style notes** — lightweight 3D annotations for marking up a design.

### 8.3 Poor fits (avoid in a CAD tool)

- Sculpting / dyntopo — mesh-artist features that conflict with precise B-rep modeling.
- Free-form polygon mesh editing as a primary workflow — keep OpenShape solid-first; offer mesh only as import/export.
- Full animation/rigging — out of scope for mechanical CAD.

---

## 9. Build Milestones

Each milestone is a usable increment, so the tool is functional long before it is complete. This sequencing front-loads the riskiest subsystem (the timeline + topological naming) so problems surface early.

| Milestone | Deliverable | Key risk |
|-----------|-------------|----------|
| M1 — Foundation | Qt window, OCCT integrated, viewport with orbit/pan/zoom, import + display a STEP file | Build system across 3 OSes; OCCT setup |
| M2 — Sketching | 2D sketch primitives + a working constraint solver; 'fully defined' detection | Constraint solver choice (§8 note) |
| M3 — First solids | Extrude, push/pull, move/rotate/scale; the timeline records these features | First real test of the feature model |
| M4 — Core ops + naming | Fillet, chamfer, shell, booleans + a first cut at persistent topological references | Topological naming (§5.3) — highest risk |
| M5 — Advanced solids | Revolve, sweep, loft | Geometric robustness on OCCT |
| M6 — Patterns + UI polish | Mirror, linear/circular patterns, draft; adaptive UI maturity | Pattern + history interaction |
| M7 — I/O breadth | STL/3MF/OBJ/DXF/IGES + image underlays; native .oshape save/open round-trip | Format edge cases |
| M8 — Units + measurement | Full metric/imperial switching, measure tools, mass properties | Precision/display correctness |
| M9 — Blender niceties | Numeric-input-on-drag, snapping, keymap editor, scripting console | Scope creep |
| M10 — Android (later) | Adapt the Qt UI layer for touch + larger-phone screens | Touch UX; deferred by design |

Do not jump ahead. If a task seems to require a later milestone's subsystem, say so rather than building it ad hoc.

---

## 10. Risks & Honest Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Topological naming on OCCT | High | Prototype early (M4); geometric fingerprinting; accept some edge-case gaps vs. Parasolid |
| Curvature-continuous surfacing on OCCT | High | Treat as research track (§3.5); ship basic fillet first; be transparent about non-parity vs. Plasticity |
| Constraint solver complexity | Med-High | Adopt an existing open solver rather than building from scratch (§8) |
| Scope (matching Shapr3D 1:1) | High | Milestone discipline; v1 explicitly excludes assemblies, cloud, .shapr, Parasolid formats |
| Geometric robustness of OCCT ops | Medium | Lean on FreeCAD's documented experience; extensive test models |
| DWG licensing | Low-Med | Ship DXF first; treat DWG as optional/paid-library |
| Single-developer sustainability | Medium | Each milestone is independently useful; CLAUDE.md keeps long build coherent |

### 10.1 Bottom line

The interface, the timeline, the units, and the bulk of the import/export are all achievable with Qt + OpenCASCADE over a milestone-driven build. The two places where OpenShape will differ from Shapr3D are unavoidable consequences of using an open kernel: no Parasolid-native formats, and topological-naming robustness that will take real work to approach Shapr3D's polish. Neither blocks the core goal — a precise, perpetually-owned, subscription-free modeler that feels like the tool you already love to use.

---

*— End of Specification v0.1 —*
