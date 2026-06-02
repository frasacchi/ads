# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ADS (Aeroelastic Development Suite)** is a MATLAB package for programmatic generation of MSC Nastran finite element models and execution of aeroelastic analyses. The suite bridges BAFF (Build A Flexible Framework) geometry definitions with Nastran solver capabilities, enabling static, modal, flutter, and transient analyses.

**Version:** 0.3.2 | **MATLAB:** 9.12 (2022a) or later

### Core Mission
- Convert structural geometries (via BAFF) into Nastran-compatible FE models
- Automate setup and execution of multiple Nastran solution types
- Provide MATLAB interfaces for aerodynamic, structural, and aeroelastic analysis

---

## Package Architecture

ADS is organized into four main packages under +ads/:

### 1. **+fe (Finite Element Models)**
The core FE data structure. All structural elements are subclasses of ds.fe.Element.

**Key Classes:**
- Component — Container for all FE entities (points, beams, shells, constraints, etc.); supports hierarchical composition via nested Components
- Beam, Shell — Structural elements with material properties and cross-section/ply definitions
- Point — Node in 3D space with optional coordinate system
- Mass, Inertia — Concentrated and distributed inertial properties
- Constraint — Boundary conditions with translational/rotational DOF control
- AeroSurface, ControlSurface — Aerodynamic panel definitions
- Material, PlyDefinition, PlyLayer — Material and composite laminate properties
- CoordSys (and variants: BaseCoordSys, AbsCoordSys) — Local coordinate frames
- IDs — Central ID allocator tracking EID, PID, MID, SID counters (incremented during UpdateIDs())

**Export Pattern:** All Element subclasses implement Export(fid) to write Nastran BDF cards. The Component.Export() method recursively exports all child elements.

### 2. **+baff (BAFF-to-FE Conversion)**
Converts BAFF structural models (external package) into ads.fe.Component hierarchies.

**Key Functions/Classes:**
- baff2fe(baff.Model, BaffOpts) — Main entry point; converts entire BAFF model to FE structure
- element2fe(baff_element, BaffOpts) — Dispatcher for individual BAFF elements (Wing, Beam, BluffBody, etc.)
- ElementFactory(baff_obj, BaffOpts) — Factory routing BAFF types to conversion functions
- BaffOpts — Configuration class controlling conversion behavior:
  - SplitBeamsAtChildren — Split parent beams at child attachment points
  - GenerateAeroPanels — Create aerodynamic surfaces from wing geometry
  - ChildAttachmentMethod — How children connect to parents (Closest node vs global)
  - IncludeAeroAddedMass — Generate lumped masses for added mass effects
  - AirDensity, AddedMassStations — Aero parameters
- private/ functions (wing2fe, beam2fe, shell2fe, constraint2fe, etc.) — Type-specific conversion logic

### 3. **+nast (Nastran Integration)**
Handles BDF file generation and Nastran execution for various solution types.

**Solution Type Classes (@SolXXX folders):**
- Sol101 — Static analysis with gravity/loading
- Sol103 — Modal (eigenvalue) analysis
- Sol111 — Fatigue analysis (incomplete)
- Sol144 — Static aeroelastic trim
- Sol145 — Dynamic aeroelastic (flutter) analysis
- Sol146 — Transient aeroelastic with gusts/turbulence
- Divergence — Divergence (static aeroelastic instability) analysis

**Each Solution Class:** Defines parameters (frequency ranges, damping, CoM constraints) and implements:
- UpdateID(ids) — Allocate Nastran IDs
- write_main_bdf(filename, model_path) — Write case control and SUBCASE entries
- run(feModel, opts) — Execute Nastran and retrieve results

**Utilities:**
- buildCommand(runFile, opts) — Construct Nastran command line
- create_tmp_bin(BinFolder) — Set up analysis directory structure
- SubCase, TrimParameter — Case control helpers
- +gust/ — Turbulence/gust definitions (Turb, OneMC, BaseSettings)
- +plot/ — Solution result visualization (sol101, sol103, sol144, sol145)

### 4. **+util (Utilities)**
Reusable computational functions.

**Atmospheric & Flight Physics:**
- atmos(h, tOffset) — 1976 Standard Atmosphere properties (density, speed of sound, viscosity, etc.) with optimized scalar/array handling
- atmosT(h) — Fast temperature-only lookup
- true_airspeed(M, h) — Mach/altitude to TAS conversion
- calibrated_airspeed(M, h) — Mach to CAS conversion
- get_flight_condition(M, h) — Return all atmospheric + airspeed properties
- Rodrigues(theta_vec, P) — Rigid body rotation via Rodrigues formula

**Rotation Matrices:**
- rotx(angle), roty(angle), rotz(angle) — Elementary 3D rotation matrices

**UI & Plotting:**
- +plotting/ — Interactive figure callbacks (mouse, keyboard, scroll wheel)
- +printing/ — Title formatting utilities

---

## Key Workflows

### 1. Building an FE Model from BAFF

```matlab
model = baff.Model();
% ... add geometry via BAFF API ...

% Convert to FE
fe = ads.baff.baff2fe(model);  % Accepts optional BaffOpts

% Configure aerodynamics
fe.AeroSurfaces.SetPanelNumbers(4, 1, 'Span');  % 4 chordwise, AR=1

% Visualize
fe.draw();
```

### 2. Running a Static Analysis (Sol101)

```matlab
% Prepare FE model
fe = fe.Flatten();  % Collapse nested Components
IDs = fe.UpdateIDs();  % Allocate all Nastran IDs

% Create and configure solution
sol = ads.nast.Sol101();
sol.g = 0;  % Disable gravity (or set to 9.81)
sol.UpdateID(IDs);  % Assign IDs to solution parameters

% Execute
binFolder = 'my_analysis';
sol.run(fe, BinFolder=binFolder, Silent=false);

% Read results via mni library
h5_file = mni.result.hdf5(fullfile(binFolder, 'bin', 'sol101.h5'));
displacements = h5_file.read_displacements();
```

### 3. Running Modal Analysis (Sol103)

```matlab
sol = ads.nast.Sol103();
sol.FreqRange = [0.01, 50];  % Hz
sol.NFreq = 500;  % Number of frequency points
sol.LModes = 20;  % Number of modes to extract
sol.ModalDampingPercentage = 2;  % Structural damping
sol.UpdateID(IDs);

[modes, binFolder] = sol.run(fe, BinFolder='modal_analysis');
```

### 4. Running Flutter Analysis (Sol145)

```matlab
sol = ads.nast.Sol145();
sol.MachRange = [0.3, 0.9];
sol.AltRange = [0, 15000];  % feet
sol.UpdateID(IDs);

[flutter_data, binFolder] = sol.run(fe, BinFolder='flutter_analysis');
```

### 5. Running Transient Gust Analysis (Sol146)

```matlab
sol = ads.nast.Sol146();
sol.TimeVector = linspace(0, 30, 1000);  % seconds
sol.UpdateID(IDs);

gust = ads.nast.gust.Turb();  % Or define custom turbulence
[transient_data, binFolder] = sol.run(fe, Gust=gust, BinFolder='gust_analysis');
```

---

## Common Development Tasks

### Running Tests

```matlab
runtests('tests')  % Run all tests in MATLAB
runtests('tests/baff2feTest.m')  % Run specific test class
```

The test framework uses matlab.unittest.TestCase with parameterized tests (e.g., baff2feTest runs hinge conversion across multiple fold/flare angles).

### Examples & Integration Testing

Located in Examples/ folder (SimpleWing_sol101_example.m, cantileverFFWT_sol103_example.m, etc.). These serve as both documentation and integration tests. Run one end-to-end:

```matlab
run Examples/SimpleWing_sol101_example.m
```

### Extending with New Solution Types

1. Create +ads/+nast/@SolXXX/ folder
2. Define SolXXX.m (subclass handle) with properties and UpdateID() method
3. Implement write_main_bdf(filename, model_path) to generate BDF case control
4. Implement run(feModel, opts) using ads.nast.buildCommand() and result reading (mni library)
5. Test with an Example script

### Adding New Element Types

1. Create subclass of ads.fe.Element in +ads/+fe/
2. Implement Export(fid) method to write Nastran cards (use mni.printing.cards.* for card formatting)
3. Implement UpdateID(ids) to allocate IDs
4. Optionally implement drawElement() for visualization
5. Add conversion function in +ads/+baff/private/ if converting from BAFF

---

## Important Design Patterns

### ID Allocation

- ads.fe.IDs tracks counters: EID (element), PID (property), MID (material), SID (set ID)
- Each Solution type allocates its own SIDs (eigenvalue sets, load sets, etc.)
- Call Component.UpdateIDs() before export to populate all Element.ID properties
- Increment IDs sequentially to avoid collisions

### Element Heterogeneity

- Element uses matlab.mixin.Heterogeneous to support array operations on mixed types
- Example: [Beam, Shell, Mass] arrays are valid and supported

### BDF Export

- All export uses mni library (mni.printing.cards.* and mni.printing.bdf.*)
- Long format cards are enabled by default for readability
- Comments are auto-inserted for each card type group

### Coordinate System Hierarchy

- BaseCoordSys: Fixed rectangular coordinates
- AbsCoordSys: Absolute (global) frame reference
- CoordSys: Local frame with transformation matrix A (rotation from global)
- Point coordinates are stored globally; local frames define element properties

### Aero Panel Generation

- AeroSurface.SetPanelNumbers(nChord, aspectRatio, spanDir) defines aerodynamic discretization
- Automatically generates CAERO cards and spline (RBE3) to structural grid

---

## Dependencies

### External MATLAB Packages

- **mni** (Matran Nastran Interface) — BDF reading/writing and Nastran result I/O
- **BAFF** (Build A Flexible Framework) — Structural geometry definitions
- **fh** (Frank Hua utilities) — Rotation functions and basic numerics

### Nastran

- Requires MSC Nastran executable in system PATH
- Solution types compile to BDF files; Nastran execution is system-level

### MATLAB Built-ins

- Uses MATLAB 2022a+ features: arguments blocks, string type, heterogeneous arrays

---

## Debugging Tips

### Common Issues

1. "Fatal error detected in f06 file" — Check BinFolder/Source/ console output; errors often relate to missing/duplicate IDs, undefined materials, or unsupported card formats.
2. Empty/malformed BDF — Verify Component.Flatten() and Component.UpdateIDs() increment correctly.
3. Aero panel misalignment — Check AeroSurface grid definitions and spline attachments; use fe.draw().
4. Coordinate system mismatch — Ensure BAFF parent/child frames align with expected attachment points.

### Inspecting Generated Files

After sol.run(), examine:
- BinFolder/Source/solXXX.bdf — Top-level case control and subcase
- BinFolder/Source/Model/model.bdf — Exported FE model
- BinFolder/bin/solXXX.f06 — Nastran output (errors, warnings, summary)
- BinFolder/bin/solXXX.h5 — Binary results (HDF5 format)

---

## Release & Versioning

Uses Semantic Versioning. Current version in version.txt is 0.3.2.

See changelog.txt for full history.

---

## Repository Remotes

- **origin** — Personal fork (frasacchi/ads)
- **upstream** — Main repository (DCRG-Bristol/ads)

Current branch: master
