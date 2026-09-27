# `bwb2fe` — Blended-Wing-Body FE generation for ADS (implementation plan)

> **Purpose.** This is a working plan for Claude Code (or a developer) to add a
> `bwb2fe` capability to **ADS**, with the supporting edits in **BAFF** and
> **Matran (mni)**. It generates an MSC Nastran model of an **A320-class BWB** in
> one of two forms:
>
> * **Shell path** (`Shell=true`): a fully defined wingbox-like primary structure
>   of `CQUAD4`/`PSHELL` elements (cabin pressure vessel + mid section + outer
>   wing box), routed through the existing `shell2fe`.
> * **Beam path** (`Shell=false`): a 1-D beam idealisation whose section
>   properties come from a **wingbox reduction** (thin-walled multi-cell
>   condensation), optionally **calibrated against the shell model**.
>
> In both paths the **centre body carries DLM (`CAERO1`) panels**. It holds about
> 64 % of the planform area, so unlike an A320 fuselage it cannot be left out of
> the aero model.
>
> Three structural cases are defined: **1-bay, 3-bay and 5-bay** cabins (Gern 2012).
>
> Status: **plan only — no repository code has been changed.** The "trial" of the
> current shell and beam paths (§2) was done by **reading and tracing the code**.
> MATLAB and Nastran were not available where this plan was written, so Phase 0
> repeats the trials on a machine that has them.

---

## 0. How to use this document (Claude Code working agreement)

1. Work **phase by phase** (§10). Each phase lists the files it touches and its
   acceptance checks. Do not start a phase until the previous phase's checks pass.
2. MATLAB ≥ R2022a and MSC Nastran must be available locally. After each phase run
   `runtests('tests')`. Nastran-dependent tests are tagged `"Nastran"` so they
   can be excluded when Nastran is not present.
3. Repositories and branch: `frasacchi/ads`, `frasacchi/baff`, `frasacchi/Matran`,
   all on `claude/vigilant-hamilton-kxm445`. Keep BAFF changes geometry-only and
   put FE-specific logic in ADS (see the repo CLAUDE.md files).
4. Every new card or element needs a unit test that exports a BDF and checks the
   text (see existing `tests/baff2feTest.m`).
5. Code snippets below are **sketches** against the current APIs (checked against
   the source). Names marked *(new)* do not exist yet.

---

## 1. Sources and what each one contributes

| Source | What we take |
|---|---|
| **Gern, "Finite Element Based HWB Centerbody Structural Optimization and Weight Prediction" (NASA LaRC, 20120008184) — key literature** | Three components: **centre body, mid section, outboard wing**. Spars in the mid section and outer wing at **12.5 % / 62.5 %** chord. **"Home-plate"** cabin (Nickol & McCullers). **1/3/5-bay** options: 1-bay is fast but gives unrealistic pressure displacements; 3- and 5-bay give displacement relief; a 4-bay layout is rejected because of the centreline wall. All-`CQUAD4` model with front/rear spars, skins, side walls and internal walls (2.5–3.5 k elements). **PRSEUS stiffness via the `PSHELL` 12I/T³ entry.** DLM `CAERO` panels from sliced OML, with twist and camber as fixed downwash, splined to the front and rear spars. Load cases **2.5 g, −1.0 g, 1.33 P** with safety factor 1.5. Symmetric **half model**. Aft body not modelled; cockpit 2 000 lb. For fewer than ~270 pax the cabin layout decides the wall arrangement, and **3-bay is the practical choice**. |
| **Joseph et al., "MER for Conceptual Design of BWB Cabin with Advanced Structures" (NASA Ames, SciTech)** | Cabin parameterisation from `A_CB, FR=b_CB/ℓ_CB, θ_CB, SR=b_CB/b` (Eqs 1–7). **2P (20 psi) internal pressure is the critical case**, plus a 2.5 g × 1.5 manoeuvre. Triangular lift on the centre body (⅓ of the lift). Outer-wing shear and moment applied at the junction from an elliptic load (Eqs 20–27). IM7-8552 and PRSEUS properties (Tables 3–5). A 5-bay cabin is used throughout (no weight difference below 300 pax). The **MER gives a weight cross-check** for our FE mass. |
| **Ikeda & Bil, "Aerodynamic Performance of a BWB" (ICAS 2006)** | The Bradley cabin-weight regression `W = K_s·0.316422·TOGW^0.166552·S_cab^1.061158`, and component weight trends. Used only as a sanity cross-check. |
| **"gemini first plan.txt"** | The A320neo targets and the BWB sizing used here: b = 35.8 m, S ≈ 220 m² (140 m² inner / 80 m² outer), AR_ext 6.84, MTOM 79 t, OEW 41.2 t, payload 20 t, fuel 17.8 t, lift share ≈ 38 % centre body / 62 % outer wing, CAERO1 + SPLINE per segment with **no spline overlap across the kink**, SOL 144/145 set-up, AELINK-geared elevons. |
| Origin chat (claude.ai share link) | **Could not be read.** The link returned only a company information page. This plan is built from the prompt text and the four attachments. |

---

## 2. Trial of the current formulation (traced from the code)

### 2.1 Shell path (`baff.Wing` + `ShellStation` → `wing2fe` → `shell2fe` → `ads.fe.Shell`)

| # | Finding | Where | Consequence | Fixed in |
|---|---|---|---|---|
| F1 | `shell2fe` reads `obj.Stations.SecondaryBeams`, but `baff.station.ShellStation.ShellStation` has no such property, and `baff.station.LBeam` does not exist in BAFF (it probably lives only in a local fork). | `ads/.../private/shell2fe.m:311` | **Every shell wing errors** ("Unrecognized property 'SecondaryBeams'") before `Etas` is returned. | Ph 1 |
| F2 | Nothing generates a mesh. `Wing.FromLETESweep_Shell` makes a `ShellStation` with empty `Nodes/Shell/SecondaryNodes`. | `baff/.../@Wing/Wing.m:367` | 0 shells. The RBE3 hubs get no independent grids, so Nastran fails fatally. **A mesher is mandatory.** | Ph 2 |
| F3 | `SecondaryNodes` is `(:,4)` and read as `numel(SecondaryEta)` blocks of equal size, but no layout is documented. | `shell2fe.m:245-253` | A mesher must emit rings of equal length per station, padded to a multiple of 4. | Ph 2 |
| F4 | A single material, `Stations.Mat(1)`, is used for every shell; `shells(i).Mat` is ignored. | `shell2fe.m:238,242` | Skins, PRSEUS bulkheads, internal walls and ribs cannot have different materials. | Ph 1 |
| F5 | `PSHELL` is written with MID1=MID2=MID3, **12I/T³ left blank, and no TS/T or NSM**. The Matran `PSHELL` card has only 6 fields. | `ads/.../Shell.m:1161`, `Matran/.../PSHELL.m` | Neither Gern's PRSEUS bending ratio nor smeared non-structural mass can be represented. | Ph 1 |
| F6 | Each shell gets its own PID. | `Shell.m` `UpdateID` | Acceptable for sizing, but 2–5 k PSHELLs. Add optional grouping. | Ph 1 |
| F7 | `Shell.GetMass` returns 0 with a warning. `Component.GetMass` ignores `Shells` and `LBeams`. | `Shell.m:1081`, `Component.m:25` | MATLAB-side mass/CG budget is wrong for shell models (Nastran itself is fine). | Ph 1 |
| F8 | `ads.fe.Shell` supports `CQUAD4` only (`G (4,1)`). Matran already has `CTRIA3`. | `Shell.m` | Fine if the mesh stays structured (plan below). `CTRIA3` is needed only for later transitions. | Ph 7 |
| F9 | RBE3 hubs use `REFC=123456` **and `Ci=123456`** on the independent skin grids. | `shell2fe.m:284-286` | MSC recommends translational `Ci=123`. Rotations of shell grids (drilling DOF) degrade conditioning. | Ph 1 |
| F10 | With `SplineType==1`, **every** attachment node of the whole wing goes into **every** panel's SPLINE1 set. The centre body is splined to one RBE3 hub per station plus rigid LE/TE bars. | `wing2fe.m:886-888` | Splines overlap across the kink (the gemini warning). The 17 m centre-body chord is **chordwise-rigid** in the aero coupling. | Ph 3 |
| F11 | The default `LeTeEdgeMode="drop"` rejects LE/TE bars whose beam-normal plane leaves through the root chord. | `wing2fe.m:812` | On a 60°-swept, 17 m-chord centre body, many stations are expected to lose their LE/TE nodes (T2 measures this). Use `"clip"` or streamwise ribs. | Ph 3 |
| F12 | `ShellStation.interpolate` drops `Nodes/Shell` (TODO). `Duplicate` drops `ConstrainedEta`. | `ShellStation.m:53,85` | Any code that interpolates stations silently loses the mesh. | Ph 1 |
| F13 | `ShellStation` `ToBaff`/`FromBaff` are copies of the *Beam* station IO (they write `obj.A/I/J`, and `FromBaff` returns `baff.station.Beam`). | `baff/.../+ShellStation/ToBaff.m`, `FromBaff.m` | Shell BWBs cannot be saved to or loaded from `.baff` HDF5. | Ph 1 |
| F14 | No pressure-load card (`PLOAD4`) in Matran, and no pressure element in ADS. | — | **The 1.33P/2P cabin case, which sizes the centre body (Gern Fig 16, Joseph), cannot be run.** | Ph 4 |
| F15 | `AeroSettings.SymXZ` is a logical. | `AeroSettings.m:78` | An antisymmetric half model (`SYMXZ=-1`) cannot be written. | Ph 3 |
| F16 | The examples pass the **full** area as `RefS` on half models. The MSC AEROS remark says REFB = full span, **REFS = half area for half-span models**. | `Examples/SimpleWing_sol144_example.m` | Check coefficient normalisation (verify in the QRG for your version). | Ph 3 |

### 2.2 Beam path (`baff.Wing` + `baff.station.Beam` → `wing2fe` → `beam2fe` → `CBEAM/PBEAM`)

| # | Finding | Consequence |
|---|---|---|
| B1 | The only wingbox→beam reduction in these repos is `cast.size.WingBoxSizing.BeamCondensation`, called from `baff/tests/@TAW/ApplyWingParams.m`. The TAW geometry puts spars at 15/65 % and sets box height = t/c·c·mean(airfoil thickness at the spars). **`cast` is not in these repos.** | The BWB beam path needs a self-contained `ads.bwb.boxCondensation` *(new)*. If your `shell=false` reduction lives somewhere else (a local fork), point Claude at it and §6.1 will wrap it instead. |
| B2 | `beam2fe` itself is sound. It writes CBEAM with A, I, J per station plus DMIG, and PBEAM `I1=I(3,3)`, `I2=I(2,2)`. Baff `Bar` uses `I(2,2)=∫z²dA` (flap) and `I(3,3)=∫y²dA` (chordwise). | Use that convention: `I = diag([Iyy+Izz, Iyy_flap, Izz_chord])`. |
| B3 | `baff.station.Beam.HollowRect` computes `Iyy = h·w³/12`, which **swaps Iyy and Izz** relative to `Bar`. | Do not use `HollowRect` for wingboxes until it is fixed (BAFF edit, Ph 5). |
| B4 | A single spanwise stick through a 17 m-chord centre body with rigid LE/TE bars makes the centre body chordwise-rigid. The internal walls are parallel to the spanwise section cut, so **bay count has no effect on the stick stiffness**. | Add a **longitudinal spine** (cruciform stick). Its multi-cell section *is* set by the bay walls (§6.2). |
| B5 | Shell hubs (RBE3 reference nodes at `SecondaryEta`) already form a natural 1-D node set. | Use them for **shell-calibrated beam identification** (§6.3): the beam path is then checked against the shell path. |

### 2.3 Phase-0 trial scripts (run locally to confirm §2.1/§2.2)

```matlab
%% T1 — shell path as-is: expected to stop at shell2fe.m:311 (F1)
w = baff.Wing.FromLETESweep_Shell(10,2,[0 1],[0 0],[0 0],0.4,baff.Material.Aluminium);
[nodes,shells,secEta,secNodes] = tinyBoxMesh(w,4,5);   % 4 chordwise x 5 spanwise box (local helper, §5.1 logic)
st = w.Stations;  st.Nodes = nodes;  st.Shell = shells;
st.SecondaryEta = secEta;  st.SecondaryNodes = secNodes;  w.Stations = st;
w.A = ads.util.rotz(90);  w.Name = "trialShell";
m = baff.Model;  m.AddElement(w);  m.UpdateIdx();
fe = ads.baff.baff2fe(m);                              % F1 error expected here
% after the Ph-1 guard: fe.Flatten; fe.UpdateIDs; fe.Export('trial_shell.bdf') and inspect the PSHELL/RBE3 cards

%% T2 — beam path on the BWB planform: aero panels on the centre body and LE/TE node loss (F11)
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
```

The pass criterion for T2 is `S_half` ≈ 110.5 m², i.e. the centre-body panels exist and the planform is right. With `"drop"`, the centre-body LE count is expected to be well below the hub count.

---

## 3. Target aircraft: A320-class BWB baseline

### 3.1 Top-level targets (gemini plan, Tables 1–3)

| Quantity | Value | Note |
|---|---|---|
| Span b | 35.8 m | ICAO Code C (A320neo) |
| Planform area S | ≈ 221 m² (inner 141 / outer 80) | A320's 122.4 m² cannot hold the cabin (volumetric paradox) |
| AR total / outer | 5.80 / 6.84 | |
| MTOM / OEW / max payload / design fuel | 79 000 / 41 200 / 20 000 / 17 800 kg | MTOM = OEW + payload + fuel |
| Cruise | M 0.78, FL390 (ρ = 0.316 kg/m³, V = 230 m/s, q = 8.38 kPa) | **C_L(MTOM) = 0.42**, which is high for a BWB; at FL350 it is ≈ 0.35. Treat the cruise altitude as a parameter. |
| Lift share target | centre body ≈ 38 %, outer ≈ 62 % | Needs reflex camber (§7.2) |
| Cabin ΔP | 8.6 psi = 59.3 kPa. **1.33P = 78.9 kPa limit** (Gern), 118 kPa ultimate | Joseph uses 2P; both are options |

### 3.2 Derived half-planform (x aft, y starboard, z up; metres)

These values satisfy the gemini areas and spans to within 1 %.

| Station | y | Chord | x_LE | x_TE | t/c | Role |
|---|---|---|---|---|---|---|
| 0 | 0.0 | 17.00 | 0.00 | 17.00 | 0.17 | centreline (symmetry plane) |
| 1 | 4.0 | 10.00 | 7.00 | 17.00 | 0.17 | **cabin side wall** (= W_f/2) |
| 2 | 6.2 | 5.00 | 10.85 | 15.85 | 0.14 | **kink**: end of mid section |
| 3 | 17.9 | 1.84 | 18.16 | 20.00 | 0.11 | tip |

* LE sweep: 60.26° (centre body and transition), 32° (outer); c/4 sweep of the outer wing is 29.1°.
  TE sweep: 0°, −27.6° (forward-swept transition), 19.5°.
* Areas per side: 54.0 + 16.5 (inner, = 70.5) and 40.0 (outer). **S = 221.0 m², AR = 5.80**, AR_ext = 6.84.
* MAC = 9.23 m, x_LE,MAC = 7.91 m, y_MAC = 5.67 m. Estimated a.c. ≈ 10.2 m; initial CG target 9.9–10.1 m
  (to be updated from the rigid SOL144 neutral point).
* Eta mapping for one `baff.Wing` running from centreline to tip: `eta = y/17.9`, so the stations are `[0 0.2235 0.3464 1]`.
* Beam line (box mid-chord): `BeamLoc = [0.544 0.500 0.375 0.375]`. Wing `Offset = [9.25;0;0]`, `A = ads.util.rotz(90)`.

### 3.3 Pressurised cabin ("home plate") and structural lines

| Item | Value |
|---|---|
| Cabin width W_f | 8.0 m (side walls at y = ±4.0) |
| Home-plate apex (front bulkhead at centreline) | x = 3.0 m. The cockpit sits ahead of it and is lumped as 907 kg (2 000 lb, Gern). |
| Front-bulkhead corner at the side wall | x = 7.0 + 0.15·10 = 8.5 m, giving θ_CB = 54° (Joseph definition) |
| Rear bulkhead (straight) | x = 15.5 m, giving XL_p = 12.5 m and XL_w = 7.0 m |
| **Cabin floor area** | **78 m²** (0.52 m²/pax at 150 pax: high-density single class; this is **tight**) |
| Max cabin depth | 0.17·17 = 2.89 m at the centreline, ≈ 1.7 m at the side wall (packaging to be checked in OpenVSP) |
| Mid-section spars | from (8.5, 15.5) at y = 4.0 to 12.5 %/62.5 % at the kink: x = 11.475 / 13.975 |
| Outer-wing spars | 12.5 % / 62.5 % chord (Gern) |
| Joseph parameters | A_CB = 840 ft², FR = 0.64, θ_CB = 54°, SR = 0.223 (**below the MER's 1 750 ft² calibration range, so treat it as extrapolation**) |
| Weight cross-checks | Joseph MER ×1.06×1.2 ≈ **5.1 t** cabin structure (without floors). Bradley with K_s = 1 gives 1.36 t, and the Ikeda scale factor K_s ≈ 5.7 gives ≈ 7.7 t. The target band after sizing is **~5–8 t**. |

### 3.4 The three structural cases (Gern Fig 8)

| Case | Bays | Internal walls (half model, y > 0) | Bay width | Expected behaviour (Gern/Joseph) |
|---|---|---|---|---|
| **C1** | 1 | none, only the side wall at 4.0 | 8.0 m | Fast weight estimate. **Pressure deflections unrealistic**, and displacement constraints cannot be used. |
| **C2** | 3 | y = 1.333 | 2.667 m | **Recommended for < 270 pax.** Significant displacement relief. |
| **C3** | 5 | y = 0.80, 2.40 | 1.60 m | At this size, little or no mass benefit over 3-bay once fully stressed (Gern Fig 22, Joseph). |

Odd bay counts put a bay (not a wall) on the centreline, which is why 4-bay is excluded.

### 3.5 Mass items (per half model unless noted)

| Item | Mass | Placement |
|---|---|---|
| Primary structure | from the FE model (ρ·t·A + NSM) | shells or beams |
| Engines (2 × LEAP-1A-class, installed) | 4 000 kg each; half model: 1 × 4 000 | x ≈ 16.0, y = 2.5, z = +1.8 m (over the aft body) |
| Cockpit and nose | 907 kg total, so 453.5 on the symmetry plane | x ≈ 2.0 |
| Payload (MTOM case) | 20 000 total, 10 000 per half | grid of CONM2 per bay × row at floor height, attached with RBE3 |
| Fuel | 17 800 total, 8 900 per half: outer box ≈ 5.3 t (usable ≈ 6.5–7 m³), mid-section box ≈ 3.6 t | recomputed from box volume by `ads.bwb.fuelVolume` *(new)* |
| Systems, furnishing, secondary structure | `OEW/2 − structure − engine − cockpit` | smeared NSM (PSHELL NSM, or baff distributed mass on the beam path) |

---

## 4. Architecture of `bwb2fe`

### 4.1 Where it lives

`bwb2fe` builds a BAFF model and then **reuses** `ads.baff.baff2fe`. In the shell path this goes through `wing2fe → shell2fe`; in the beam path through `wing2fe → beam2fe`. BWB-specific pre- and post-processing (mesher, section reduction, pressure, symmetry, mass budget) goes in a new package:

```
ads/tbx/+ads/+bwb/                (new package)
  BWBGeometry.m        planform, cabin home-plate, spars, bays; A320Class(nBays)
  BWBStructure.m       materials (MAT1/MAT8), gauges per region tag, PRSEUS 12I/T^3, NSM
  BWBMass.m            payload, fuel, engines, cockpit, OEW target, CG target
  BWBOpts.m            Shell, BeamModel, Symmetry, mesh and aero density, spline mode, load options
  bwb2fe.m             entry point  -> [fe, info]
  buildBaff.m          geometry -> baff.Model (one baff.Wing + spine beams + masses + control surfaces)
  meshShellStation.m   structured CQUAD4 mesher -> baff.station.ShellStation.ShellStation
  boxCondensation.m    thin-walled multi-cell section -> A, Iyy, Izz, J (beam reduction)
  spineSections.m      longitudinal multi-cell sections across the bays (cruciform beam path)
  identifyBeamFromShell.m   shell-calibrated EI/GJ per hub segment (SOL101 unit loads)
  addSymmetryBCs.m     SPC on y = 0 independent grids (246 sym / 135 antisym)
  addCabinPressure.m   ads.fe.Pressure on cabin skins, bulkheads and side walls (by shell Label)
  setPanelDensity.m    per-panel box size (centre body vs outer wing)
  massBudget.m         NSM top-up to OEW, CG/inertia report, SUPORT/CoM node
  fuelVolume.m         usable box volume per region
  liftShare.m          SOL144 post-processing: centre-body vs outer-wing lift
ads/Examples/
  BWB_A320_build_example.m        build, draw, export (all six models)
  BWB_A320_sol103_example.m       free-free modes, symmetric and antisymmetric
  BWB_A320_sol144_example.m       1 g / 2.5 g / -1 g trim, lift share
  BWB_A320_sol145_example.m       flutter, including body-freedom
  BWB_A320_pressure_example.m     SOL101 1.33P with inertia relief (shell only)
  BWB_A320_bay_study.m            C1/C2/C3 x shell/beam matrix -> tables and plots
ads/tests/bwb2feTest.m            parameterised nBays x Shell (+ "Nastran"-tagged runs)
```

### 4.2 Data flow

```
BWBGeometry ─┐
BWBStructure ├─> buildBaff ──> baff.Model ──> ads.baff.baff2fe ──> fe (ads.fe.Component)
BWBMass ─────┤      │ Shell=true : Wing.FromLETESweep_Shell + meshShellStation   (shell2fe)
BWBOpts ─────┘      │ Shell=false: Wing.FromLETESweep + boxCondensation (+spine) (beam2fe)
                    │ + baff.ControlSurface (elevons, aileron) + baff.Mass (payload/fuel/engine/cockpit)
                    ▼
      post: addSymmetryBCs → [addCabinPressure] → setPanelDensity → massBudget → AeroSettings
                    ▼
      ads.nast.Sol101 / Sol103 / Sol144 / Sol145 (existing classes, small edits in §9)
```

**Why one `baff.Wing` from the centreline to the tip?**
`element2fe` joins a child to its parent with **one** `RigidBar` between the closest points. That is fine for masses and pylons but wrong between shell segments: the side-wall joint must be continuous. A single wing avoids the problem:

* its `ShellStation` holds the whole connected mesh (cabin, mid section and outer box), and
* its `AeroStations` put `CAERO1` panels on the centre body automatically, which is the key aero requirement.

### 4.3 Entry point (sketch)

```matlab
function [fe,info] = bwb2fe(geom,str,mass,opts)
%BWB2FE Nastran FE + DLM model of a BWB (half model by default).
%   opts.Shell = true  -> PSHELL wingbox via shell2fe
%   opts.Shell = false -> beam reduction via beam2fe (stick or cruciform)
arguments
    geom ads.bwb.BWBGeometry  = ads.bwb.BWBGeometry.A320Class(3)
    str  ads.bwb.BWBStructure = ads.bwb.BWBStructure.PRSEUS()
    mass ads.bwb.BWBMass      = ads.bwb.BWBMass.A320Class()
    opts ads.bwb.BWBOpts      = ads.bwb.BWBOpts()
end
geom.validate();                                          % Y(2)==CabinWidth/2, areas, wall positions
model = ads.bwb.buildBaff(geom,str,mass,opts);
bOpts = ads.baff.BaffOpts(SplitBeamsAtChildren=false, LeTeEdgeMode="clip", ...
                          AddEndRibs=true, ShellSplineMode=opts.SplineMode);   % ShellSplineMode (new)
fe = ads.baff.baff2fe(model,bOpts);
ads.bwb.addSymmetryBCs(fe,opts.Symmetry);
if opts.Shell && opts.IncludePressure
    ads.bwb.addCabinPressure(fe,opts.CabinDeltaP*opts.PressureFactor);
end
ads.bwb.setPanelDensity(fe,opts.AeroBoxSize,opts.AeroBoxAR);
info = ads.bwb.massBudget(fe,geom,mass,opts);             % NSM top-up, CG, SUPORT node -> info.CoM
symxz = ads.util.tern(opts.Symmetry=="sym",1,ads.util.tern(opts.Symmetry=="antisym",-1,0));
fe.AeroSettings(1) = ads.fe.AeroSettings(geom.MAC,1.225,2*geom.HalfSpan,geom.Area/2, ...
                                         SymXZ=symxz);    % SymXZ as -1/0/1 (F15), REFS = half (F16)
info.Geometry = geom;  info.Opts = opts;
end
```

---

## 5. Shell path (`Shell = true`)

### 5.1 Structured mesher → `ShellStation` (feeds the existing `shell2fe`)

The mesh uses parametric coordinates per spanwise station y_k:

* ξ ∈ [0,1] from the **front line** (home-plate front bulkhead / front spar) to the **rear line** (rear bulkhead / rear spar);
* ζ ∈ [0,1] down the webs.

Every wall lies on a mesh line: symmetry plane, internal walls, side wall, kink, ribs and tip are all included in the `y_k` set. The whole structure is therefore `CQUAD4`, with no `CTRIA3`:

* cabin front and rear bulkheads are the ξ = 0/1 webs,
* the side wall and internal walls are "ribs" at constant y,
* the mid-section and outer spars are the same webs continued.

```matlab
function st = meshShellStation(geom,str,opts,wing)
%MESHSHELLSTATION Structured CQUAD4 mesh of cabin + mid section + outer box,
% returned as a baff ShellStation in the wing's LOCAL frame.
yS    = geom.StructStations(opts);            % sorted global y: 0, walls, Wf/2, kink, ribs, CS breaks, tip
isRib = geom.IsRibStation(yS,opts);           % walls, side wall, kink, rib pitch, tip (NOT y = 0)
xi    = linspace(0,1,opts.NChordStruct+1);    % default 10 elements chordwise
zeta  = linspace(0,1,opts.NDepthStruct+1);    % default 3 elements through the web depth
K = numel(yS);  J = numel(xi);  L = numel(zeta);

Xg = zeros(0,3);  nN = 0;                     % global node store
U = zeros(K,J);  Lo = zeros(K,J);  F = zeros(K,L);  R = zeros(K,L);  RibG = cell(K,1);
for k = 1:K
    [xf,xr]  = geom.BoxLines(yS(k));          % front / rear structural lines at this y
    x        = xf + xi*(xr-xf);
    [zu,zl]  = geom.Surface(x,yS(k));         % OML from airfoil * t/c * chord
    [Xg,nN,U(k,:)]  = addNodes(Xg,nN,[x(:), repmat(yS(k),J,1), zu(:)]);
    [Xg,nN,Lo(k,:)] = addNodes(Xg,nN,[x(:), repmat(yS(k),J,1), zl(:)]);
    zf = zu(1) + zeta(2:L-1)*(zl(1)-zu(1));   zr = zu(J) + zeta(2:L-1)*(zl(J)-zu(J));
    [Xg,nN,fi] = addNodes(Xg,nN,[repmat([x(1) yS(k)],L-2,1), zf(:)]);
    [Xg,nN,ri] = addNodes(Xg,nN,[repmat([x(J) yS(k)],L-2,1), zr(:)]);
    F(k,:) = [U(k,1) fi Lo(k,1)];   R(k,:) = [U(k,J) ri Lo(k,J)];
    if isRib(k)                               % interior grid of the rib / wall plane
        G = zeros(J,L);  G(:,1) = U(k,:)';  G(:,L) = Lo(k,:)';  G(1,:) = F(k,:);  G(J,:) = R(k,:);
        for j = 2:J-1
            z = zu(j) + zeta(2:L-1)*(zl(j)-zu(j));
            [Xg,nN,G(j,2:L-1)] = addNodes(Xg,nN,[repmat([x(j) yS(k)],L-2,1), z(:)]);
        end
        RibG{k} = G;
    end
end

% ---- elements (node order gives OUTWARD normals: needed for PLOAD4) ----
Q = zeros(0,4);  T = strings(0,1);
for k = 1:K-1
    reg = geom.Region((yS(k)+yS(k+1))/2);     % "CB" | "MS" | "OW"
    for j = 1:J-1
        [Q,T] = push(Q,T,[U(k,j)  U(k,j+1)  U(k+1,j+1)  U(k+1,j)],  reg+"_UpperSkin");  % +z
        [Q,T] = push(Q,T,[Lo(k,j) Lo(k+1,j) Lo(k+1,j+1) Lo(k,j+1)], reg+"_LowerSkin");  % -z
    end
    for l = 1:L-1
        [Q,T] = push(Q,T,[F(k,l) F(k+1,l) F(k+1,l+1) F(k,l+1)], reg+ads.util.tern(reg=="CB","_FrontBulkhead","_FrontSpar")); % -x
        [Q,T] = push(Q,T,[R(k,l) R(k,l+1) R(k+1,l+1) R(k+1,l)], reg+ads.util.tern(reg=="CB","_RearBulkhead","_RearSpar"));   % +x
    end
end
for k = find(isRib(:)')
    G = RibG{k};  tag = geom.RibTag(yS(k));   % "CB_InternalWall" | "CB_SideWall" | "MS_KinkRib" | "OW_Rib" | ...
    for j = 1:J-1, for l = 1:L-1
        [Q,T] = push(Q,T,[G(j,l) G(j+1,l) G(j+1,l+1) G(j,l+1)], tag);   % +y (side wall outward)
    end, end
end

% ---- to the wing local frame and a baff ShellStation ----
Xl = (wing.A.' * (Xg.' - wing.Offset(:))).';
shells = baff.station.ShellStation.Shell.empty;
for e = 1:size(Q,1)
    p = str.Props(T(e));                      % gauge, baff.Material, BendRatio, NSM per tag
    shells(end+1,1) = baff.station.ShellStation.Shell(Q(e,:)',p.Mat,p.t,"PSHELL",Tag=T(e)); %#ok<AGROW>
end
eta   = yS / geom.HalfSpan;                   % valid because EtaDir(1,:) == 1 (FromLETESweep, no dihedral)
rings = arrayfun(@(k) [U(k,:), R(k,2:L-1), fliplr(Lo(k,:)), fliplr(F(k,2:L-1))], 1:K, 'UniformOutput',false);
st = wing.Stations;                            % from FromLETESweep_Shell: keeps EtaDir / beam line
st.Nodes = Xl;  st.Shell = shells;
st.SecondaryEta   = eta;
st.SecondaryNodes = packRings(rings);         % K blocks of equal rows, padded to multiples of 4 (F3)
st.SplineNodes    = reshape(U.',[],1);        % (new property) upper-skin grids for "skin" splines
end

function [Xg,nN,idx] = addNodes(Xg,nN,P)
idx = nN + (1:size(P,1));  Xg(idx,:) = P;  nN = idx(end);
end
function [Q,T] = push(Q,T,q,t)
Q(end+1,:) = q;  T(end+1,1) = t;
end
```

With the default densities (10 chordwise × 3 deep; 0.5 m spanwise in the centre body and mid section, 0.35 m outboard; outer ribs about every 0.7 m) this gives **about 1.9 k CQUAD4**, comparable to Gern's 2.5–3.5 k. Element aspect ratio stays at or below ~4 at the tip.

### 5.2 Structural idealisation per tag (initial gauges before sizing)

| Tag | Material (PSHELL route) | t₀ [mm] | 12I/T³ | Pressure |
|---|---|---|---|---|
| `CB_UpperSkin`, `CB_LowerSkin` | PRSEUS smeared (QI IM7-8552: E = 56.1 GPa, G = 21.4 GPa, ν = 0.31, ρ = 1 578 kg/m³) | 6 | `BendRatio_PRSEUS` | yes (outward) |
| `CB_FrontBulkhead`, `CB_RearBulkhead` | PRSEUS smeared | 6 | `BendRatio_PRSEUS` | yes |
| `CB_SideWall` | PRSEUS smeared | 5 | `BendRatio_PRSEUS` | yes (+y, towards the unpressurised mid section) |
| `CB_InternalWall` | simple composite panel (Joseph: ribs are not PRSEUS) | 4 | 1 | no (pressurised on both sides) |
| `MS_*` skins, spars, ribs | CFRP QI | 5 / 5 / 3 | 1 | no |
| `OW_*` skins, spars, ribs | CFRP QI | 8→3 / 6→3 / 3 (linear in y) | 1 | no |

* **PRSEUS (Gern §III.C).** Keep the membrane thickness `t_eff = (A_skin + A_stringer)/pitch` and set
  `BendRatio = 12·I_panel/t_eff³`, where `I_panel` is the panel bending inertia per unit width. Use the
  Velicki panel dimensions (Joseph Ref 12: stringer pitch 6 in, frame pitch 24 in).
  Put this in `BWBStructure.PRSEUS()` as a function of the panel geometry, not as a magic number.
* **PCOMP/MAT8 route (optional, Ph 7).** IM7-8552 tape: E1 = 146.9 GPa, E2 = 8.69 GPa, G12 = 5.16 GPa,
  ν12 = 0.32 (Joseph Table 3). Joseph's `[45/-45/0/90/45/-45]s` layup gives E = 45.9 GPa and G = 26.9 GPa.
* All primary structure uses the PRSEUS density of 0.057 lb/in³ (Gern §III.G). Non-optimum factor 1.2 (Joseph).

### 5.3 Boundary conditions, hubs, supports

* **Symmetric half model.** SPC `246` on every *independent* structural grid with |y| < 1e-6
  (antisymmetric: `135`). **Never SPC a grid that is dependent in an RBE2/RBE3** (the RBE3 hubs and
  LE/TE bar ends); Nastran stops with a fatal error. So filter on grids that belong to shells:

```matlab
function addSymmetryBCs(fe,mode)
if mode == "none", return, end
dofs = ads.util.tern(mode=="sym",246,135);
shellPts = unique([fe.Shells.G]);                          % independent structural grids only
for p = shellPts(:)'
    if abs(p.GlobalPos(2)) < 1e-6
        fe.Constraints(end+1) = ads.fe.Constraint(p,dofs);
    end
end
end
```

* **Free-free** (SOL103/144/145): use the existing `CoM` constraint mechanism, but put it on the
  **nearest independent structural grid to the CG** (a lower-skin node), not on an RBE3 reference.
  Symmetric trim uses `DoFs=35` (plunge and pitch), as `Sol144.set_trim_steadyLevel` already does.
* **SOL101 (pressure and unit loads):** use inertia relief `PARAM,INREL,-2`. This needs a `Params`
  struct on `Sol101`, matching `Sol144`/`Sol145` (§9). Gern notes that ignoring inertia relief
  over-predicts loads.

### 5.4 Cabin pressure (new `PLOAD4` + `ads.fe.Pressure`)

```matlab
% Matran: tbx/+mni/+printing/+cards/PLOAD4.m (new) - P1 only (P2-P4 default to P1)
classdef PLOAD4 < mni.printing.cards.BaseCard
    properties
        SID; EID; P;
    end
    methods
        function obj = PLOAD4(SID,EID,P)
            arguments
                SID (1,1) double; EID (1,1) double; P (1,1) double
            end
            obj.Name = 'PLOAD4';  obj.SID = SID;  obj.EID = EID;  obj.P = P;
        end
        function writeToFile(obj,fid,varargin)
            writeToFile@mni.printing.cards.BaseCard(obj,fid,varargin{:})
            obj.fprint_nas(fid,'iir',{obj.SID,obj.EID,obj.P});
        end
    end
end
```

```matlab
% ADS: tbx/+ads/+fe/Pressure.m (new) - positive P acts along the shell normal (outward, from the mesher ordering)
classdef Pressure < ads.fe.Element
    properties
        Shells (:,1) ads.fe.Shell = ads.fe.Shell.empty;
        P double = 0;          % Pa
        ID double = nan;       % load set id (goes into Sol*.ForceIDs, like Force/Moment)
    end
    methods
        function obj = Pressure(shells,P)
            obj.Shells = shells;  obj.P = P;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:numel(obj), obj(i).ID = ids.SID;  ids.SID = ids.SID + 1;  end
        end
        function Export(obj,fid)
            if isempty(obj), return, end
            mni.printing.bdf.writeComment(fid,"PLOAD4 : pressure on shell elements");
            for i = 1:numel(obj)
                for s = obj(i).Shells(:)'
                    mni.printing.cards.PLOAD4(obj(i).ID,s.EID,obj(i).P).writeToFile(fid);
                end
            end
        end
        function plt_obj = drawElement(~), plt_obj = []; end
    end
end
```

```matlab
function addCabinPressure(fe,P)
labels = ["CB_UpperSkin","CB_LowerSkin","CB_FrontBulkhead","CB_RearBulkhead","CB_SideWall"];
fe.Pressures(end+1) = ads.fe.Pressure(fe.Shells(ismember([fe.Shells.Label],labels)),P);  % Label (new): baff Shell.Tag
end
```

Acceptance: for the upper skin alone, the sum of the PLOAD4 resultants should be ≈ P × projected cabin
area, pointing +z. Check this in the MATLAB unit test from the shell normals and in the Nastran OLOAD
resultant. Verify the PLOAD4 sign convention against your Nastran QRG.

### 5.5 `shell2fe` / `ads.fe.Shell` edits (Phase 1)

```matlab
% shell2fe.m — per-shell materials (F4), Ci = 123 (F9), guard (F1), labels
mats = [shells.Mat];
[~,~,im] = unique(arrayfun(@(m) m.Hash, mats),'stable');
feMats = ads.fe.Material.empty;
for m = 1:max(im)
    feMats(m,1) = ads.fe.Material.FromBaffMat(mats(find(im==m,1)));
end
fe.Materials = [fe.Materials; feMats];
for i = 1:numel(shells)
    fe.Shells(end+1) = ads.fe.Shell.FromBaffStations(shells(i),fe.Points(shells(i).G), ...
                                                      feMats(im(i)),shells(i).Thickness);
end
...
Ci = 123;                                              % was 123456
...
if isprop(obj.Stations,'SecondaryBeams') && ~isempty(obj.Stations.SecondaryBeams)   % was unguarded
...
% optional "skin" spline nodes (F10): mark the mesher's upper-skin grids
if isprop(obj.Stations,'SplineNodes') && ~isempty(obj.Stations.SplineNodes)
    [fe.Points(obj.Stations.SplineNodes).Note] = deal("SplineNode");
end
```

```matlab
% ads.fe.Shell — new properties and methods (F5-F7)
properties
    NSM double = 0;              % kg/m^2
    BendRatio double = 1;        % PSHELL 12I/T^3 (PRSEUS)
    TST double = [];             % PSHELL TS/T (blank -> 0.833333)
    Label string = "";           % from baff Shell.Tag; NOT overwritten by Component.UpdateTag
    PropertyGroup string = "";   % shells with the same group share one PSHELL (empty -> own PID)
end
function m = GetMass(obj)
    m = zeros(size(obj));
    for i = 1:numel(obj)
        X = [obj(i).G.GlobalPos];
        A = 0.5*norm(cross(X(:,3)-X(:,1), X(:,4)-X(:,2)));
        m(i) = A*(obj(i).Thickness*obj(i).Mat.rho + obj(i).NSM);
    end
end
% ExportToPSHELL: write each unique PID once
tmpCard = mni.printing.cards.PSHELL(obj(i).PID,obj(i).Mat.ID,obj(i).Thickness,obj(i).Mat.ID, ...
            obj(i).BendRatio,obj(i).Mat.ID,TST=obj(i).TST,NSM=obj(i).NSM);
```

```matlab
% Matran PSHELL — backward-compatible optional fields (F5)
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
    ...  obj.TST = opts.TST;  obj.NSM = opts.NSM;
end
function writeToFile(obj,fid,varargin)
    writeToFile@mni.printing.cards.BaseCard(obj,fid,varargin{:})
    obj.fprint_nas(fid,'iiririrr',{obj.PID,obj.MID1,obj.T,obj.MID2,obj.I12,obj.MID3,obj.TST,obj.NSM});
end
```

`Component.GetMass` must also sum `Shells.GetMass` and `LBeams.GetMass`. `Component` gets a new property,
`Pressures (:,1) ads.fe.Pressure`.

---

## 6. Beam path (`Shell = false`): wingbox reduction

### 6.1 Analytical multi-cell condensation (spanwise stick)

At each beam station, the spanwise section cut (plane normal to the beam line, ≈ constant y) is a thin-walled box:

* skins from the OML (`geom.Surface`), smeared with stringers;
* webs at the front and rear lines (cabin: front/rear bulkheads; mid/outer: spars).

The internal walls are parallel to this cut, so **the spanwise stick is single-cell in the cabin**. The bay count enters through the spine (§6.2) and through mass.

```matlab
function sec = boxCondensation(x,zU,zL,tU,tL,tW)
%BOXCONDENSATION Thin-walled multi-cell section -> beam properties.
%  x      : web positions across the section (1 x nw), sorted; first/last = closing webs
%  zU,zL  : upper/lower skin height at those positions (1 x nw)
%  tU,tL  : smeared skin thickness per cell (1 x nw-1)  (skin + stringer area / pitch)
%  tW     : web thickness (1 x nw)
%  -> A, Iyy (= int z^2 dA, flap), Izz (= int x^2 dA, in-plane), J (multi-cell Bredt-Batho)
nw = numel(x);  nc = nw-1;
seg = zeros(0,5);                                    % [x1 z1 x2 z2 t]
for c = 1:nc
    seg(end+1,:) = [x(c) zU(c) x(c+1) zU(c+1) tU(c)];   %#ok<AGROW>
    seg(end+1,:) = [x(c) zL(c) x(c+1) zL(c+1) tL(c)];   %#ok<AGROW>
end
for w = 1:nw
    seg(end+1,:) = [x(w) zL(w) x(w) zU(w) tW(w)];       %#ok<AGROW>
end
dx = seg(:,3)-seg(:,1);  dz = seg(:,4)-seg(:,2);  Aw = hypot(dx,dz).*seg(:,5);
xm = (seg(:,1)+seg(:,3))/2;  zm = (seg(:,2)+seg(:,4))/2;
A  = sum(Aw);  xc = sum(Aw.*xm)/A;  zc = sum(Aw.*zm)/A;
Iyy = sum(Aw.*((zm-zc).^2 + dz.^2/12));
Izz = sum(Aw.*((xm-xc).^2 + dx.^2/12));
% St Venant torsion, equal twist rate in every cell:  D*q = 2*Acell*(G*theta')
Acell = zeros(nc,1);  D = zeros(nc);
for c = 1:nc
    hL = zU(c)-zL(c);  hR = zU(c+1)-zL(c+1);
    Acell(c) = 0.5*(x(c+1)-x(c))*(hL+hR);
    lu = hypot(x(c+1)-x(c), zU(c+1)-zU(c));  ll = hypot(x(c+1)-x(c), zL(c+1)-zL(c));
    D(c,c) = lu/tU(c) + ll/tL(c) + hL/tW(c) + hR/tW(c+1);
    if c > 1,  D(c,c-1) = -hL/tW(c);   end
    if c < nc, D(c,c+1) = -hR/tW(c+1); end
end
q = D \ (2*Acell);                                   % shear flows for unit G*theta'
J = 2*sum(Acell.*q);                                 % single cell -> 4A^2 / (oint ds/t)
sec = struct('A',A,'Iyy',Iyy,'Izz',Izz,'J',J,'xc',xc,'zc',zc);
end
```

How it plugs into `buildBaff` when `Shell=false`:

```matlab
w = baff.Wing.FromLETESweep(b,geom.Chord(1),geom.Y/b,geom.LESweep,geom.TESweep, ...
                            geom.BeamLoc,str.RefMat,ThicknessRatio=geom.TC);
w.Stations = w.Stations.interpolate(geom.BeamEtas(opts));      % e.g. ~0.5 m spacing + all breaks
for i = 1:w.Stations.N
    y = w.Stations.Eta(i)*b;
    [xw,tW,tU,tL] = str.SpanwiseSection(geom,y);               % webs at the front/rear lines (+ mid spar)
    [zu,zl] = geom.Surface(xw,y);
    s = ads.bwb.boxCondensation(xw,zu,zl,tU,tL,tW);            % modulus-weighted if materials differ
    w.Stations.A(i)     = s.A;
    w.Stations.I(:,:,i) = diag([s.Iyy+s.Izz, s.Iyy, s.Izz]);   % baff/Bar convention (B2)
    w.Stations.J(i)     = s.J;
end
w.Stations.Mat = str.RefMat;                                    % E, G of the reference laminate
% Mass consistency with the shell model: ribs, walls and bulkhead mass that is not in rho*A
% is added as baff distributed mass (as in baff/tests/@TAW/SetupWings)
w.DistributeMass(str.NonBeamMass(geom),opts.NMassStations,"tag","bwb_nonbeam","Method","Regular");
```

### 6.2 Centre-body spine: cruciform stick (the bay count appears here)

A single spanwise stick makes the centre body chordwise-rigid (B4). Add a **longitudinal spine** on the centreline: two `baff.Beam` children of the BWB wing at `eta=0`, one running forward to x = 3.0 and one aft to x = 15.5–17.0.

Its section at each x is the cut **across the cabin width**. The skins span W_f, and the **webs are the side walls and the internal walls**, so the section has `NBays` cells:

```matlab
function [A,I,J] = spineSection(geom,str,x)
yw = [-geom.CabinWidth/2, -fliplr(geom.WallY), geom.WallY, geom.CabinWidth/2];   % 1/3/5 bays -> 1/3/5 cells
yw = yw(arrayfun(@(y) x >= geom.FrontLineX(abs(y)), yw));   % home plate: walls start further aft
zu = zeros(size(yw));  zl = zu;
for k = 1:numel(yw), [zu(k),zl(k)] = geom.Surface(x,abs(yw(k))); end
s  = ads.bwb.boxCondensation(yw,zu,zl,str.t("CB_UpperSkin")*ones(1,numel(yw)-1), ...
                             str.t("CB_LowerSkin")*ones(1,numel(yw)-1),str.WallThickness(yw));
% HALF MODEL: the spine lies on the symmetry plane, so it carries half of everything
A = s.A/2;  I = diag([s.Iyy+s.Izz, s.Iyy, s.Izz])/2;  J = s.J/2;
end
```

* 1 → 3 → 5 bays adds webs (bending and shear) and cells (torsion). This is the beam-path counterpart
  of Gern's displacement relief.
* The spine nodes lie on y = 0 and get the same symmetry SPCs.
* Its aero coupling: `SPLINE4` sets for the centre-body panels include the spine nodes, which gives
  chordwise (pitch-plane) flexibility.
* **Option B2 (Ph 7):** a full **grillage**, built directly as `ads.fe` beams. Bulkheads become spanwise
  beams, walls become chordwise beams, and skins become effective flanges, all joined at shared grids.
  BAFF's one-bar parent/child joint cannot represent it.

### 6.3 Shell-calibrated beam: the reduction checked against the shell path

Three SOL101 runs on the shell model, with the root hub clamped and no masses:

1. tip force normal to the chord plane;
2. tip torque about the beam axis;
3. tip force chordwise.

These give the **3×3 compliance per unit length** of every hub segment. Its inverse gives GJ, EI_flap and EI_chord, including bend–twist coupling from sweep and laminates.

```matlab
% after the three runs: Xh (3 x nH) hub positions, rot(:,k,c) hub rotations (global), Fc/Mc (3 x 3) applied tip loads
for k = 1:nH-1
    e1 = (Xh(:,k+1)-Xh(:,k));  ds = norm(e1);  e1 = e1/ds;          % beam axis
    e3 = cross(e1,chordDir(:,k));  e3 = e3/norm(e3);  e2 = cross(e3,e1);
    Tk = [e1 e2 e3];                                                % local frame: axis, chord, normal
    Xm = (Xh(:,k)+Xh(:,k+1))/2;   M = zeros(3);  Th = zeros(3);
    for c = 1:3
        M(:,c)  = Tk.'*( cross(Xh(:,end)-Xm, Fc(:,c)) + Mc(:,c) );  % internal moment at segment mid
        Th(:,c) = Tk.'*( rot(:,k+1,c) - rot(:,k,c) ) / ds;          % twist rate and curvatures
    end
    Kseg = inv(((Th/M) + (Th/M).')/2);                              % symmetrised stiffness
    GJ(k) = Kseg(1,1);  EIflap(k) = Kseg(2,2);  EIchord(k) = Kseg(3,3);
end
```

Use this to:

1. **validate §6.1**. Within ±15 % on EI_flap and GJ outboard of the kink is acceptable; expect large
   differences in the cabin, which is plate-like;
2. optionally **replace** the analytical stations: `BeamSource = "analytic" | "shell"` in `BWBOpts`.

**Stretch goal (Ph 7).** Exact Guyan reduction to the hub set:

* `ASET1` on the hubs + case control `EXTSEOUT(STIFFNESS,MASS,DMIGPCH)` in a SOL103 run (check the syntax for your version);
* parse `KAAX`/`MAAX` from the `.pch` and inject them as `ads.fe.DMIG` (K2GG/M2GG) on the stick nodes.

### 6.4 Mass on the beam path

* Structural mass comes from `ρ·A`, plus distributed non-beam mass (ribs, walls, non-optimum factor).
* Masses from §3.5 are `baff.Mass` children. `element2fe` attaches each one to the closest stick or
  spine node with a rigid bar.
* Payload uses a bay × row grid at floor height. **Match the shell model's mass per spanwise strip**;
  modal comparisons are meaningless otherwise.

---

## 7. Aero model: centre-body panels are the key difference from a tube-and-wing A320

### 7.1 CAERO1 layout (DLM, half model with `AEROS SYMXZ=+1`)

`wing2fe` builds one `CAERO1` per `AeroStations` interval, split further at control-surface etas. The BWB wing therefore gets centre-body panels automatically:

| Macro-panel | y range | Chords | Chordwise boxes (Δx ≈ 0.5 m) | Spanwise boxes (AR ≈ 1.5) |
|---|---|---|---|---|
| Centre body (split at elevon breaks) | 0 → 4.0 | 17 → 10 | 34 | 8 |
| Transition / mid section | 4.0 → 6.2 | 10 → 5 | 20 | 5 |
| Outer wing (elevon, aileron breaks) | 6.2 → 17.9 | 5 → 1.84 | 10 | 24 |

About 600 boxes. The box size meets `Δx ≤ 0.08·V_min/f_max` (0.53 m for 100 m/s and 15 Hz).

The existing `SetPanelNumbers(N,AR,'Span')` uses one chordwise N everywhere, which does not suit 17 m and 1.84 m chords on the same wing. Add a size-based method:

```matlab
% ads.fe.AeroSurface (new method)
function SetPanelSize(obj,dx,AR)
%SETPANELSIZE chordwise box length dx [m] and box aspect ratio AR (span/chord)
for i = 1:numel(obj)
    cMax = max(obj(i).Chords);
    obj(i).nChord = max(4,ceil(cMax/dx));
    span = norm(obj(i).Points(:,2)-obj(i).Points(:,1));
    obj(i).nSpan  = max(1,ceil(span/(AR*cMax/obj(i).nChord)));
end
end
```

### 7.2 Camber, reflex and twist as fixed downwash (Gern §III.D)

With flat DLM panels the centre body over-lifts relative to the 38 %/62 % target. Include **camber-slope downwash** in the `W2GJ` DMI that ADS already writes for twist:

* reflexed centre-body camber for the tailless trim (C_m0 ≈ 0);
* outer-wing washout (initial twist `[0 0 0 −3]°`, tuned for a bell-shaped span load).

```matlab
% ads.fe.AeroSurface: new property CamberFcn = [] (handle: xi -> dz/dx of the camber line)
% in get_twists, per surface i, BEFORE the "if X4(1) < 0" sign flip:
if ~isempty(obj(i).CamberFcn)
    xc   = obj(i).EtaChord(1:end-1) + 0.75*diff(obj(i).EtaChord);    % 3/4-box collocation points
    dzdx = obj(i).CamberFcn(xc);                                      % nChord values
    angles{i} = angles{i} - rad2deg(atan(repmat(dzdx(:),obj(i).nSpan,1))).';   % chordwise index fastest
end
```

```matlab
% simple reflexed camber line: z/c = a*xi*(1-xi)*(xr - xi); positive forward, reflexed aft of xr
reflex = @(a,xr) @(xi) a*((1-xi).*(xr-xi) - xi.*(xr-xi) - xi.*(1-xi));   % d(z/c)/d(xi)
% centre body: CamberFcn = reflex(0.05,0.75) -> tune a so that rigid Cm0 ~ 0 at the CG
```

`WKK` (per-box C_Lα correction) stays available for matching test or CFD data later.

### 7.3 Splines: no overlap across the kink

* **Beam path:** `SPLINE4` (IPS) per panel, as now, but with each panel's structural set limited to
  nodes inside its span (plus the shared boundary station). Centre-body panels also get the spine nodes.
* **Shell path:** new `BaffOpts.ShellSplineMode`:
  * `"hub"`: current behaviour (F10);
  * `"segment"`: RBE3 hubs and LE/TE nodes inside the panel span only;
  * `"skin"` (**default for BWB**): upper-skin grids from `ShellStation.SplineNodes` inside the panel
    span. This keeps the centre body's chordwise flexibility (Gern splined to the front and rear spars).

```matlab
% wing2fe.m, replacing lines 886-888
if SplineType == 1
    mode = string(getOpt(baffOpts,'ShellSplineMode',"hub"));
    tol  = 1e-6*obj.EtaLength;
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
X = [p.X];                                   % local wing frame: X(1,:) is spanwise (no dihedral)
p = p(X(1,:) >= e1*L-tol & X(1,:) <= e2*L+tol);
end
```

### 7.4 Control surfaces (tailless: elevons + AELINK)

| Surface | y range [m] | eta | Constant chord fraction (MSC) |
|---|---|---|---|
| `ElevCB` | 1.0 → 4.0 | 0.056 → 0.2235 | 0.12 |
| `ElevMS` | 4.0 → 6.2 | 0.2235 → 0.3464 | 0.20 |
| `ElevOW` | 6.2 → 12.0 | 0.3464 → 0.670 | 0.25 |
| `Ail` | 12.0 → 16.5 | 0.670 → 0.922 | 0.25 |

* `ElevCB` and `ElevMS` are linked to `ElevOW` through `LinkedSurface`/`LinkedCoefficent`, which
  writes AELINK. For symmetric trim, **ANGLEA and ElevOW are the free trim variables** and `Ail` is
  locked at 0. The centre-body elevons sit behind the rear bulkhead, where there is no structure, so
  they are splined through the TE nodes.

### 7.5 Lift-share check (acceptance for §7.2)

```matlab
h5  = mni.result.hdf5(fullfile(bin,'bin','sol144.h5'));
af  = h5.read_aero_force();                           % per subcase: box ID and F (n x 3)
ids = double(af(1).ID);  Fz = af(1).F(:,3);
cb  = [];
for s = fe.AeroSurfaces(:)'
    Yg = s.CoordSys.getPointGlobal(s.Points);
    if max(Yg(2,:)) <= 6.2+1e-6, cb = [cb, s.get_panelIDs()]; end %#ok<AGROW>
end
share = sum(Fz(ismember(ids,cb)))/sum(Fz);            % target ~0.38 (range 0.33-0.40)
```

---

## 8. Analyses and the case matrix

Six models: {C1, C2, C3} × {Shell, Beam}. Every run uses the same geometry, mass budget and aero mesh.

| Run | Solution | Settings | Output metrics |
|---|---|---|---|
| R1 | Build + export | `bwb2fe` → `Flatten` → `UpdateIDs` → `Export` | element counts, mass, CG, I_yy, S_CAERO = 110.5 m² |
| R2 | SOL103 free-free | sym (`SYMXZ=+1`, SPC 246) and antisym (−1, 135); 0.1–30 Hz; LModes 30 | 1st sym wing bending, centre-body pitch/bending, 1st torsion; frequencies shell vs beam |
| R3 | SOL101 1.33P (shell only) | PLOAD4 on cabin skins, bulkheads and side wall; INREL −2; g = 0 | max skin deflection (Gern Fig 13/17 trend: C1 ≫ C2 > C3), max von Mises / strain |
| R4 | SOL144 trim | M 0.78 cruise q; `LoadFactor` 1.0, 2.5, −1.0; `set_trim_steadyLevel(V,rho,M,CoM)`; ElevOW free | α, δ_e, **lift share**, tip deflection, root/kink bending moment, stresses ×1.5 |
| R5 | SOL145 flutter | PK (or PKNL), sym + antisym, M 0.3/0.5/0.78, density sweep; target 1.15·V_D (A320-like V_D = 381 KEAS, M_D 0.89) | V_f, mechanism: **body-freedom flutter** (centre-body pitch + wing bending) vs classical |
| R6 | Beam identification | §6.3 on each shell case | EI/GJ vs analytical; update the beam models |

```matlab
% Examples/BWB_A320_bay_study.m (sketch)
S = ads.bwb.BWBStructure.PRSEUS();  Mb = ads.bwb.BWBMass.A320Class();  out = table();
for nb = [1 3 5]
    for isShell = [true false]
        g = ads.bwb.BWBGeometry.A320Class(nb);
        o = ads.bwb.BWBOpts(Shell=isShell,Symmetry="sym");
        [fe,info] = ads.bwb.bwb2fe(g,S,Mb,o);
        fe = fe.Flatten();  IDs = fe.UpdateIDs();
        tag = sprintf('bwb_%dbay_%s',nb,ads.util.tern(isShell,'shell','beam'));
        s103 = ads.nast.Sol103();  s103.FreqRange = [0.1 30];  s103.LModes = 30;  s103.UpdateID(IDs);
        modes = s103.run(fe,BinFolder=fullfile('bwb_runs',tag,'s103'));
        s144 = ads.nast.Sol144();  s144.set_trim_steadyLevel(230.2,0.3164,0.78,info.CoM);
        s144.LoadFactor = 2.5;  s144.UpdateID(IDs);
        s144.run(fe,BinFolder=fullfile('bwb_runs',tag,'s144_2p5g'));
        share = ads.bwb.liftShare(fe,fullfile('bwb_runs',tag,'s144_2p5g'));
        out = [out; {nb,isShell,info.Mass.Total,modes(1).Frequency,share}]; %#ok<AGROW>
    end
end
```

(Check the `Sol103.run` return type and the `modes` field names against `+ads/+nast/@Sol103/run.m` when implementing.)

**Expected trends / acceptance:**

1. Structural mass: C2 ≈ C3 (within ~5 %) and C1 lighter only when displacement is unconstrained. Pressure deflection C1 ≫ C2 > C3.
2. Shell vs beam: outer-wing bending frequency within ~10 %, and larger differences for centre-body modes, especially without the spine.
3. Lift share 33–40 % once camber and twist are tuned.
4. Sized cabin mass inside the 5–8 t cross-check band (§3.3) once a sizing loop exists (Ph 7).

---

## 9. Repository edit list

### ads (`frasacchi/ads`)

| File | Change | Phase |
|---|---|---|
| `tbx/+ads/+baff/private/shell2fe.m` | guard `SecondaryBeams`; per-shell materials; `Ci=123`; pass the baff `Tag` to `Shell.Label`; mark `SplineNodes` | 1 |
| `tbx/+ads/+fe/Shell.m` | `NSM`, `BendRatio`, `TST`, `Label`, `PropertyGroup`; `GetMass`; grouped PIDs; PSHELL with 12I/T³/TS-T/NSM; `FromBaffStations` passes `Tag`, `BendRatio`, `NSM` | 1 |
| `tbx/+ads/+fe/@Component/Component.m` | `GetMass` includes `Shells` and `LBeams`; new `Pressures` property | 1, 4 |
| `tbx/+ads/+fe/Pressure.m` *(new)* | PLOAD4 load element | 4 |
| `tbx/+ads/+fe/AeroSurface.m` | `SetPanelSize`; `CamberFcn` → W2GJ | 3 |
| `tbx/+ads/+fe/AeroSettings.m` | `SymXZ` accepts −1/0/+1 (keep logical input working) | 3 |
| `tbx/+ads/+baff/private/wing2fe.m` | `ShellSplineMode` ("hub"/"segment"/"skin"); per-panel span filter for SPLINE1/SPLINE4 | 3 |
| `tbx/+ads/+baff/BaffOpts.m` | `ShellSplineMode="hub"` (default keeps current behaviour) | 3 |
| `tbx/+ads/+nast/@Sol101/*` | `Params` struct (for INREL); add `Pressures` IDs to `ForceIDs` (as Forces/Moments) | 4 |
| `tbx/+ads/+nast/@Sol144/run.m` (and 145 if needed) | add `Pressures` IDs to `ForceIDs` (combined 2.5 g + 1.33P option) | 4 |
| `tbx/+ads/+bwb/*` *(new package)* | everything in §4.1 | 2–6 |
| `Examples/BWB_A320_*.m` *(new)* | build / 103 / 144 / 145 / pressure / bay study | 2–6 |
| `tests/bwb2feTest.m` *(new)*, `tests/shellCardsTest.m` *(new)* | see §10 | 1–6 |
| `CLAUDE.md`, `changelog.txt`, `version.txt` | document `+bwb`; bump minor version (0.4.0) at the end | 6 |

### baff (`frasacchi/baff`)

| File | Change | Phase |
|---|---|---|
| `+station/+ShellStation/ShellStation.m` | add `SecondaryBeams` (empty default; or merge from your fork together with `baff.station.LBeam`), `SplineNodes (:,1)`; `interpolate` keeps `Nodes/Shell` (return a copy with the new etas, since the mesh is eta-independent); `Duplicate` keeps `ConstrainedEta`; `horzcat` offsets node indices | 1 |
| `+station/+ShellStation/Shell.m` | `BendRatio = 1`, `NSM = 0` | 1 |
| `+station/+ShellStation/ToBaff.m`, `FromBaff.m`, `TemplateHdf5.m` | real shell IO: Nodes, connectivity, thickness, material table, tags, Secondary*/Constrained*/SplineNodes | 1 |
| `+station/@Beam/Beam.m` | fix the `HollowRect` Iyy/Izz swap (B3), with a regression test | 5 |
| `tests/ShellStationTest.m` *(new)* | round-trip H5, interpolate keeps the mesh | 1 |

### Matran (`frasacchi/Matran`)

| File | Change | Phase |
|---|---|---|
| `tbx/+mni/+printing/+cards/PSHELL.m` | optional `TST`, `NSM` (backward compatible) | 1 |
| `tbx/+mni/+printing/+cards/PLOAD4.m` *(new)* | pressure card | 4 |
| (Ph 7) `+mni/+result/@hdf5/read_stress_QUAD4.m` *(if missing)* | for sizing loops | 7 |

---

## 10. Phased roadmap and acceptance tests

| Phase | Content | Acceptance (all in `runtests('tests')` unless noted) |
|---|---|---|
| **0** Trials | Run T1/T2 (§2.3) locally and record the results in this file | F1 reproduced; T2 prints the CAERO area ≈ 110.5 m² and the LE-node counts |
| **1** Shell foundations | §9 Phase-1 edits in all three repos | T1 builds and exports; BDF has one MAT per material, PSHELL with 12I/T³ and NSM, RBE3 `Ci=123`; `Component.GetMass` = Σρ·t·A; ShellStation H5 round-trip |
| **2** Geometry + mesher | `BWBGeometry`, `BWBStructure`, `meshShellStation`, `buildBaff(Shell=true)`, `bwb2fe` skeleton | Areas/spans within 1 % of §3.2; 1/3/5-bay walls at the §3.4 y values; all skin normals outward; no zero-area or duplicate elements; C1/C2/C3 export; `fe.draw()` |
| **3** Aero | `SetPanelSize`, `CamberFcn`, spline modes, control surfaces, AEROS ±1 | Σ CAERO area = S/2; no SPLINE set holds nodes outside its panel span (+ boundary); *(Nastran)* rigid SOL144 runs and lift share is reported |
| **4** Loads, BCs, mass | PLOAD4, `Pressure`, Sol101 `Params`/INREL, symmetry BCs, `massBudget`, CoM node | PLOAD4 resultant check; SPC never on dependent grids; mass = MTOM/2 ± 0.5 %, CG at target ± 0.1 m; *(Nastran)* SOL103 sym/antisym with 3 rigid modes (sym: T1, T3, R2) ≈ 0 Hz; SOL101 1.33P runs |
| **5** Beam path | `boxCondensation`, `spineSection`, `buildBaff(Shell=false)`, `identifyBeamFromShell`, baff `HollowRect` fix | Single cell reproduces 4A²/∮ds/t; a symmetric two-cell box agrees with the textbook result; C1/C2/C3 beam models build; *(Nastran)* identified vs analytic EI/GJ within ±15 % outboard |
| **6** Case study | `BWB_A320_bay_study.m`, SOL145 examples, docs | Table of §8 metrics for 6 models plus plots; trends as in §8, with deviations explained |
| **7** (optional) | Sizing loop (FSD in MATLAB or a `Sol200` class), PCOMP/MAT8 tailoring, CTRIA3 transitions, grillage B2, EXTSEOUT → DMIG | case-specific |

Unit-test skeleton:

```matlab
classdef bwb2feTest < matlab.unittest.TestCase
    properties (TestParameter)
        nBays   = {1,3,5};
        isShell = {true,false};
    end
    methods (Test)
        function buildsAndExports(tc,nBays,isShell)
            g  = ads.bwb.BWBGeometry.A320Class(nBays);
            fe = ads.bwb.bwb2fe(g,ads.bwb.BWBStructure.PRSEUS(),ads.bwb.BWBMass.A320Class(), ...
                                ads.bwb.BWBOpts(Shell=isShell));
            tc.verifyEqual(sum([fe.AeroSurfaces.Area]), g.Area/2, 'RelTol',0.01);
            fe = fe.Flatten();  fe.UpdateIDs();
            f = [tempname '.bdf'];  fe.Export(f);  tc.verifyTrue(isfile(f));
        end
        function wallsOnMesh(tc,nBays)
            g  = ads.bwb.BWBGeometry.A320Class(nBays);
            fe = ads.bwb.bwb2fe(g,ads.bwb.BWBStructure.PRSEUS(),ads.bwb.BWBMass.A320Class(), ...
                                ads.bwb.BWBOpts(Shell=true));
            yw = arrayfun(@(s) s.G(1).GlobalPos(2), fe.Shells([fe.Shells.Label]=="CB_InternalWall"));
            yw = uniquetol(yw,1e-6);                        % one y per internal wall (half model)
            tc.verifyEqual(numel(yw), numel(g.WallY));      % 0 / 1 / 2 walls for 1 / 3 / 5 bays
            tc.verifyEqual(sort(yw(:))', sort(g.WallY), 'AbsTol',1e-6);
        end
    end
end
```

---

## 11. Risks and open questions

1. **Cabin packaging vs the 140 m² inner area.** A 78 m² cabin, 1.7 m side-wall depth and C_L(FL390) ≈ 0.42
   are all tight. `BWBGeometry` is fully parametric; the likely levers are W_f, rear-bulkhead x, t/c and
   cruise altitude. Confirm with OpenVSP before sizing conclusions.
2. **Fuel volume:** the outer box holds only ~5.3 t per side, so ≈ 3.6 t goes in the mid-section box.
   Check that it is outside the pressure vessel (it is: y > 4.0).
3. **PRSEUS `BendRatio`** needs the Velicki panel dimensions. Until they are set, run with 1.0 and
   flag the results as "homogeneous skin".
4. **DLM near M_D 0.89** is outside DLM's comfort zone. Use M ≤ 0.8 for clearance studies and state it.
5. **Beam vs shell in the cabin:** a stick (even cruciform) cannot represent pressure-driven plate
   bending, which drives cabin sizing. Treat the beam path as a *dynamics/loads* model and the shell
   path as the *sizing* model.
6. **Your local fork:** if `baff.station.LBeam` / `SecondaryBeams` or a `shell=false` reduction exist
   only there, merge them first. §9 assumes the public branch.
7. **SOL200** (Gern's optimiser) is not in ADS. The plan stops at analysis plus an optional MATLAB FSD
   loop. A `Sol200` class would be a separate project.

---

## Appendix A: formulas used

* Joseph cabin parameterisation: `A_CB = b·ℓ_rect + ½·b·ℓ_tri`, `b = FR·ℓ`, `ℓ_tri = (b/2)·tanθ`, so
  `ℓ = sqrt(A_CB / (FR·(1 − FR·tanθ/4)))`.
* Joseph outer-wing junction loads (for hand checks of the SOL144 kink loads): `L0 = 8·L_OW/(π·b_ow)`,
  `V_OW = L_OW`, `M_OW = L0·b_ow²/12` (with `L_OW = TOGW/3` in Joseph; use the SOL144 share here).
* Bredt–Batho: single cell `J = 4A²/∮ds/t`; multi-cell `D·q = 2A·Gθ'`, `J = 2·ΣA_i q_i`.
* DLM box size: `Δx ≤ 0.08·V/f_max`; box aspect ratio ≲ 3.
* PSHELL PRSEUS: `12I/T³ = 12·I_panel/t_eff³`, `t_eff = (A_skin + A_str)/pitch`.
* Quasi-isotropic IM7-8552 `[0/±45/90]s`: E = 56.1 GPa, G = 21.4 GPa, ν = 0.31, ρ = 1 578 kg/m³.
