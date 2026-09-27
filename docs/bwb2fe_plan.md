# `bwb2fe` — BWB aeroelastic model generation for ADS (implementation plan, v2)

> **Goal.** Build an **A320-class blended-wing-body (BWB)** MSC Nastran model in ADS for
> **aeroelastic stability and dynamic behaviour**: find where the free-flying aircraft becomes
> **dynamically unstable** (body-freedom flutter (BFF), classical flutter, divergence), and
> describe its **rigid + flexible dynamics** (short period, BFF coalescence, gust/control response).
>
> `ads.bwb.bwb2fe` produces the structure in one of two forms:
>
> * **Shell** (`Shell=true`): `CQUAD4`/`PSHELL` wingbox (centre body + mid section + outer wing box),
>   routed through the existing `shell2fe`.
> * **Beam** (`Shell=false`): a 1-D **wingbox reduction** (multi-cell thin-walled condensation, with a
>   centreline spine), optionally calibrated against the shell model.
>
> Both forms carry **DLM `CAERO1` panels on the centre body**, which holds about 64 % of the planform,
> and **payload as distributed mass**.
>
> **v2 changes (aeroelastic focus):**
> * Cabin layout detail is reduced. The home-plate cabin now only defines the payload region and the
>   pressure-vessel walls, which set the centre-body stiffness.
> * Pressure loading is optional.
> * New inputs for BFF (§2) and new stability and flight-dynamics workflows (§10–§11).
> * Code snippets for every repository edit (§12).
>
> Status: **plan only; no repository code changed.** The "trial" of the current code (§3) was done by
> reading and tracing the source. MATLAB and Nastran were not available where this was written, so
> Phase 0 repeats the trials on a machine that has them.

---

## 0. How to use this document (Claude Code working agreement)

1. Work **phase by phase** (§13). Do not start a phase until the previous phase's acceptance checks pass.
2. You need MATLAB ≥ R2022a and MSC Nastran locally. Run `runtests('tests')` after each phase.
   Tests that need Nastran carry the tag `"Nastran"`.
3. Repositories and branch: `frasacchi/ads`, `frasacchi/baff`, `frasacchi/Matran`, all on
   `claude/vigilant-hamilton-kxm445`. BAFF stays geometry-only; FE and Nastran logic goes in ADS.
4. Snippets are **sketches** against the current APIs (checked against the source). Items marked
   *(new)* do not exist yet. Where a DMAP line number or subDMAP name is version-dependent, it is flagged.

---

## 1. Sources

| Source | What is used |
|---|---|
| **Gern, NASA 20120008184 (key)** | Three components (centre body / mid section / outboard wing). Spars at 12.5 %/62.5 %. Home-plate cabin. **1/3/5-bay** walls. All-`CQUAD4` model. PRSEUS modelled through `PSHELL` 12I/T³. DLM from sliced OML with camber/twist downwash, splined to the spars. Half model. |
| **Joseph et al. (NASA Ames) MER** | Cabin parameterisation (A_CB, FR, θ_CB, SR); IM7-8552 and PRSEUS data; cabin-weight cross-check. |
| **Ikeda & Bil (ICAS)** | Bradley cabin regression (sanity check only). |
| **gemini first plan** | A320neo-class targets: b = 35.8 m, S ≈ 220 m², masses, 38/62 lift share, per-segment splines, SOL144/145 set-up, AELINK-geared elevons, body-freedom flutter. |
| Origin chat link | **Could not be read** (the link returned a company information page). |

---

## 2. Additional inputs for aeroelastic stability, BFF and flight dynamics

Yes, several inputs should be added. BFF comes from the **short-period mode** (rigid pitch/plunge,
whose frequency rises with speed) **coalescing with the first symmetric wing/body bending mode**. So
the inputs that set the short-period frequency (CG vs neutral point, pitch inertia, Cmα) and the
elastic frequencies (stiffness, mass distribution) matter far more than the cabin layout.

| Group | Input *(new unless noted)* | Default | Why it matters |
|---|---|---|---|
| **Mass cases** | `BWBMass.Case` ∈ MTOM / MZFW / OEW+reserve / Custom; `PayloadFraction`, `FuelFraction` | MTOM | BFF speed changes strongly with mass and fuel state. Sweep the cases. |
| **Payload as distributed mass** | `PayloadArealDensity` over the payload region (the home-plate polygon), plus `PayloadBias` (linear fore/aft gradient) | uniform, bias 0 | Sets CG and **pitch inertia I_yy** with no cabin detail. The bias is the CG-trimming knob. |
| **CG / static margin** | `CGTarget` = `"StaticMargin"` with `StaticMargin` (fraction of MAC), or an absolute `XCG` | SM = 0.05 | Short-period frequency grows with static margin, so the BFF onset speed depends on it. NP comes from the rigid SOL144 (§10.2). |
| **Inertia check** | `IyyTarget` (optional); reported always: mass, CG, I_xx, I_yy, I_zz (§8.3) | report | The BWB's low I_yy, relative to its mass, drives BFF. |
| **Fuel tanks** | `FuelTanks(k)`: eta range, capacity, fill fraction | OW 5.3 t + MS 3.6 t per side | Wing mass shifts the bending frequency and the CG. |
| **Engines** | mass, position, **pylon frequency** (or stiffness) | 4 000 kg each; 3 Hz pitch | Engine/pylon modes can couple into BFF or wing flutter. |
| **Stiffness scaling** | `StiffnessScale.CB/MS/OW` (scales E,G on shells or EI,GJ on beams; **mass unchanged**) | 1 | Sweeps to find where instability enters the envelope. |
| **Structural damping** | `StructuralDamping` (% critical, `TABDMP1 CRIT`) | 0 (boundary); 1–2 % realistic | Positions the damping-zero crossing. |
| **Free-free BCs** | `KeepRigidBodyModes=true`, SUPORT at CG, `Symmetry` = sym/antisym | true, sym | **Needed for BFF.** Today's defaults drop the rigid modes (finding A1). |
| **Modal basis** | `NModes`, `FMax` | 40, 30 Hz | Rigid + about 30 elastic modes. |
| **Flight envelope** | altitudes, EAS range to beyond 1.15·V_D, **matched points** (M, ρ from altitude) | 0–11.9 km; 60–260 m/s EAS | Gives the flutter boundary per altitude. V_D ≈ 381 KEAS, M_D 0.89 (A320-like). |
| **Unsteady aero** | `ReducedFreqs` dense at low k; `MachList` for MKAERO; box size; `RefC` = MAC | k = 0.001…1.5; M = 0.2/0.5/0.7/0.78 | BFF and rigid modes sit at **low k** (≈ 0.02–0.3). |
| **Aero calibration** | `CLaTarget`, `XNPTarget` (or WKK factors); centre-body camber/reflex; tip washout | off; reflex 0.05; −3° | The DLM's Cmα sets the short period. Calibrate if CFD/VLM data exist. |
| **Controls** | elevon/aileron layout (§9.4); for ASE later: actuator bandwidth | as §9.4 | Trim, control effectiveness/reversal, and flight-dynamics inputs. |
| **Gusts** (dynamic behaviour) | 1-cos gust lengths, turbulence (existing `ads.nast.gust.*`) | CS-25 | Response of the flexible free-flying aircraft. |

**Reduced or removed:** detailed cabin packaging and seat counts. Pressure loading is kept as an
optional case (`IncludePressure=false`); it does not change the linear stability results.

---

## 3. Trial of the current formulation (traced from the code)

### 3.1 Shell path (`ShellStation` → `wing2fe` → `shell2fe` → `ads.fe.Shell`)

| # | Finding | Where | Consequence | Phase |
|---|---|---|---|---|
| F1 | `shell2fe` reads `Stations.SecondaryBeams`, which `baff.station.ShellStation.ShellStation` does not have (`baff.station.LBeam` is not in BAFF either). | `ads/.../private/shell2fe.m:311` | **Every shell wing errors.** | 1 |
| F2 | No mesher: `Wing.FromLETESweep_Shell` leaves `Nodes/Shell/SecondaryNodes` empty. | `baff/.../@Wing/Wing.m:367` | 0 shells and empty RBE3s, so Nastran stops with a fatal error. | 2 |
| F3 | The `SecondaryNodes (:,4)` layout (equal blocks per `SecondaryEta`) is implicit. | `shell2fe.m:245-253` | The mesher must emit equal-length rings, padded to multiples of 4. | 2 |
| F4 | One material (`Stations.Mat(1)`) for all shells. | `shell2fe.m:238,242` | Per-region materials and stiffness scaling are impossible. | 1 |
| F5 | `PSHELL` has 12I/T³ blank and no TS/T or NSM; the Matran `PSHELL` card has 6 fields. | `Shell.m:1161`, `Matran/.../PSHELL.m` | No PRSEUS bending ratio and **no smeared payload NSM**. | 1 |
| F6 | One PID per shell. | `Shell.m` `UpdateID` | Allow grouping. | 1 |
| F7 | `Shell.GetMass` returns 0; `Component.GetMass` ignores Shells and LBeams. | `Shell.m:1081`, `Component.m:25` | MATLAB mass, CG and inertia are wrong, so CG targeting fails. | 1 |
| F8 | `CQUAD4` only. | `Shell.m` | Fine with a structured mesh. | 7 |
| F9 | RBE3 `Ci=123456` on independent shell grids. | `shell2fe.m:286` | Use `Ci=123`. | 1 |
| F10 | SPLINE1 gets every attachment node of the wing for every panel; the centre body is splined to one hub per station plus rigid LE/TE bars. | `wing2fe.m:886-888` | Splines overlap across the kink, and the centre body's **chordwise bending is lost from the aero coupling**. That coupling matters for BFF. | 3 |
| F11 | `LeTeEdgeMode="drop"` default. | `wing2fe.m:812` | The 60°-swept centre body is expected to lose many LE/TE nodes (T2 measures this). | 3 |
| F12 | `ShellStation.interpolate` drops the mesh; `Duplicate` drops `ConstrainedEta`. | `ShellStation.m:53,85` | Interpolation silently loses the mesh. | 1 |
| F13 | ShellStation `ToBaff`/`FromBaff` are copies of the Beam IO. | `+ShellStation/ToBaff.m` | No `.baff` save/load for shells. | 7 |
| F14 | No `PLOAD4` or pressure element. | — | Pressure case unavailable (now optional). | 7 |
| F15 | `AeroSettings.SymXZ` is a logical. | `AeroSettings.m:78` | **Antisymmetric** half model impossible. | 3 |
| F16 | Examples pass the full area as `RefS` on half models; the MSC AEROS remark says REFS = half area. | `Examples/SimpleWing_sol144_example.m` | Check coefficient normalisation. | 3 |

### 3.2 Beam path (`baff.station.Beam` → `beam2fe` → `CBEAM`)

| # | Finding | Consequence |
|---|---|---|
| B1 | The only wingbox→beam reduction is `cast.size.WingBoxSizing.BeamCondensation` (called from `baff/tests/@TAW/ApplyWingParams.m`), and **`cast` is not in these repos**. | Re-implement it as `ads.bwb.boxCondensation` (§7.1). If your `shell=false` reduction is elsewhere, wrap that instead. |
| B2 | `beam2fe` writes PBEAM `I1=I(3,3)`, `I2=I(2,2)`; BAFF `Bar` uses `I(2,2)=∫z²` (flap) and `I(3,3)=∫y²`. | Convention: `I = diag([Iyy+Izz, Iyy_flap, Izz_chord])`. |
| B3 | `baff.station.Beam.HollowRect` swaps Iyy and Izz relative to `Bar`. | Fix before using it (Ph 5). |
| B4 | A single spanwise stick makes the 17 m centre body chordwise-rigid, and bay walls do not enter its section. | Add the centreline **spine** (§7.2). The centre-body pitch-plane bending takes part in BFF. |
| B5 | Shell RBE3 hubs form a natural 1-D node set. | Use them for shell-calibrated beams (§7.3). |

### 3.3 Aeroelastic-solution findings (new in v2)

| # | Finding | Where | Consequence | Phase |
|---|---|---|---|---|
| **A1** | `modeParamDefaults` writes `LFREQ`/`LFREQFL = FreqRange(1)`, and the default `FreqRange` is `[0.01 50]`. **Rigid-body modes at 0 Hz are removed from the modal flutter basis.** | `+nast/modeParamDefaults.m:12,14`; `Sol145.m:25` | **The default SOL145 cannot predict body-freedom flutter or the short period.** | 4 |
| A2 | `Sol103` defaults to `EigMethod='AGIV'`, which writes `EIGR F1=0`. Numerically slightly negative rigid roots may be missed. | `Sol103.m:19`, `eigCard.m` | Use `LAN` (EIGRL with V1 blank) for free-free runs. | 4 |
| A3 | `read_flutter_summary` assigns `M = machs(j)` and `RHO_RATIO = dens(j)` by point index. | `Matran/.../read_flutter_summary.m:62-63` | Correct only for **PKNL matched lists** (or single ρ and M). Use PKNL matched points (§10.3). | 4 |
| A4 | `Sol145.run` sets `CoM.ComponentNumbers = inv_dof(DoFs)` and `SupportNumbers = DoFs`; the symmetric default is `DoFs=35`. | `Sol145/run.m:133` | Antisymmetric needs `246`. The CoM grid must be an **independent** grid. | 4 |
| A5 | No export of the generalised matrices (QHH, MHH, KHH, BHH) from SOL145. The Sol144 `AJJ` DMAP alter is version-dependent. Matran `op4.read_matrix` reads **one real** matrix only. | `Sol144/write_main_bdf.m:27-36`; `Matran/.../@op4/read_matrix.m` | No state-space or flight-dynamics model yet. Add export and a multi/complex OP4 reader. | 6 |
| A6 | `Sol145.ReducedFreqs` default `[0.01 0.05 0.1 0.2 0.5 …]` is sparse at low k. | `Sol145.m:53` | Poor quasi-steady and BFF accuracy. Use a dense low-k set. | 4 |
| A7 | `Component` has no CG/inertia method, and `Mass.GetMass` starts with `m = size(obj)`, which returns `[m 1]` for a single mass (+1 kg). | `Component.m`, `Mass.m:33` | CG and I_yy reporting and static-margin targeting need new code. | 1 |
| A8 | No reader for SOL144 stability derivatives. | Matran `@f06` | Compute NP from AEROF resultants instead (§10.2). | 4 |

### 3.4 Phase-0 trial scripts (run locally)

```matlab
%% T1 — shell path as-is: expected to stop at shell2fe.m:311 (F1)
w = baff.Wing.FromLETESweep_Shell(10,2,[0 1],[0 0],[0 0],0.4,baff.Material.Aluminium);
[nodes,shells,secEta,secNodes] = tinyBoxMesh(w,4,5);  % 20-line helper using the §6.1 logic
st = w.Stations;  st.Nodes = nodes;  st.Shell = shells;
st.SecondaryEta = secEta;  st.SecondaryNodes = secNodes;  w.Stations = st;
w.A = ads.util.rotz(90);  w.Name = "trialShell";
m = baff.Model;  m.AddElement(w);  m.UpdateIdx();
fe = ads.baff.baff2fe(m);                               % F1 expected

%% T2 — beam path on the BWB planform: centre-body panels and LE/TE loss (F10/F11)
Y = [0 4.0 6.2 17.9];  c = [17 10 5 1.84];  b = Y(end);
w = baff.Wing.FromLETESweep(b,c(1),Y/b,[60.26 60.26 32 32],[0 -27.6 19.5 19.5], ...
        [0.544 0.5 0.375 0.375],baff.Material.Aluminium,ThicknessRatio=[0.17 0.17 0.14 0.11]);
% (if baff.station.Aero rejects a vector BeamLoc, pass 0.5 and set w.AeroStations.BeamLoc afterwards)
w.Stations = w.Stations.interpolate(linspace(0,1,41));
w.A = ads.util.rotz(90);  w.Offset = [9.25;0;0];  w.Name = "BWB";
m = baff.Model;  m.AddElement(w);  m.UpdateIdx();
for mode = ["drop","clip"]
    fe = ads.baff.baff2fe(m,ads.baff.BaffOpts(LeTeEdgeMode=mode));
    fprintf('%s: %d hubs, %d LE nodes, %d CAERO1, S_half=%.1f m^2\n', mode, ...
        nnz([fe.Points.Note]=="AttachmentNode"), nnz(endsWith([fe.Points.Name],"_LE")), ...
        numel(fe.AeroSurfaces), sum([fe.AeroSurfaces.Area]));
end

%% T3 — A1: rigid modes dropped from the flutter basis
%  Run any free-free SOL145 with defaults and open Source/flutter.bdf:
%  "PARAM LFREQFL 0.01" is present, and the f06 flutter summary has no zero-frequency roots.
```

---

## 4. Target aircraft: A320-class BWB baseline

### 4.1 Top level (gemini plan)

| Quantity | Value |
|---|---|
| Span / area / AR | 35.8 m / ≈ 221 m² (inner 141, outer 80) / 5.80 (outer 6.84) |
| MTOM / OEW / max payload / design fuel | 79 000 / 41 200 / 20 000 / 17 800 kg |
| Mass cases | **MTOM** 79.0 t; **MZFW** 61.2 t; **OEW + 2 t reserve** 43.2 t |
| Cruise | M 0.78, FL390 (ρ 0.316, V 230 m/s, q 8.38 kPa); C_L(MTOM) = 0.42, ≈ 0.35 at FL350 |
| Envelope (A320-like) | V_C 350 KEAS / M_C 0.82; **V_D 381 KEAS / M_D 0.89**; clearance to **1.15·V_D ≈ 225 m/s EAS** |

### 4.2 Half-planform (x aft, y starboard, z up; metres)

| Station | y | Chord | x_LE | x_TE | t/c | Role |
|---|---|---|---|---|---|---|
| 0 | 0.0 | 17.00 | 0.00 | 17.00 | 0.17 | centreline (symmetry plane) |
| 1 | 4.0 | 10.00 | 7.00 | 17.00 | 0.17 | cabin side wall |
| 2 | 6.2 | 5.00 | 10.85 | 15.85 | 0.14 | kink |
| 3 | 17.9 | 1.84 | 18.16 | 20.00 | 0.11 | tip |

* LE sweep 60.26°/60.26°/32°; TE sweep 0°/−27.6°/19.5°; outer-wing c/4 sweep 29.1°.
* MAC 9.23 m, x_LE,MAC 7.91 m, y_MAC 5.67 m. Estimated a.c. ≈ 10.2 m; the NP is computed in §10.2.
* One `baff.Wing` from centreline to tip: `eta = y/17.9` gives stations `[0 0.2235 0.3464 1]`;
  `BeamLoc = [0.544 0.500 0.375 0.375]` (box mid-chord); `Offset = [9.25;0;0]`; `A = ads.util.rotz(90)`.

### 4.3 Payload region and centre-body walls (stiffness)

* **Payload region** (home plate): width 8.0 m (side walls at y = ±4.0), front apex x = 3.0,
  front corner x = 8.5 at the side wall, straight rear bulkhead x = 15.5. Area 78 m², so the
  payload areal density at MTOM is 20 000/78 ≈ **256 kg/m²** before bias.
* Mid-section spars: (8.5, 15.5) at y = 4.0 → 12.5 %/62.5 % at the kink (11.475, 13.975).
  Outer-wing spars at 12.5 %/62.5 %.
* **Bay cases** (they change the centre-body bending and torsion stiffness, and hence the body modes in BFF):

| Case | Bays | Internal walls (y > 0) | Expected (Gern) |
|---|---|---|---|
| C1 | 1 | none | most flexible centre body |
| C2 | 3 | 1.333 | recommended below 270 pax |
| C3 | 5 | 0.80, 2.40 | stiffest centre body; small mass penalty |

### 4.4 Mass items (half model)

| Item | Half-model value | Model |
|---|---|---|
| Structure | from FE | shells (ρ·t·A) or beams (ρ·A + distributed non-beam mass) |
| Engine | 4 000 kg at (16.0, 2.5, 1.8); pylon with pitch frequency 3 Hz | CONM2 on a CBUSH/beam pylon |
| Cockpit | 453.5 kg at (2.0, 0, 0) | CONM2 on the symmetry plane |
| Payload | `PayloadFraction` × 10 000 kg, areal density over the payload region | PSHELL **NSM** on the centre-body lower skin (shell); lumped grid (beam) |
| Fuel | OW box ≤ 5.3 t, MS box ≤ 3.6 t, × fill fraction | NSM on tank lower skins (shell); baff distributed mass (beam) |
| Systems / secondary | `OEW/2 − structure − engine − cockpit` | area-weighted NSM over all skins |

---

## 5. Architecture

### 5.1 Files

```
ads/tbx/+ads/+bwb/                       (new package)
  BWBGeometry.m        planform, payload region, spars, bays; A320Class(nBays)
  BWBStructure.m       materials, gauges per region tag, PRSEUS 12I/T^3, stiffness scaling
  BWBMass.m            mass cases, distributed payload, fuel tanks, engines, CG/SM target
  BWBOpts.m            model form, mesh, aero, stability settings
  bwb2fe.m             entry point -> [fe, info]
  buildBaff.m          geometry -> baff.Model (one baff.Wing [+ spine] + masses + control surfaces)
  meshShellStation.m   structured CQUAD4 mesher -> ShellStation
  boxCondensation.m    thin-walled multi-cell section properties (beam reduction)
  spineSection.m       longitudinal multi-cell section across the bays
  identifyBeamFromShell.m  shell-calibrated EI/GJ per hub segment
  addSymmetryBCs.m     SPC 246 (sym) / 135 (antisym) on independent y = 0 grids
  applyDistributedMass.m   payload / fuel / systems as NSM (shell) or lumped grid (beam)
  massBudget.m         OEW top-up, CG targeting (payload bias), CoM/SUPORT grid, report
  neutralPoint.m       NP from two SOL144 runs (rigid or flexible)
  matchedPoints.m      EAS sweep -> (V, rho, M) per altitude
  findInstability.m    damping zero-crossings, classification (BFF / flutter / divergence)
  stabilitySweep.m     loops: altitude x mass case x SM x stiffness scale -> boundary table
  liftShare.m          centre-body vs outer-wing lift
ads/tbx/+ads/+aeroelastic/               (new package, model-independent)
  readGAF.m            OP4 -> Mhh, Bhh, Khh, Qhh(k) at each Mach
  rogerRFA.m           rational function approximation
  stateSpace.m         rigid + elastic + aero-lag state-space at (V, rho)
  rootLocus.m          eigenvalues vs V with root tracking
ads/Examples/BWB_A320_{build,sol103,np_sol144,bff_sol145,statespace,gust_sol146,bay_study}.m
ads/tests/bwb2feTest.m, tests/aeroelasticTest.m
```

### 5.2 Data flow

```
BWBGeometry ─┐
BWBStructure ├─> buildBaff ─> baff.Model ─> ads.baff.baff2fe ─> fe
BWBMass ─────┤   Shell: FromLETESweep_Shell + meshShellStation (-> shell2fe)
BWBOpts ─────┘   Beam : FromLETESweep + boxCondensation (+ spine)  (-> beam2fe)
                                   │
   addSymmetryBCs → applyDistributedMass → massBudget (CG/SM) → setPanelDensity → AeroSettings
                                   │
   SOL103 free-free → SOL144 NP/trim → SOL145 PKNL matched points (sym/antisym)
                                   │                         │
                         findInstability (BFF…)     GAF export → RFA → state-space → root loci / time response
```

Why **one `baff.Wing` from centreline to tip**: `element2fe` joins a child to its parent with a single
`RigidBar`, which is wrong between shell segments. With one wing, its `ShellStation` holds the whole
connected mesh and its `AeroStations` put CAERO1 panels on the centre body automatically.

### 5.3 Input classes (sketch)

```matlab
classdef BWBGeometry
    %BWBGEOMETRY Half-model planform (x aft, y starboard, z up) [m, deg]
    properties
        Y     (1,:) double = [0 4.0 6.2 17.9];
        Chord (1,:) double = [17.0 10.0 5.0 1.84];
        XLE   (1,:) double = [0 7.0 10.85 18.16];
        TC    (1,:) double = [0.17 0.17 0.14 0.11];
        Twist (1,:) double = [0 0 0 -3];
        BeamLoc (1,:) double = [0.544 0.500 0.375 0.375];
        PayloadWidth = 8.0;  PayloadApexX = 3.0;  RearBulkheadX = 15.5;  FrontCornerPc = 0.15;
        FrontSparPc = 0.125;  RearSparPc = 0.625;
        NBays (1,1) double {mustBeMember(NBays,[1 3 5])} = 3;
        AirfoilCB = baff.Airfoil.NACA(0,0,0.17);  AirfoilOW = baff.Airfoil.NACA(0,0,0.11);  % placeholders
    end
    properties (Dependent)
        HalfSpan, Area, MAC, XLEMAC, WallY, LESweep, TESweep
    end
    methods
        function b = get.HalfSpan(obj),  b = obj.Y(end);  end
        function S = get.Area(obj),      S = 2*trapz(obj.Y,obj.Chord);  end
        function c = get.MAC(obj)
            y = linspace(0,obj.HalfSpan,2001);  cc = interp1(obj.Y,obj.Chord,y);
            c = trapz(y,cc.^2)/trapz(y,cc);
        end
        function x = get.XLEMAC(obj)
            y = linspace(0,obj.HalfSpan,2001);  cc = interp1(obj.Y,obj.Chord,y);
            x = trapz(y,cc.*interp1(obj.Y,obj.XLE,y))/trapz(y,cc);
        end
        function y = get.WallY(obj)
            w = obj.PayloadWidth/obj.NBays;
            y = -obj.PayloadWidth/2 + w*(1:obj.NBays-1);  y = y(y > 1e-9);
        end
        function s = get.LESweep(obj), s = [atand(diff(obj.XLE)./diff(obj.Y)), 0];  end
        function s = get.TESweep(obj), s = [atand(diff(obj.XLE+obj.Chord)./diff(obj.Y)), 0];  end
        function [xf,xr] = BoxLines(obj,y)
            %front/rear structural lines: payload region -> mid section -> outer spars
            yc = obj.PayloadWidth/2;  xc = interp1(obj.Y,obj.XLE,yc) + obj.FrontCornerPc*interp1(obj.Y,obj.Chord,yc);
            xl = @(yy) interp1(obj.Y,obj.XLE,yy);  cl = @(yy) interp1(obj.Y,obj.Chord,yy);
            if y <= yc
                xf = obj.PayloadApexX + (xc-obj.PayloadApexX)*y/yc;   xr = obj.RearBulkheadX;
            elseif y <= obj.Y(3)
                t  = (y-yc)/(obj.Y(3)-yc);
                xf = xc + t*(xl(obj.Y(3)) + obj.FrontSparPc*cl(obj.Y(3)) - xc);
                xr = obj.RearBulkheadX + t*(xl(obj.Y(3)) + obj.RearSparPc*cl(obj.Y(3)) - obj.RearBulkheadX);
            else
                xf = xl(y) + obj.FrontSparPc*cl(y);   xr = xl(y) + obj.RearSparPc*cl(y);
            end
        end
        function [zu,zl] = Surface(obj,x,y)
            %OML heights; baff.Airfoil Ys are for unit thickness (NACA: max half-thickness 0.5), so
            %scale by t/c*c. Use symmetric sections here: camber inside Ys would also be scaled by t/c,
            %so aerodynamic camber goes in AeroSurface.CamberFcn instead.
            c = interp1(obj.Y,obj.Chord,y);  xi = (x - interp1(obj.Y,obj.XLE,y))/c;
            tc = interp1(obj.Y,obj.TC,y);   af = ads.util.tern(y <= obj.Y(3),obj.AirfoilCB,obj.AirfoilOW);
            zu = c*tc*interp1(af.Etas,af.Ys(:,1),xi,'pchip');
            zl = c*tc*interp1(af.Etas,af.Ys(:,2),xi,'pchip');
        end
        function r = Region(obj,y)
            if y < obj.PayloadWidth/2, r = "CB"; elseif y < obj.Y(3), r = "MS"; else, r = "OW"; end
        end
    end
    methods (Static)
        function obj = A320Class(nBays)
            obj = ads.bwb.BWBGeometry();  obj.NBays = nBays;
        end
    end
end
```

```matlab
classdef BWBMass
    properties
        MTOM = 79000;  OEW = 41200;  PayloadMax = 20000;  FuelDesign = 17800;  Reserve = 2000;
        Case string {mustBeMember(Case,["MTOM","MZFW","OEW","Custom"])} = "MTOM";
        PayloadFraction = 1;  FuelFraction = 1;           % used when Case == "Custom"
        PayloadBias = 0;                                    % NSM(x) = n0*(1 + PayloadBias*(x-xm)/L)
        FuelTanks = struct('Name',{"OW","MS"},'EtaRange',{[0.3464 0.86],[0.2235 0.3464]}, ...
                           'Capacity',{5300,3600});         % per half [kg]
        Engine  = struct('Mass',4000,'X',[16.0;2.5;1.8],'PylonFreq',3.0);
        Cockpit = struct('Mass',907,'X',[2.0;0;0]);
        CGTarget string {mustBeMember(CGTarget,["StaticMargin","X","None"])} = "StaticMargin";
        StaticMargin = 0.05;  XCG = 10.0;  IyyTarget = NaN;
        XNP = NaN;                                          % neutral point [m]; NaN -> a.c. estimate
    end
    methods
        function [mp,mf] = CaseFractions(obj)
            switch obj.Case
                case "MTOM", mp = 1; mf = 1;
                case "MZFW", mp = 1; mf = 0;
                case "OEW",  mp = 0; mf = obj.Reserve/obj.FuelDesign;
                otherwise,   mp = obj.PayloadFraction; mf = obj.FuelFraction;
            end
        end
    end
    methods (Static)
        function obj = A320Class(), obj = ads.bwb.BWBMass(); end
    end
end
```

```matlab
classdef BWBOpts
    properties
        % model form
        Shell logical = true;
        BeamModel  string {mustBeMember(BeamModel,["stick","cruciform"])} = "cruciform";
        BeamSource string {mustBeMember(BeamSource,["analytic","shell"])} = "analytic";
        Symmetry   string {mustBeMember(Symmetry,["sym","antisym","none"])} = "sym";
        % structural mesh / stiffness
        NChordStruct = 10;  NDepthStruct = 3;  SpanElemCB = 0.5;  SpanElemOW = 0.35;  RibPitch = 0.7;
        StiffnessScale = struct('CB',1,'MS',1,'OW',1);     % E,G (shell) or EI,GJ (beam); mass unchanged
        % aero
        AeroBoxSize = 0.5;  AeroBoxAR = 1.5;  SplineMode string = "skin";
        CamberCB = 0.05;  ReflexXi = 0.75;
        % stability
        ReducedFreqs = [0.001 0.005 0.01 0.02 0.035 0.05 0.075 0.1 0.15 0.2 0.3 0.45 0.65 1.0 1.5];
        MachList = [0.2 0.5 0.7 0.78];
        NModes = 40;  FMax = 30;  KeepRigidBodyModes logical = true;  StructuralDamping = 0;
        % optional loads
        IncludePressure logical = false;  CabinDeltaP = 59.3e3;  PressureFactor = 1.33;
    end
    methods
        function obj = BWBOpts(opts)
            arguments, opts.?ads.bwb.BWBOpts, end
            for p = string(fieldnames(opts))', obj.(p) = opts.(p); end
        end
    end
end
```

### 5.4 Entry point

```matlab
function [fe,info] = bwb2fe(geom,str,mass,opts)
%BWB2FE Nastran FE + DLM model of a free-flying BWB (half model by default).
arguments
    geom ads.bwb.BWBGeometry  = ads.bwb.BWBGeometry.A320Class(3)
    str  ads.bwb.BWBStructure = ads.bwb.BWBStructure.PRSEUS()
    mass ads.bwb.BWBMass      = ads.bwb.BWBMass.A320Class()
    opts ads.bwb.BWBOpts      = ads.bwb.BWBOpts()
end
model = ads.bwb.buildBaff(geom,str,mass,opts);        % wing (+spine), engine/pylon, cockpit, control surfaces
bOpts = ads.baff.BaffOpts(SplitBeamsAtChildren=false, LeTeEdgeMode="clip", AddEndRibs=true, ...
                          ShellSplineMode=opts.SplineMode);          % ShellSplineMode (new)
fe = ads.baff.baff2fe(model,bOpts);
ads.bwb.addSymmetryBCs(fe,opts.Symmetry);
ads.bwb.applyDistributedMass(fe,geom,mass,opts);      % payload + fuel + systems (NSM or lumped)
info = ads.bwb.massBudget(fe,geom,mass,opts);         % OEW top-up, CG targeting, CoM grid, report
ads.bwb.setPanelDensity(fe,opts.AeroBoxSize,opts.AeroBoxAR);
symxz = ads.util.tern(opts.Symmetry=="sym",1,ads.util.tern(opts.Symmetry=="antisym",-1,0));
fe.AeroSettings(1) = ads.fe.AeroSettings(geom.MAC,1.225,2*geom.HalfSpan,geom.Area/2,SymXZ=symxz);
info.Geometry = geom;  info.Opts = opts;
end
```

---

## 6. Shell path (`Shell = true`)

### 6.1 Structured mesher → `ShellStation`

Every wall lies on a mesh line (symmetry plane, internal walls, side wall, kink, ribs, tip), so the
whole mesh is `CQUAD4`.

```matlab
function st = meshShellStation(geom,str,opts,wing)
%MESHSHELLSTATION Structured CQUAD4 mesh (centre body + mid section + outer box) in wing LOCAL frame.
yS    = structStations(geom,opts);            % sorted y: 0, walls, side wall, kink, ribs, CS breaks, tip
isRib = isRibStation(geom,yS,opts);           % walls, side wall, kink, rib pitch, tip (not y = 0)
xi = linspace(0,1,opts.NChordStruct+1);  zeta = linspace(0,1,opts.NDepthStruct+1);
K = numel(yS);  J = numel(xi);  L = numel(zeta);
Xg = zeros(0,3);  nN = 0;  U = zeros(K,J);  Lo = zeros(K,J);  F = zeros(K,L);  R = zeros(K,L);  RibG = cell(K,1);
for k = 1:K
    [xf,xr] = geom.BoxLines(yS(k));   x = xf + xi*(xr-xf);   [zu,zl] = geom.Surface(x,yS(k));
    [Xg,nN,U(k,:)]  = addNodes(Xg,nN,[x(:), repmat(yS(k),J,1), zu(:)]);
    [Xg,nN,Lo(k,:)] = addNodes(Xg,nN,[x(:), repmat(yS(k),J,1), zl(:)]);
    zf = zu(1) + zeta(2:L-1)*(zl(1)-zu(1));   zr = zu(J) + zeta(2:L-1)*(zl(J)-zu(J));
    [Xg,nN,fi] = addNodes(Xg,nN,[repmat([x(1) yS(k)],L-2,1), zf(:)]);
    [Xg,nN,ri] = addNodes(Xg,nN,[repmat([x(J) yS(k)],L-2,1), zr(:)]);
    F(k,:) = [U(k,1) fi Lo(k,1)];   R(k,:) = [U(k,J) ri Lo(k,J)];
    if isRib(k)
        G = zeros(J,L);  G(:,1) = U(k,:)';  G(:,L) = Lo(k,:)';  G(1,:) = F(k,:);  G(J,:) = R(k,:);
        for j = 2:J-1
            z = zu(j) + zeta(2:L-1)*(zl(j)-zu(j));
            [Xg,nN,G(j,2:L-1)] = addNodes(Xg,nN,[repmat([x(j) yS(k)],L-2,1), z(:)]);
        end
        RibG{k} = G;
    end
end
Q = zeros(0,4);  T = strings(0,1);               % node order -> outward normals
for k = 1:K-1
    reg = geom.Region((yS(k)+yS(k+1))/2);
    for j = 1:J-1
        [Q,T] = push(Q,T,[U(k,j)  U(k,j+1)  U(k+1,j+1)  U(k+1,j)],  reg+"_UpperSkin");
        [Q,T] = push(Q,T,[Lo(k,j) Lo(k+1,j) Lo(k+1,j+1) Lo(k,j+1)], reg+"_LowerSkin");
    end
    for l = 1:L-1
        [Q,T] = push(Q,T,[F(k,l) F(k+1,l) F(k+1,l+1) F(k,l+1)], reg+"_FrontSpar");
        [Q,T] = push(Q,T,[R(k,l) R(k,l+1) R(k+1,l+1) R(k+1,l)], reg+"_RearSpar");
    end
end
for k = find(isRib(:)')
    G = RibG{k};  tag = ribTag(geom,yS(k));      % CB_InternalWall | CB_SideWall | MS_KinkRib | OW_Rib ...
    for j = 1:J-1, for l = 1:L-1
        [Q,T] = push(Q,T,[G(j,l) G(j+1,l) G(j+1,l+1) G(j,l+1)], tag);
    end, end
end
Xl = (wing.A.' * (Xg.' - wing.Offset(:))).';     % global -> wing local
shells = baff.station.ShellStation.Shell.empty;
for e = 1:size(Q,1)
    p = str.Props(T(e),opts.StiffnessScale);     % gauge, material (E,G scaled), BendRatio
    shells(end+1,1) = baff.station.ShellStation.Shell(Q(e,:)',p.Mat,p.t,"PSHELL", ...
                          Tag=T(e),BendRatio=p.BendRatio); %#ok<AGROW>
end
rings = arrayfun(@(k) [U(k,:), R(k,2:L-1), fliplr(Lo(k,:)), fliplr(F(k,2:L-1))],1:K,'UniformOutput',false);
st = wing.Stations;
st.Nodes = Xl;  st.Shell = shells;  st.SecondaryEta = yS/geom.HalfSpan;   % EtaDir(1,:) == 1
st.SecondaryNodes = packRings(rings);  st.SplineNodes = reshape(U.',[],1);
end

function [Xg,nN,idx] = addNodes(Xg,nN,P)
idx = nN + (1:size(P,1));  Xg(idx,:) = P;  nN = idx(end);
end
function [Q,T] = push(Q,T,q,t)
Q(end+1,:) = q;  T(end+1,1) = t;
end
function R = packRings(rings)
n = numel(rings{1});  n4 = 4*ceil(n/4);  R = zeros(0,4);
for k = 1:numel(rings)
    r = rings{k};  r = [r, repmat(r(end),1,n4-n)];  R = [R; reshape(r,4,[]).']; %#ok<AGROW>
end
end
```

At the default densities this gives about 1.9 k CQUAD4 (Gern used 2.5–3.5 k), with element aspect
ratio at or below ~4.

### 6.2 Properties per region tag

| Tag | Material (PSHELL) | t₀ [mm] | 12I/T³ |
|---|---|---|---|
| `CB_UpperSkin/LowerSkin/FrontSpar/RearSpar/SideWall` | PRSEUS smeared, QI IM7-8552: E 56.1 GPa, G 21.4 GPa, ν 0.31, ρ 1 578 | 6 (side wall 5) | `BendRatio_PRSEUS` |
| `CB_InternalWall` | QI CFRP | 4 | 1 |
| `MS_*` | QI CFRP | 5 / 5 / 3 | 1 |
| `OW_*` | QI CFRP | skin 8→3, spar 6→3, rib 3 | 1 |

* `BendRatio_PRSEUS = 12·I_panel/t_eff³` with `t_eff = (A_skin + A_str)/pitch`, from the Velicki
  panel dimensions. Use 1.0 until those are set.
* `StiffnessScale.(region)` multiplies E and G only, which leaves the mass unchanged.

### 6.3 Boundary conditions

```matlab
function addSymmetryBCs(fe,mode)
if mode == "none", return, end
dofs = ads.util.tern(mode=="sym",246,135);
dep  = [[fe.RigidBodyElements.REFGRID], [fe.RigidBars.Point2]];   % dependent grids (RBE3 ref, RBE2 GM)
for p = fe.Points(:)'
    if abs(p.GlobalPos(2)) < 1e-6 && ~any(p == dep)               % handle identity comparison
        fe.Constraints(end+1) = ads.fe.Constraint(p,dofs);
    end
end
end
```

Never SPC a grid that is dependent in an RBE2/RBE3 (hubs, LE/TE and mass-bar ends); Nastran stops
with a fatal error. The free-free CoM/SUPORT grid is the nearest independent structural grid to the
CG (§8.4).

---

## 7. Beam path (`Shell = false`): wingbox reduction

### 7.1 Multi-cell condensation

```matlab
function sec = boxCondensation(x,zU,zL,tU,tL,tW)
%BOXCONDENSATION thin-walled multi-cell section -> A, Iyy (int z^2), Izz (int x^2), J (Bredt-Batho)
nw = numel(x);  nc = nw-1;  seg = zeros(0,5);
for c = 1:nc
    seg(end+1,:) = [x(c) zU(c) x(c+1) zU(c+1) tU(c)]; %#ok<AGROW>
    seg(end+1,:) = [x(c) zL(c) x(c+1) zL(c+1) tL(c)]; %#ok<AGROW>
end
for w = 1:nw, seg(end+1,:) = [x(w) zL(w) x(w) zU(w) tW(w)]; end %#ok<AGROW>
dx = seg(:,3)-seg(:,1);  dz = seg(:,4)-seg(:,2);  Aw = hypot(dx,dz).*seg(:,5);
xm = (seg(:,1)+seg(:,3))/2;  zm = (seg(:,2)+seg(:,4))/2;
A = sum(Aw);  xc = sum(Aw.*xm)/A;  zc = sum(Aw.*zm)/A;
Iyy = sum(Aw.*((zm-zc).^2 + dz.^2/12));   Izz = sum(Aw.*((xm-xc).^2 + dx.^2/12));
Acell = zeros(nc,1);  D = zeros(nc);
for c = 1:nc
    hL = zU(c)-zL(c);  hR = zU(c+1)-zL(c+1);   Acell(c) = 0.5*(x(c+1)-x(c))*(hL+hR);
    D(c,c) = hypot(x(c+1)-x(c),zU(c+1)-zU(c))/tU(c) + hypot(x(c+1)-x(c),zL(c+1)-zL(c))/tL(c) ...
           + hL/tW(c) + hR/tW(c+1);
    if c > 1,  D(c,c-1) = -hL/tW(c);   end
    if c < nc, D(c,c+1) = -hR/tW(c+1); end
end
q = D \ (2*Acell);   J = 2*sum(Acell.*q);           % single cell -> 4A^2/(oint ds/t)
sec = struct('A',A,'Iyy',Iyy,'Izz',Izz,'J',J,'xc',xc,'zc',zc);
end
```

Use in `buildBaff` when `Shell=false`:

```matlab
w = baff.Wing.FromLETESweep(b,geom.Chord(1),geom.Y/b,geom.LESweep,geom.TESweep, ...
                            geom.BeamLoc,str.RefMat,ThicknessRatio=geom.TC);
w.Stations = w.Stations.interpolate(beamEtas(geom,opts));
for i = 1:w.Stations.N
    y = w.Stations.Eta(i)*b;   [xw,tW,tU,tL] = str.SpanwiseSection(geom,y);   [zu,zl] = geom.Surface(xw,y);
    s = ads.bwb.boxCondensation(xw,zu,zl,tU,tL,tW);
    k = opts.StiffnessScale.(geom.Region(y));                          % stiffness only
    w.Stations.A(i) = s.A;                                             % mass from rho*A (unscaled)
    w.Stations.I(:,:,i) = k*diag([s.Iyy+s.Izz, s.Iyy, s.Izz]);
    w.Stations.J(i) = k*s.J;
end
w.DistributeMass(str.NonBeamMass(geom),opts.NMassStations,"tag","bwb_nonbeam","Method","Regular");
```

### 7.2 Centreline spine (cruciform): the bay walls enter here

The spine is two `baff.Beam` children of the wing at `eta=0`: one forward to x = 3.0 and one aft to
x = 17.0. Each spine section is the cut across the payload width, with the side walls and internal
walls as webs, so it has `NBays` cells. **Halve everything in the half model**, because the spine lies
on the symmetry plane.

```matlab
function [A,I,J] = spineSection(geom,str,x)
yw = [-geom.PayloadWidth/2, -fliplr(geom.WallY), geom.WallY, geom.PayloadWidth/2];
yw = yw(arrayfun(@(y) x >= frontLineX(geom,abs(y)), yw));   % walls start behind the home-plate front
zu = zeros(size(yw));  zl = zu;
for k = 1:numel(yw), [zu(k),zl(k)] = geom.Surface(x,abs(yw(k))); end
nc = numel(yw)-1;
s = ads.bwb.boxCondensation(yw,zu,zl,str.t("CB_UpperSkin")*ones(1,nc),str.t("CB_LowerSkin")*ones(1,nc), ...
                            str.WallThickness(yw));
A = s.A/2;  I = diag([s.Iyy+s.Izz, s.Iyy, s.Izz])/2;  J = s.J/2;
end
```

The centre-body `SPLINE4` sets include the spine nodes, which gives pitch-plane flexibility in the aero
coupling. **Option B2 (Ph 7):** a full grillage built directly from `ads.fe` beams.

### 7.3 Shell-calibrated beam

Three SOL101 unit-load cases on the shell model, with the root hub clamped and no masses: tip normal
force, tip torque about the beam axis, and tip chordwise force. These give the 3×3 compliance per unit
length for each hub segment (bend–twist coupling included).

```matlab
for k = 1:nH-1
    e1 = Xh(:,k+1)-Xh(:,k);  ds = norm(e1);  e1 = e1/ds;
    e3 = cross(e1,chordDir(:,k));  e3 = e3/norm(e3);  e2 = cross(e3,e1);  Tk = [e1 e2 e3];
    Xm = (Xh(:,k)+Xh(:,k+1))/2;  M = zeros(3);  Th = zeros(3);
    for c = 1:3
        M(:,c)  = Tk.'*(cross(Xh(:,end)-Xm,Fc(:,c)) + Mc(:,c));   % internal moment at the segment middle
        Th(:,c) = Tk.'*(rot(:,k+1,c)-rot(:,k,c))/ds;              % twist rate and curvatures
    end
    C = Th/M;  Kseg = inv((C+C.')/2);
    GJ(k) = Kseg(1,1);  EIflap(k) = Kseg(2,2);  EIchord(k) = Kseg(3,3);
end
```

Set `BeamSource="shell"` to replace the analytic stations. Acceptance: analytic vs identified within
±15 % outboard of the kink.

---

## 8. Mass, distributed payload and inertia

### 8.1 Payload, fuel and systems as distributed mass

**Shell path.** PSHELL NSM (kg/m²) on the lower-skin elements whose centroid is inside the payload
polygon. Tank lower skins carry the fuel, and all skins carry the systems top-up.

**Beam path.** The same areal density is sampled on a grid and lumped as `ads.fe.Mass` on new grids,
each tied by `RigidBar` to the nearest beam or spine node.

```matlab
function applyDistributedMass(fe,geom,mass,opts)
[mp,mf] = mass.CaseFractions();
mPay = mp*mass.PayloadMax/2;                                     % half model
if opts.Shell
    sh = fe.Shells([fe.Shells.Label]=="CB_LowerSkin");
    [A,xc] = shellAreaCentroid(sh);                              % 1 x n area, 3 x n centroid (global)
    in = inPayloadRegion(geom,xc);  sh = sh(in);  A = A(in);  x = xc(1,in);
    [xm,Lx] = deal(mean(x),max(x)-min(x));
    w = 1 + mass.PayloadBias*(x-xm)/Lx;                           % fore/aft gradient (CG knob)
    n0 = mPay/sum(w.*A);
    for i = 1:numel(sh), sh(i).NSM = sh(i).NSM + n0*w(i); end
    for t = mass.FuelTanks                                       % fuel on the tank lower skins
        st = tankLowerSkins(fe,geom,t.EtaRange);  [At,~] = shellAreaCentroid(st);
        for i = 1:numel(st), st(i).NSM = st(i).NSM + mf*t.Capacity/sum(At); end
    end
else
    [xg,yg,mg] = sampleAreal(geom,mPay,mass.PayloadBias,[8 5]);  % 8 chordwise x 5 spanwise points
    lumpToNearest(fe,[xg;yg;floorZ(geom,xg,yg)],mg);             % ads.fe.Mass + RigidBar to nearest beam node
    for t = mass.FuelTanks
        [xt,yt,mt] = sampleTank(geom,t,mf);  lumpToNearest(fe,[xt;yt;0*xt],mt);
    end
end
end
```

### 8.2 OEW top-up and CG targeting

```matlab
function info = massBudget(fe,geom,mass,opts)
mp0 = fe.GetMassProperties();                                   % new (§12, A7)
[mpf,mff] = mass.CaseFractions();
mSys = mass.OEW/2 - mp0.Mass + mpf*mass.PayloadMax/2 + mff*sum([mass.FuelTanks.Capacity]);
% mp0 already contains structure + engine + cockpit + payload + fuel, so mSys = OEW/2 - (structure+engine+cockpit)
assert(mSys > 0,'bwb:mass','FE structure + fixed items exceed OEW/2 by %.0f kg',-mSys);
distributeSystemsNSM(fe,mSys);                                  % area-weighted over all skins / beams
if mass.CGTarget ~= "None"
    xnp = mass.XNP;                                              % from ads.bwb.neutralPoint (§10.2)
    if isnan(xnp), xnp = geom.XLEMAC + 0.25*geom.MAC; end        % first pass: a.c. estimate
    xT = ads.util.tern(mass.CGTarget=="X", mass.XCG, xnp - mass.StaticMargin*geom.MAC);
    solveBias = @(b) cgAfterBias(fe,geom,mass,b) - xT;
    try
        mass.PayloadBias = fzero(solveBias,[-1 1]);
    catch
        warning('bwb:cg','CG target %.2f m not reachable by payload bias alone: move fuel or add ballast',xT);
    end
    reapplyPayload(fe,geom,mass);                               % re-apply payload NSM with the new bias
end
info.PayloadBias = mass.PayloadBias;
info.Mass = fe.GetMassProperties();                             % mass, CG, inertia (half model)
info.CoM  = supportGrid(fe,info.Mass.CG);                       % nearest independent grid -> ads.fe.Constraint
fe.Constraints(end+1) = info.CoM;
end
```

If `fzero` finds no bias in [−1, 1], report it: the CG target cannot be met by payload redistribution
alone, so move fuel or add ballast.

### 8.3 Full-aircraft figures from the half model

Mass and I_yy double. The CG x and z are unchanged, and y = 0 by symmetry. I_xx and I_zz need the
mirror image: `2·(I_half + m_half·y_cg²)` with the parallel-axis term. Report all of them, since BFF
depends on I_yy/(m·MAC²).

---

## 9. Aero model (centre-body panels)

### 9.1 CAERO1 layout (half model, `AEROS SYMXZ=+1`, or −1 for antisymmetric)

| Macro-panel | y range | Chords | Chordwise boxes (Δx ≈ 0.5 m) | Spanwise boxes |
|---|---|---|---|---|
| Centre body (split at elevon breaks) | 0 → 4.0 | 17 → 10 | 34 | 8 |
| Mid section | 4.0 → 6.2 | 10 → 5 | 20 | 5 |
| Outer wing (split at elevon/aileron breaks) | 6.2 → 17.9 | 5 → 1.84 | 10 | 24 |

About 600 boxes, with `Δx ≤ 0.08·V_min/f_max` (0.53 m at 100 m/s and 15 Hz).

### 9.2 Camber and reflex (trim and Cm0) and twist

Add `CamberFcn` to `AeroSurface`, written into `W2GJ` with the twist (§12). Reflexed centre-body
camber `z/c = a·ξ(1−ξ)(ξ_r−ξ)` with a ≈ 0.05 and ξ_r = 0.75, tuned for Cm0 ≈ 0 about the CG, plus
−3° tip washout. The target lift share is centre body ≈ 38 %.

### 9.3 Splines

* **Beam path:** SPLINE4 per panel, restricted to nodes inside the panel span; centre-body panels also
  get the spine nodes.
* **Shell path:** `ShellSplineMode="skin"` uses the upper-skin grids inside each panel's span, which
  keeps the centre body's chordwise flexibility. There is no overlap across the kink.

### 9.4 Control surfaces

| Surface | y [m] | eta | Chord fraction |
|---|---|---|---|
| `ElevCB` | 1.0 → 4.0 | 0.056 → 0.2235 | 0.12 |
| `ElevMS` | 4.0 → 6.2 | 0.2235 → 0.3464 | 0.20 |
| `ElevOW` | 6.2 → 12.0 | 0.3464 → 0.670 | 0.25 |
| `Ail` | 12.0 → 16.5 | 0.670 → 0.922 | 0.25 |

`ElevCB` and `ElevMS` are linked to `ElevOW` through AELINK, so symmetric trim has two free variables
(ANGLEA and ElevOW). The ailerons are locked for the symmetric case.

---

## 10. Aeroelastic stability workflow: finding the instability

### 10.1 SOL103 free-free (symmetric and antisymmetric)

```matlab
s = ads.nast.Sol103();  s.EigMethod = 'LAN';  s.FreqRange = [0 opts.FMax];  s.LModes = opts.NModes;
s.UpdateID(IDs);
modes = s.run(fe,BinFolder=fullfile(bin,'s103'));
% acceptance: symmetric half model -> 3 rigid modes (T1, T3, R2) below 1e-3*f1; list the first 10 elastic modes
```

### 10.2 Neutral point and static margin (SOL144, rigid and flexible)

Two locked-trim runs at α = 0 and 1°, with the model restrained at the CoM grid:

* the **flexible, restrained** run uses the model as is;
* the **rigid** run uses `StiffnessScale = 1e3` on every region.

```matlab
function xnp = neutralPoint(fe,IDs,bin,flightCond)
F = zeros(2,1);  My = zeros(2,1);
for k = 1:2
    s = ads.nast.Sol144();  s.set_trim_locked(flightCond.V,flightCond.rho,flightCond.M);
    s.ANGLEA.Value = deg2rad(k-1);  s.CoM = flightCond.CoM;  s.isFree = false;   % restrained at CoM
    s.UpdateID(IDs);  s.run(fe,BinFolder=fullfile(bin,sprintf('np_%d',k)));
    h5 = mni.result.hdf5(fullfile(bin,sprintf('np_%d',k),'bin','sol144.h5'));
    af = h5.read_aero_force();
    pid = cell2mat(arrayfun(@(a) a.get_panelIDs(),fe.AeroSurfaces(:)','UniformOutput',false));
    Xc  = [fe.AeroSurfaces.CentroidsGlobal];                    % same order as pid
    [~,loc] = ismember(double(af(1).ID),pid);                   % map AEROF rows to boxes by ID
    F(k)  = sum(af(1).F(:,3));
    My(k) = sum(-Xc(1,loc)'.*af(1).F(:,3) + af(1).M(:,2));      % moment about x = 0 (x aft, z up)
end
xnp = -diff(My)/diff(F);                                        % x where dMy/dalpha = 0
end
```

Check the AEROF force reference points and the sign conventions against a flat-plate unit test (NP at
c/4 at low Mach). The static margin is then `SM = (x_NP − x_CG)/MAC`. Iterate §8.2 once with the
computed NP.

### 10.3 SOL145: matched points, rigid modes kept, symmetric and antisymmetric

```matlab
function [V,rho,M] = matchedPoints(h,Veas)
[rho1,a] = ads.util.atmos(h);   rho0 = ads.util.atmos(0);
V = Veas*sqrt(rho0/rho1);   M = V/a;   rho = rho1*ones(size(V));
end
```

```matlab
s = ads.nast.Sol145();
[s.V,s.rho,s.Mach] = ads.bwb.matchedPoints(h,linspace(60,260,41));   % EAS sweep to beyond 1.15*V_D
s.FlutterMethod = 'PKNL';                        % one-to-one (V, rho, M) lists (see A3)
s.ReducedMachs = opts.MachList;   s.ReducedFreqs = opts.ReducedFreqs;               % A6
s.LModes = opts.NModes;  s.FreqRange = [0 opts.FMax];  s.KeepRigidBodyModes = true; % A1 (new property)
s.ModalDampingPercentage = opts.StructuralDamping;  s.DampingFreqs = [0 opts.FMax];
s.set_free_free(info.CoM,opts.Symmetry);         % new helper: SUPORT 35 (sym) / 246 (antisym), A4
s.UpdateID(IDs);
res = s.run(fe,BinFolder=fullfile(bin,sprintf('s145_h%05.0f',h)));
inst = ads.bwb.findInstability(res,RigidModes=rigidModeNumbers(modes));
```

### 10.4 Finding the instability and classifying it

```matlab
function out = findInstability(res,opts)
%FINDINSTABILITY first damping zero-crossing of every root; BFF if the root starts as a rigid-body mode
arguments
    res struct                 % Sol145.run output: MODE, POINT, V, D, F, KF, CMPLX
    opts.gTol = 0
    opts.RigidModes = []       % mode numbers of the rigid-body roots (SOL103: f < 1e-3*f1)
    opts.MinFreq = 0.05        % Hz; below this a crossing is (quasi-)static divergence
end
out = struct('Mode',{},'V',{},'F',{},'Type',{});
for m = unique([res.MODE])
    r = res([res.MODE]==m);  [V,ix] = sort([r.V]);  g = [r(ix).D];  f = [r(ix).F];
    j = find(g(1:end-1) <= opts.gTol & g(2:end) > opts.gTol,1);
    if isempty(j), continue, end
    t = (opts.gTol-g(j))/(g(j+1)-g(j));   Vf = V(j)+t*(V(j+1)-V(j));   ff = f(j)+t*(f(j+1)-f(j));
    if ff < opts.MinFreq,                  type = "divergence";
    elseif ismember(m,opts.RigidModes),    type = "body-freedom flutter";
    else,                                  type = "elastic flutter";
    end
    out(end+1) = struct('Mode',m,'V',Vf,'F',ff,'Type',type); %#ok<AGROW>
end
if ~isempty(out), [~,i] = sort([out.V]); out = out(i); end
end
```

Additional evidence for BFF, to report alongside:

* the unstable root's frequency rises from ≈ 0 (short period) towards the first symmetric bending frequency;
* its complex eigenvector (`res(i).EigenVector`, already attached by `Sol145.run`) has a large pitch/plunge participation.

### 10.5 Sweeps: stability boundary maps

```matlab
function T = stabilitySweep(geom,str,mass,opts,grid)
%STABILITYSWEEP grid.h (altitudes), grid.Case, grid.SM, grid.Kscale -> table of first instabilities
T = table();
for cse = grid.Case, for sm = grid.SM, for ks = grid.Kscale
    mass.Case = cse;  mass.StaticMargin = sm;
    opts.StiffnessScale = struct('CB',ks,'MS',ks,'OW',ks);
    [fe,info] = ads.bwb.bwb2fe(geom,str,mass,opts);  fe = fe.Flatten();  IDs = fe.UpdateIDs();
    for h = grid.h
        inst = runSol145(fe,IDs,info,opts,h);           % §10.3
        if isempty(inst), first = struct('V',NaN,'F',NaN,'Type',"none"); else, first = inst(1); end
        Veas = first.V*sqrt(ads.util.atmos(h)/ads.util.atmos(0));
        T = [T; {cse,sm,ks,h,Veas,first.F,first.Type,info.Mass.Inertia(2,2)*2}]; %#ok<AGROW>
    end
end, end, end
T.Properties.VariableNames = {'Case','SM','Kscale','h','Veas_f','f_f','Type','Iyy_full'};
end
```

Deliverables per bay case (C1/C2/C3) × {shell, beam}:

* V_f (EAS) vs altitude, for sym and antisym;
* the instability type;
* the margin to 1.15·V_D;
* sensitivity of V_BFF to static margin, mass case, stiffness scale and I_yy.

---

## 11. Flight-dynamic behaviour: integrated rigid + elastic state-space

### 11.1 Export the generalised matrices from Nastran (SOL145)

Mirror the existing `Sol144.OutputAeroMatrices` DMAP pattern. Names and ALTER points are
**version-dependent**: print the FLUTTER subDMAP with `DIAG 14` once and adjust.

```matlab
% Sol145/write_main_bdf.m (inside the Executive Control section), when obj.OutputGAF (new) is true
println(fid,'ASSIGN OUTPUT4=''../bin/GAF.op4'',FORMATTED,UNIT=13');   % before SOL
...
println(fid,'SOL 145');
println(fid,'COMPILE FLUTTER');
println(fid,'ALTER ''FA1'' $');                 % after QHHL is formed, before the flutter solution (check)
println(fid,'OUTPUT4 MHH,BHH,KHH,QHHL,//0/13///8 $');
```

`QHHL` holds Q_hh for every (M, k) pair in MKAERO1, in MKAERO order. Read it with the new Matran
multi-matrix OP4 reader (§12) and split it per Mach:

```matlab
function gaf = readGAF(op4file,machs,kfreqs,nModes)
mats = mni.result.op4(op4file).read_matrices();          % new: struct array (Name, Data), complex aware
get  = @(n) mats(strcmpi({mats.Name},n)).Data;
Mhh = get('MHH');  Bhh = get('BHH');  Khh = get('KHH');  QL = get('QHHL');
nk = numel(kfreqs);  nM = numel(machs);
Q = reshape(QL,nModes,nModes,nk,nM);                     % verify the column ordering once (unit test)
gaf = struct('M',Mhh,'B',Bhh,'K',Khh,'Q',Q,'k',kfreqs,'Mach',machs);
end
```

### 11.2 Roger RFA and state-space

```matlab
function rfa = rogerRFA(k,Q,beta)
%ROGERRFA Q(p) ~ A0 + A1 p + A2 p^2 + sum_l A_{l+2} p/(p+beta_l),  p = i k  (one Mach number)
p = 1i*k(:);  nk = numel(k);  n = size(Q,1);
Phi = [ones(nk,1), p, p.^2, p./(p+beta(:).')];   Pr = [real(Phi); imag(Phi)];
A = zeros(n,n,size(Phi,2));
for r = 1:n
    for c = 1:n
        q = squeeze(Q(r,c,:));   A(r,c,:) = Pr \ [real(q); imag(q)];
    end
end
rfa = struct('A',A,'beta',beta(:).','k',k);
end
```

```matlab
function sys = stateSpace(gaf,rfa,V,rho,bref)
%STATESPACE x = [q; qdot; x_lag]  with  M qdd + B qd + K q = qdyn*[A0 q + A1 (b/V) qd + A2 (b/V)^2 qdd + sum A_l x_l]
n = size(gaf.M,1);  nL = numel(rfa.beta);  qd = 0.5*rho*V^2;  A = rfa.A;
Mb = gaf.M - qd*(bref/V)^2*A(:,:,3);   Bb = gaf.B - qd*(bref/V)*A(:,:,2);   Kb = gaf.K - qd*A(:,:,1);
Mi = Mb \ eye(n);
As = zeros(2*n+nL*n);
As(1:n,n+1:2*n) = eye(n);
As(n+1:2*n,1:n) = -Mi*Kb;   As(n+1:2*n,n+1:2*n) = -Mi*Bb;
for l = 1:nL
    ix = 2*n+(l-1)*n+(1:n);
    As(n+1:2*n,ix) = qd*Mi*A(:,:,3+l);
    As(ix,n+1:2*n) = eye(n);   As(ix,ix) = -(V/bref)*rfa.beta(l)*eye(n);
end
sys = struct('A',As,'lambda',eig(As),'V',V,'rho',rho);
end
```

* `bref = MAC/2`, matching the reduced frequency Nastran uses (k = ω·REFC/(2V)).
* Lag roots: `beta = 1.7*max(k)*((1:nL)/(nL+1)).^2` with `nL = 4`.
* Root loci against V give the short period and the BFF coalescence; **cross-check the crossing speed
  against PKNL** (acceptance: within 3 %).
* Time responses: control step via an added control-surface mode, and gusts via `SOL146` (existing
  `ads.nast.Sol146` + `gust.OneMC`/`Turb`) on the same free-free model.
* Phugoid needs a speed DOF and gravity terms that are not in the DLM modal model. Add them as a
  classical augmentation in Ph 7.

---

## 12. Repository edits, with code

### 12.1 ads

**(a) `tbx/+ads/+nast/modeParamDefaults.m`: keep the rigid-body modes (A1).**

```matlab
function defaults = modeParamDefaults(lModes,freqRange,opts)
arguments
    lModes
    freqRange
    opts.KeepRigid logical = false          % true: no LFREQ/LFREQFL, so 0 Hz modes stay in the basis
end
if isempty(freqRange), fr = {[],[]}; else, fr = num2cell(freqRange(1:2)); end
lo = fr{1};  if opts.KeepRigid, lo = []; end
defaults = {'LMODES','i',lModes; 'LMODESFL','i',lModes; ...
            'LFREQ','r',lo; 'HFREQ','r',fr{2}; 'LFREQFL','r',lo; 'HFREQFL','r',fr{2}};
end
```

**(b) `tbx/+ads/+nast/@Sol145/Sol145.m`: new properties and a free-free helper (A1, A4, A5).**

```matlab
properties
    KeepRigidBodyModes logical = false;   % pass-through to modeParamDefaults(KeepRigid=...)
    OutputGAF logical = false;            % write MHH/BHH/KHH/QHHL to ../bin/GAF.op4 (section 11.1)
end
methods
    function set_free_free(obj,CoM,symmetry)
        arguments
            obj
            CoM ads.fe.Constraint
            symmetry string {mustBeMember(symmetry,["sym","antisym","none"])} = "sym"
        end
        obj.isFree = true;  obj.CoM = CoM;  obj.KeepRigidBodyModes = true;
        switch symmetry
            case "sym",     obj.DoFs = 35;       % plunge + pitch (surge SPC'd at the CoM grid)
            case "antisym", obj.DoFs = 246;      % lateral + roll + yaw
            otherwise,      obj.DoFs = 123456;
        end
    end
end
```

In `write_flutter.m` and `write_main_bdf.m`, replace both calls:

```matlab
ads.nast.modeParamDefaults(obj.LModes,obj.FreqRange,KeepRigid=obj.KeepRigidBodyModes)
```

In `write_main_bdf.m` (Executive Control), add the §11.1 lines behind `if obj.OutputGAF`.

**(c) `tbx/+ads/+nast/@Sol103/Sol103.m`: same `KeepRigidBodyModes` property. Recommend
`EigMethod='LAN'` for free-free runs (A2).** Pass `KeepRigid` in `Sol103/write_main_bdf.m:80`.

**(d) `tbx/+ads/+nast/@Sol101/*`: `Params` struct (INREL for unit loads) and ForceIDs from `Pressures`.**

```matlab
% Sol101.m
Params struct = struct();
% Sol101/write_main_bdf.m, after the generic PARAMs
ads.nast.writeExtraParams(fid,obj.Params,params);      % same helper as Sol145
% Sol101/run.m and Sol144/run.m, after the Forces/Moments block
if ~isempty(feModel.Pressures)
    obj.ForceIDs = [obj.ForceIDs; [feModel.Pressures.ID]'];
end
```

**(e) `tbx/+ads/+fe/@Component/Component.m`: mass properties, shells in `GetMass`, pressures (F7, A7).**

```matlab
properties
    Pressures (:,1) ads.fe.Pressure = ads.fe.Pressure.empty;   % new element class (optional loads)
end
methods
    function m = GetMass(obj)
        m = zeros(size(obj));
        for i = 1:numel(obj)
            m(i) = sum(obj(i).Beams.GetMass) + sum(obj(i).Masses.GetMass) + sum(obj(i).Shells.GetMass) ...
                 + sum(obj(i).LBeams.GetMass) + sum(obj(i).Components.GetMass);
        end
    end
    function mp = GetMassProperties(obj)
        %GETMASSPROPERTIES total mass, CG and inertia about the CG (global axes); aero added mass excluded
        [m,X,Ic] = obj.massItems();
        M = sum(m);  cg = X*m(:)/M;  I = sum(Ic,3);
        for k = 1:numel(m)
            d = X(:,k)-cg;  I = I + m(k)*((d.'*d)*eye(3) - d*d.');
        end
        mp = struct('Mass',M,'CG',cg,'Inertia',I);
    end
    function [m,X,Ic] = massItems(obj)
        m = zeros(1,0);  X = zeros(3,0);  Ic = zeros(3,3,0);
        for c = obj(:)'
            for e = c.Masses(:)'
                m(end+1) = e.mass;  X(:,end+1) = e.Point.GlobalPos;  Ic(:,:,end+1) = e.InertiaTensor; %#ok<AGROW>
            end
            for e = c.Inertias(:)'                         % 6x6 at a grid -> mass, CG offset, own inertia
                M6 = e.InertiaTensor;  mi = M6(1,1);
                if mi <= 0, continue, end                  % skip aero added-mass entries (translational only)
                S = M6(4:6,1:3)/mi;  d = [S(3,2); S(1,3); S(2,1)];
                m(end+1) = mi;  X(:,end+1) = e.Point.GlobalPos + d;                                  %#ok<AGROW>
                Ic(:,:,end+1) = M6(4:6,4:6) - mi*((d.'*d)*eye(3) - d*d.');                           %#ok<AGROW>
            end
            for e = c.Beams(:)'
                P = [e.Stations.Point];  m(end+1) = e.GetMass();  X(:,end+1) = mean([P.GlobalPos],2); %#ok<AGROW>
                Ic(:,:,end+1) = zeros(3);                                                            %#ok<AGROW>
            end
            for e = c.Shells(:)'
                m(end+1) = e.GetMass();  X(:,end+1) = mean([e.G.GlobalPos],2);  Ic(:,:,end+1) = zeros(3); %#ok<AGROW>
            end
            if ~isempty(c.Components)
                [m2,X2,I2] = c.Components.massItems();  m = [m m2];  X = [X X2];  Ic = cat(3,Ic,I2);
            end
        end
    end
end
```

Also add a unit test: a single `ads.fe.Mass` gives `GetMass == mass`. Fix `Mass.GetMass` to start
with `m = zeros(size(obj));` (A7).

**(f) `tbx/+ads/+baff/private/shell2fe.m`: guard, per-shell materials, `Ci`, labels, spline nodes (F1, F4, F9, F10).**

```matlab
mats = [shells.Mat];
[~,~,im] = unique(arrayfun(@(m) m.Hash,mats),'stable');
feMats = ads.fe.Material.empty;
for m = 1:max(im), feMats(m,1) = ads.fe.Material.FromBaffMat(mats(find(im==m,1))); end
fe.Materials = [fe.Materials; feMats];
for i = 1:numel(shells)
    fe.Shells(end+1) = ads.fe.Shell.FromBaffStations(shells(i),fe.Points(shells(i).G),feMats(im(i)),shells(i).Thickness);
end
...
Ci = 123;                                                        % was 123456
...
if isprop(obj.Stations,'SecondaryBeams') && ~isempty(obj.Stations.SecondaryBeams)   % was unguarded
...
if isprop(obj.Stations,'SplineNodes') && ~isempty(obj.Stations.SplineNodes)
    [fe.Points(obj.Stations.SplineNodes).Note] = deal("SplineNode");
end
```

**(g) `tbx/+ads/+fe/Shell.m`: NSM, 12I/T³, labels, grouped PIDs, mass (F5–F7).**

```matlab
properties
    NSM double = 0;  BendRatio double = 1;  TST double = [];
    Label string = "";          % from baff Shell.Tag (Component.UpdateTag does not touch it)
    PropertyGroup string = "";  % same group -> same PSHELL
end
function m = GetMass(obj)
    m = zeros(size(obj));
    for i = 1:numel(obj)
        X = [obj(i).G.GlobalPos];
        m(i) = 0.5*norm(cross(X(:,3)-X(:,1),X(:,4)-X(:,2)))*(obj(i).Thickness*obj(i).Mat.rho + obj(i).NSM);
    end
end
function ids = UpdateID(obj,ids)
    grp = containers.Map('KeyType','char','ValueType','double');
    for i = 1:numel(obj)
        obj(i).EID = ids.EID;  ids.EID = ids.EID + 1;  g = char(obj(i).PropertyGroup);
        if isempty(g),          obj(i).PID = ids.PID;  ids.PID = ids.PID + 1;
        elseif isKey(grp,g),    obj(i).PID = grp(g);
        else,                   obj(i).PID = ids.PID;  grp(g) = ids.PID;  ids.PID = ids.PID + 1;
        end
    end
end
function ExportToPSHELL(obj,fid)
    mni.printing.bdf.writeComment(fid,"PSHELL : Defines the properties of a SHELL element.");
    mni.printing.bdf.writeColumnDelimiter(fid,"long")
    [~,iu] = unique([obj.PID],'stable');
    for i = iu(:)'
        c = mni.printing.cards.PSHELL(obj(i).PID,obj(i).Mat.ID,obj(i).Thickness,obj(i).Mat.ID, ...
                obj(i).BendRatio,obj(i).Mat.ID,TST=obj(i).TST,NSM=obj(i).NSM);
        c.LongFormat = obj(i).ExportLongFormat;  c.writeToFile(fid);
    end
end
% FromBaffStations: pass Tag/BendRatio/NSM
obj = ads.fe.Shell(G,Mat,Thickness,"ExportType",st.ExportType,"ply",PlyDef);
obj.Label = st.Tag;  obj.BendRatio = st.BendRatio;  obj.NSM = st.NSM;
```

A shared PID also shares NSM. When payload NSM varies element by element, leave `PropertyGroup`
empty on those shells.

**(h) `tbx/+ads/+fe/AeroSurface.m`: panel size and camber downwash (§9).**

```matlab
properties
    CamberFcn = [];                       % handle xi -> dz/dx of the camber line (x aft, z up)
end
function SetPanelSize(obj,dx,AR)
    for i = 1:numel(obj)
        cMax = max(obj(i).Chords);   obj(i).nChord = max(4,ceil(cMax/dx));
        span = norm(obj(i).Points(:,2)-obj(i).Points(:,1));
        obj(i).nSpan = max(1,ceil(span/(AR*cMax/obj(i).nChord)));
    end
end
% get_twists: per surface i, BEFORE the "if X4(1) < 0" sign flip
if ~isempty(obj(i).CamberFcn)
    xc = obj(i).EtaChord(1:end-1) + 0.75*diff(obj(i).EtaChord);
    angles{i} = angles{i} - rad2deg(atan(repmat(reshape(obj(i).CamberFcn(xc),[],1),obj(i).nSpan,1))).';
end
```

**(i) `tbx/+ads/+fe/AeroSettings.m`: signed symmetry (F15).**

```matlab
SymXZ double {mustBeMember(SymXZ,[-1 0 1])} = 0;    % was logical; true/false map to 1/0
% constructor: obj.SymXZ = double(opts.SymXZ);
% Export: write SYMXZ = obj.SymXZ (0 written as 0)
```

**(j) `tbx/+ads/+baff/BaffOpts.m` and `private/wing2fe.m`: spline modes (F10).**

```matlab
% BaffOpts.m
ShellSplineMode string {mustBeMember(ShellSplineMode,["hub","segment","skin"])} = "hub";
% wing2fe.m, replacing lines 886-888
if SplineType == 1
    mode = string(getOpt(baffOpts,'ShellSplineMode',"hub"));  tol = 1e-6*obj.EtaLength;
    for i = 1:numel(fe.AeroSurfaces)
        switch mode
            case "hub",     pts = fe.Points(idxA);
            case "segment", pts = inSpan(fe.Points(idxA),st.Eta(i),st.Eta(i+1),obj.EtaLength,tol);
            case "skin",    pts = inSpan(fe.Points([fe.Points.Note]=="SplineNode"),st.Eta(i),st.Eta(i+1),obj.EtaLength,tol);
        end
        fe.AeroSurfaces(i).StructuralPoints = pts;
    end
end
function p = inSpan(p,e1,e2,L,tol)
X = [p.X];  p = p(X(1,:) >= e1*L-tol & X(1,:) <= e2*L+tol);     % local x = spanwise (no dihedral)
end
```

**(k) New files:** the `+ads/+bwb` package (§5–§10), the `+ads/+aeroelastic` package (§11),
`+ads/+fe/Pressure.m` (optional, §12.3), the examples and the tests.

### 12.2 baff

**(a) `+station/+ShellStation/ShellStation.m`: properties, mesh-preserving interpolate, Duplicate, horzcat (F1, F12).**

```matlab
properties
    SecondaryBeams = [];              % baff.station.LBeam array if/when merged from your fork
    SplineNodes (:,1) double = [];    % node indices used for "skin" aero splines
end
% interpolate(): after the EtaDir/StationDir/Mat lines
% (the mesh is in physical coordinates, independent of the station etas)
out.Nodes = obj.Nodes;  out.Shell = obj.Shell;  out.SplineNodes = obj.SplineNodes;
out.SecondaryEta = obj.SecondaryEta;  out.SecondaryNodes = obj.SecondaryNodes;
out.ConstrainedEta = obj.ConstrainedEta;  out.ConstrainedNodes = obj.ConstrainedNodes;
out.SecondaryBeams = obj.SecondaryBeams;
% Duplicate(): add ConstrainedEta=obj.ConstrainedEta to the constructor call
% horzcat(): offset node indices of each appended mesh
off = size(obj.Nodes,1);  sh = varargin{i}.Shell;
for s = 1:numel(sh), sh(s).G = sh(s).G + off; end
obj.Nodes = [obj.Nodes; varargin{i}.Nodes];   obj.Shell = [obj.Shell; sh];
obj.SecondaryNodes = [obj.SecondaryNodes; varargin{i}.SecondaryNodes + off];
obj.SplineNodes    = [obj.SplineNodes;    varargin{i}.SplineNodes + off];
```

**(b) `+station/+ShellStation/Shell.m`: bending ratio and NSM.**

```matlab
properties
    BendRatio double = 1;   % PSHELL 12I/T^3 (PRSEUS smeared bending)
    NSM double = 0;         % kg/m^2
end
% constructor: add opts.BendRatio = 1; opts.NSM = 0;  then  obj.BendRatio = opts.BendRatio;  obj.NSM = opts.NSM;
```

**(c) `+station/@Beam/Beam.m`: fix the `HollowRect` Iyy/Izz swap (B3), consistent with `Bar`.**

```matlab
Iyy = (width*height^3 - (width-2*thickness)*(height-2*thickness)^3)/12;   % int z^2 (flap), as in Bar
Izz = (height*width^3 - (height-2*thickness)*(width-2*thickness)^3)/12;   % int y^2
```

This changes results for existing `HollowRect` users; call it out in `changelog.txt`.

**(d) Ph 7:** real ShellStation `ToBaff`/`FromBaff`/`TemplateHdf5` (F13), with a per-wing group
because the mesh size differs per wing.

### 12.3 Matran

**(a) `tbx/+mni/+printing/+cards/PSHELL.m`: optional TS/T and NSM (backward compatible).**

```matlab
properties, PID; MID1; T; MID2; I12; MID3; TST; NSM; end
function obj = PSHELL(PID,MID1,T,MID2,I12,MID3,opts)
    arguments
        PID (1,1) double {mustBePositive}
        MID1 (1,1) double {mustBePositive}
        T (1,1) double {mustBePositive}
        MID2 (1,1) double {mustBePositive}
        I12 (:,1) double {mustBePositive}
        MID3 (1,1) double {mustBePositive}
        opts.TST (:,1) double = []
        opts.NSM (:,1) double = []
    end
    obj.PID = PID; obj.MID1 = MID1; obj.T = T; obj.MID2 = MID2; obj.I12 = I12; obj.MID3 = MID3;
    obj.TST = opts.TST;  obj.NSM = opts.NSM;  obj.Name = 'PSHELL';
end
function writeToFile(obj,fid,varargin)
    writeToFile@mni.printing.cards.BaseCard(obj,fid,varargin{:})
    obj.fprint_nas(fid,'iiririrr',{obj.PID,obj.MID1,obj.T,obj.MID2,obj.I12,obj.MID3,obj.TST,obj.NSM});
end
```

**(b) `tbx/+mni/+result/@op4/read_matrices.m` *(new)*: every matrix in a formatted OP4, real or complex (A5).**

```matlab
function mats = read_matrices(obj)
%READ_MATRICES all matrices in a formatted OP4 file -> struct array (Name, Data)
txt = splitlines(fileread(obj.filepath));  i = 1;  mats = struct('Name',{},'Data',{});
while i <= numel(txt)
    h = txt{i};
    if strlength(strtrim(h)) == 0, i = i+1; continue, end
    hd = sscanf(h(1:32),'%d');                      % NCOL NROW FORM TYPE (formatted OP4 header)
    ncol = hd(1);  nrow = abs(hd(2));  typ = hd(4);  name = strtrim(h(33:min(40,end)));
    isC = any(typ == [3 4]);  D = zeros(nrow,ncol);  i = i+1;
    while true
        rec = sscanf(txt{i},'%d',3);  i = i+1;       % ICOL IROW NW
        if rec(1) > ncol, i = i+1; break, end        % terminating record + its single value line
        vals = [];
        while numel(vals) < rec(3)
            vals = [vals; sscanf(strrep(txt{i},'D','E'),'%f')]; i = i+1; %#ok<AGROW>
        end
        if isC, v = vals(1:2:end) + 1i*vals(2:2:end); else, v = vals; end
        D(rec(2)+(0:numel(v)-1),rec(1)) = v;
    end
    mats(end+1) = struct('Name',name,'Data',D); %#ok<AGROW>
end
end
```

Check the header field widths and the terminating record against a known OP4 written by the
existing Sol144 `AJJ` alter, and add a unit test with a small real and a small complex matrix.

**(c) `tbx/+mni/+printing/+cards/PLOAD4.m` *(new, optional pressure case)*.**

```matlab
classdef PLOAD4 < mni.printing.cards.BaseCard
    properties, SID; EID; P; end
    methods
        function obj = PLOAD4(SID,EID,P)
            arguments, SID (1,1) double; EID (1,1) double; P (1,1) double; end
            obj.Name = 'PLOAD4';  obj.SID = SID;  obj.EID = EID;  obj.P = P;
        end
        function writeToFile(obj,fid,varargin)
            writeToFile@mni.printing.cards.BaseCard(obj,fid,varargin{:})
            obj.fprint_nas(fid,'iir',{obj.SID,obj.EID,obj.P});
        end
    end
end
```

The matching `ads.fe.Pressure` element loops over its shells and writes one `PLOAD4` per `EID`, with
the load-set `ID` taken from `ids.SID`.

---

## 13. Phases and acceptance

| Phase | Content | Acceptance |
|---|---|---|
| **0** | Trials T1–T3 (§3.4) | F1 and A1 reproduced; T2 prints S_half ≈ 110.5 m² |
| **1** | Shell foundations + mass properties (§12.1 e–g, §12.2 a–b, §12.3 a) | T1 builds and exports; PSHELL has 12I/T³ and NSM; RBE3 `Ci=123`; `GetMassProperties` matches hand calculations (point masses, one shell, one beam) |
| **2** | Geometry, mesher, `bwb2fe` (shell) | Areas within 1 %; walls at the §4.3 y values; outward normals; C1/C2/C3 build and export |
| **3** | Aero (panel size, camber, spline modes, controls, SYMXZ ±1) | Σ CAERO area = S/2; no spline point outside its panel span; *(Nastran)* rigid SOL144 runs |
| **4** | Distributed mass, CG targeting, free-free, NP, SOL145 settings (§12.1 a–d) | Mass = case mass/2 ± 0.5 %; CG = target ± 0.05 m; *(Nastran)* SOL103 gives 3 rigid modes ≈ 0 Hz; **flutter.bdf has no LFREQFL, and the summary contains roots that start at ≈ 0 Hz**; NP unit test on a flat plate |
| **5** | Beam path (condensation, spine, calibration, `HollowRect` fix) | Single cell = 4A²/∮ds/t; textbook two-cell case; *(Nastran)* identified vs analytic within ±15 % outboard; beam vs shell first sym bending within 10 % |
| **6** | Stability study: `stabilitySweep` over C1/C2/C3 × shell/beam × {MTOM, MZFW, OEW} × SM {0, 0.05, 0.10} × Kscale {0.5, 1, 2}; GAF export → RFA → state-space | Boundary tables and plots; BFF identified where present; state-space and PKNL crossing speeds within 3 % |
| **7** (optional) | Phugoid augmentation, gust/control time responses, grillage B2, ShellStation H5 IO, pressure case, sizing loop, PCOMP tailoring | case-specific |

Unit-test skeleton:

```matlab
classdef bwb2feTest < matlab.unittest.TestCase
    properties (TestParameter)
        nBays = {1,3,5};  isShell = {true,false};
    end
    methods (Test)
        function buildsAndExports(tc,nBays,isShell)
            g = ads.bwb.BWBGeometry.A320Class(nBays);
            [fe,info] = ads.bwb.bwb2fe(g,ads.bwb.BWBStructure.PRSEUS(),ads.bwb.BWBMass.A320Class(), ...
                                       ads.bwb.BWBOpts(Shell=isShell));
            tc.verifyEqual(sum([fe.AeroSurfaces.Area]),g.Area/2,'RelTol',0.01);
            tc.verifyEqual(info.Mass.Mass,79000/2,'RelTol',0.005);
            fe = fe.Flatten();  fe.UpdateIDs();  f = [tempname '.bdf'];  fe.Export(f);
            tc.verifyTrue(isfile(f));
        end
        function wallsOnMesh(tc,nBays)
            g  = ads.bwb.BWBGeometry.A320Class(nBays);
            fe = ads.bwb.bwb2fe(g,ads.bwb.BWBStructure.PRSEUS(),ads.bwb.BWBMass.A320Class(),ads.bwb.BWBOpts(Shell=true));
            yw = arrayfun(@(s) s.G(1).GlobalPos(2),fe.Shells([fe.Shells.Label]=="CB_InternalWall"));
            yw = uniquetol(yw,1e-6);
            tc.verifyEqual(numel(yw),numel(g.WallY));
            tc.verifyEqual(sort(yw(:))',sort(g.WallY),'AbsTol',1e-6);
        end
        function rigidModesKept(tc)
            d = ads.nast.modeParamDefaults(40,[0.01 30],KeepRigid=true);
            tc.verifyEmpty(d{strcmp(d(:,1),'LFREQFL'),3});
        end
    end
end
```

---

## 14. Risks and open questions

1. **DLM Cmα accuracy** decides the short period, and so the BFF speed. Calibrate NP/CLα against VLM
   or CFD if available (WKK or `XNPTarget`). Report results against static margin rather than one
   point value.
2. **Rigid-body modes:** SUPORT at an independent grid near the CG, and LFREQ removed. Check that
   ground-check and rigid-mode frequencies are ≈ 0 before trusting BFF results.
3. **Half-model limits:** symmetric BFF is fully captured. Lateral coupling (dutch roll, tailless yaw)
   needs the antisymmetric model, and yaw stability needs vertical surfaces (winglets) in the aero
   model: add them as vertical CAERO1 panels if they exist in the design.
4. **Beam vs shell in the centre body:** the spine (cruciform) is an approximation. Use the shell model
   (or B2) as the reference for body modes.
5. **Transonic range:** DLM is uncorrected above about M 0.8. State this in the clearance margins.
6. **Version-dependent DMAP** for GAF export (§11.1). Verify it with `DIAG 14` for your Nastran version.
7. **Your fork:** merge any `LBeam`/`SecondaryBeams` or `shell=false` code from your fork before Phase 1.

---

## Appendix: formulas

* Bredt–Batho: `J = 4A²/∮ds/t`; multi-cell `D·q = 2A·Gθ'`, `J = 2ΣA_i q_i`.
* NP from two locked runs: `x_NP = −ΔM_y/ΔF_z` about x = 0; `SM = (x_NP − x_CG)/MAC`.
* Matched point: `V = V_EAS·sqrt(ρ0/ρ(h))`, `M = V/a(h)`.
* Reduced frequency (Nastran AERO): `k = ω·REFC/(2V)`, with REFC = MAC = 9.23 m, so `bref = 4.6 m`.
* Roger RFA: `Q(p) = A0 + A1 p + A2 p² + Σ A_{l+2} p/(p+β_l)`, `p = ik`; lag state `ẋ_l = q̇ − (V/b)β_l x_l`.
* DLM box size: `Δx ≤ 0.08·V/f_max`.
* QI IM7-8552 `[0/±45/90]s`: E = 56.1 GPa, G = 21.4 GPa, ν = 0.31, ρ = 1 578 kg/m³.
