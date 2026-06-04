# CLAUDE.md — OpenShape

> This file is read by Claude Code at the start of every session. It is the single source of truth for how this project is built. If something here conflicts with what seems "normal," follow this file. When an architectural decision changes, update this file in the same commit.

---

## What this project is

OpenShape is a **cross-platform, desktop-first 3D CAD modeler**. The goal is a near-1:1 functional replacement for **Shapr3D**, with a **Fusion 360–style non-linear feature timeline**. The motivation is ownership: a tool built once and kept, with no subscription.

The full design lives in `docs/OpenShape_System_Spec.docx`. Read it before any architectural work. This file is the quick-reference; the spec is the detail.

**Defining experience to replicate:** direct, intuitive solid modeling (push/pull on faces), an adaptive context-sensitive UI, and precise dimensional control — on a true B-rep solid kernel, not a mesh.

---

## Non-negotiable architecture

Do not deviate from these without my explicit sign-off. These are settled.

| Layer | Technology | Notes |
|-------|-----------|-------|
| UI / Presentation | **Qt 6** (C++) | Cross-platform desktop; mobile path reserved for later |
| Application / Document | **C++** (custom) | Document model, undo/redo, units, the feature timeline |
| Geometry kernel | **OpenCASCADE (OCCT)** | True B-rep. NOT Parasolid — see "Hard truths" below |
| I/O | OCCT data exchange + custom serializer | Native `.oshape` format |

**Language:** C++ (C++17 or newer). Qt and OCCT are both C++ native — do not introduce another primary language for core code.

**Build system:** CMake. Must build on Windows, Linux, and macOS from one tree. Every new module gets wired into CMake; never assume a single-OS build.

---

## Hard truths — internalize these

1. **OCCT, not Parasolid.** Shapr3D runs on the commercial Parasolid kernel. We cannot license it. This means: **no X_T / X_B (Parasolid) file formats**, ever, in v1. BREP + STEP are our lossless interchange instead. Do not propose Parasolid formats.

2. **Topological naming is THE hard problem.** When an upstream feature is edited and a body rebuilds, OCCT may renumber edges/faces. Naively storing indices produces a "broken history tree." We solve this with **geometric fingerprinting** (position, normal, adjacency) to re-match entities after a rebuild — never by trusting kernel indices. This is the highest-risk subsystem. If you are touching feature references, you are touching this. Tread carefully and ask if unsure.

2b. **Curvature-continuous surfacing is the SECOND hard problem.** Plasticity's signature G2 / Class-A surfacing rests on commercial Parasolid + xNURBS. On OCCT this is a research track, not a near-term feature (spec §3.5). Ship basic fillet/chamfer first. Do NOT imply parity with Plasticity's surfacing in user-facing docs — be transparent that curvature-perfect surfacing may never fully match on an open kernel.

3. **Every operation is a replayable feature.** The model is NOT a static shape. It is an ordered recipe of features; the visible geometry is the result of replaying that recipe. This includes direct push/pull edits — they record as features too. If you ever write code that mutates geometry without creating a timeline feature, that is a bug.

4. **Scope discipline.** v1 explicitly EXCLUDES: assemblies/mating, cloud/accounts/collaboration, the proprietary `.shapr` format, Parasolid formats, and Android. Do not add these. Flag scope creep when you see it.

---

## Core invariants (these cause silent bugs if violated)

- **Internal unit is millimeters, double precision, always.** All geometry math is in mm. Convert to/from the user's display unit (mm/cm/m/in/ft) ONLY at the input/display boundary. Never store a value in the user's display unit. Changing the display unit must never alter geometry — only its presentation.
- **The timeline is always recording**, even when the UI sidebar is collapsed. Users who want pure direct-modeling should be able to ignore the timeline, but it is still there. **Important:** the optional "direct-modeling mode" (collapsed timeline, Plasticity-style flow) is a HIDDEN VIEW of an always-recording timeline — it is NOT a history-free mode like Plasticity's. Rollback/edit capability stays fully intact underneath. Never implement a mode that actually stops recording features.
- **Rebuilds must be incremental where possible** — use the feature dependency graph; don't recompute the whole tree on every edit.
- **Keep the UI thread responsive** — long kernel operations (booleans, rebuilds) run off the UI thread where feasible.

---

## Layer separation rule (this protects the future Android port)

The four layers above are **strictly separated**. The UI layer must not reach directly into OCCT; it goes through the Application/Document layer. The reason is concrete: the eventual Android phase should be an adaptation of the **UI layer only**, not a rewrite. If you find yourself calling OCCT from UI code, stop — that is an architectural violation.

---

## Code conventions

- **C++17+**, RAII, smart pointers over raw owning pointers.
- **Naming:** `PascalCase` for types, `camelCase` for functions/variables, `m_` prefix for member variables. (If the existing code already diverges, match the existing code and tell me.)
- **OCCT handles:** use OCCT's `Handle()` mechanism as the library intends; don't fight it.
- **One feature type = one class**, implementing a common `Feature` interface (parameters, input references, `rebuild()`, full serialization).
- **Everything in a feature must serialize** to the native format and round-trip cleanly. A saved `.oshape` must reopen fully editable.
- **No magic numbers** for geometry tolerances — centralize them.
- Comment the *why*, not the *what*, especially around topological-naming and rebuild logic.

---

## Native file format (`.oshape`)

- ZIP container.
- JSON manifest: timeline, features, parameters, units, references, schema version.
- Serialized OCCT BREP of cached body results, so reopening is fast and doesn't force a full rebuild.
- **Versioned schema from day one.** Every format change bumps the version and provides migration. Never break old files silently.

---

## Milestone we are currently on

<!-- UPDATE THIS as we progress. Claude Code: read this first to know where we are. -->

**Current: M1 — Foundation.**
Goal: Qt window up, OCCT integrated and building on all three OSes, a 3D viewport with orbit/pan/zoom, and the ability to import and display a STEP file.

Milestone order (each is independently useful):
M1 Foundation · M2 Sketching+constraint solver · M3 First solids (extrude/push-pull) + timeline records them · M4 Core ops (fillet/chamfer/shell/boolean) + first cut at topological naming · M5 Advanced solids (revolve/sweep/loft) · M6 Patterns + UI polish · M7 I/O breadth + `.oshape` round-trip · M8 Units + measurement · M9 Blender niceties · M10 Android (later, deferred by design).

Do not jump ahead. If a task seems to require a later milestone's subsystem, say so rather than building it ad hoc.

---

## Decisions still open (ask me; don't silently pick)

- **Constraint solver (affects M2):** adopt an existing open-source solver vs. build. Strong lean toward adopting (e.g. an established 2D geometric constraint solver) rather than writing from scratch. Confirm with me before committing.
- **Rendering path:** OCCT's own visualization layer vs. a custom renderer over the tessellated B-rep.
- **DWG support:** requires a paid third-party library (e.g. ODA). DXF (open) ships first; DWG is optional. Don't add a paid dependency without asking.
- **Dependency management (M1 — DECIDED):** **aqtinstall for Qt 6 + vcpkg (manifest mode) for OCCT and other C++ deps.** Qt is downloaded as official prebuilt binaries via `aqtinstall` to `deps/Qt/` (gitignored). OCCT and future C++ libs come via `vcpkg.json` at the repo root; vcpkg is pointed to via `VCPKG_ROOT` env var (not committed). `CMakePresets.json` reads `$env{VCPKG_ROOT}` (toolchain) and `$env{QT_DIR}` (prefix path). See `scripts/setup-deps.sh` / `scripts/setup-deps.ps1`. Qt version: **6.7.3**. After vcpkg is installed, run `vcpkg x-update-baseline --add-initial-baseline` and commit the result to lock the registry baseline.

---

## Working style I want from Claude Code

- **Explain trade-offs before big moves.** For anything touching the timeline, topological naming, or the document model, walk me through the approach before writing a lot of code.
- **Small, reviewable increments.** I review and test as we go.
- **Be honest about kernel limits.** Where OCCT can't cleanly match a Shapr3D behavior, tell me plainly and propose the workaround rather than pretending it's seamless.
- **When you make a notable mid-session decision, remind me to record it here** so it survives into future sessions.
- **Update the "Current milestone" section** when we move forward.

---

## Repository & hosting

- **Public home:** GitHub (open source). Source code only — it stays small.
- **`.gitignore` is authoritative:** never commit `build/`, Qt, OCCT, package-manager-fetched deps, or compiled/linked artifacts. If a change would add a dependency or binary to the repo, stop and flag it.
- **Release binaries** (`.exe` / `.dmg` / AppImage) go through **GitHub Releases**, never committed to the repo tree.
- **Large test models:** keep committed fixtures SMALL. Route chunky CAD models (STEP/IGES/STL) through **Git LFS** via `.gitattributes` — only enable LFS when actually needed.
- **Optional workflow:** develop against the local Gitea instance (Raspberry Pi) and mirror to GitHub for public visibility. Not required.

---

## Reference

- Full spec: `docs/OpenShape_System_Spec.docx`
- Prior art to learn from (esp. for topological naming pain): FreeCAD (same Qt + OCCT stack).
- Experience to emulate: Shapr3D (adaptive UI, push/pull feel) + Fusion 360 (timeline + rollback marker) + Plasticity (direct-modeling flow, surfacing quality, live dimensioning, instancing). Note all three run on commercial Parasolid — their file-format breadth and surfacing polish come from paid components we can't use.
