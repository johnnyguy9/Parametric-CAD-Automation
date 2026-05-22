# AI-Driven Parametric CAD Automation

## Executive Summary

This repository demonstrates programmatic spatial logic for automated industrial asset generation. It contains two complementary CAD automation examples: a FreeCAD Python generator for a fully parametric mechanical mounting bracket, and an OpenSCAD generator for a mathematically controlled interlocking gear assembly.

The work is framed around the same engineering pattern used in advanced automation systems: parameters define intent, scripts transform that intent into precise geometry, and CAD kernels compile the result into manufacturable 3D assets.

## System Architecture

The repository is intentionally compact and inspectable:

- `freecad_bracket_generator.py` defines a parametric L-bracket using Python, FreeCAD's Part workbench, and OpenCASCADE-backed boolean geometry.
- `parametric_gear_assembly.scad` defines a gear pair using OpenSCAD modules, trigonometric tooth generation, pitch-circle alignment, bores, hubs, and webbing.
- `README.md` documents the purpose, architecture, technologies, and execution path for review or extension.

The architecture separates inputs, geometry construction, and model publication. This lets an engineer change high-level design variables such as length, thickness, hole count, gear teeth, module size, or bore radius without manually remodeling the asset.

## Core Technologies

### Python

Python is used as the automation layer for the FreeCAD model. The script defines typed parameter structures, validates dimensions, computes aligned feature placement, and orchestrates C++ geometry operations through FreeCAD's Python API.

### FreeCAD

FreeCAD provides the parametric CAD environment and exposes the `FreeCAD` and `Part` modules to Python. The bracket generator creates exact solid primitives, fuses bracket components, subtracts bolt-hole cylinders, applies fillets, and publishes the result into a FreeCAD document.

### OpenSCAD

OpenSCAD is used for declarative script-to-model compilation. The gear assembly is generated from modules and functions that describe pitch radius, root radius, addendum, dedendum, tooth profiles, hubs, bores, and assembly alignment. Trigonometric polar coordinates drive the tooth geometry.

## Implementation Instructions

### FreeCAD Bracket Generator

1. Open FreeCAD.
2. Open the Python console.
3. Run:

   ```python
   exec(open("freecad_bracket_generator.py").read())
   ```

4. Adjust values in the `BracketParameters` object to regenerate alternate mounting bracket configurations.

The script prints base bolt centers and wall hole centers to the FreeCAD console so the generated feature layout can be inspected numerically.

### OpenSCAD Gear Assembly

1. Open OpenSCAD.
2. Load `parametric_gear_assembly.scad`.
3. Press Preview or Render.
4. Modify variables such as:

   - `gear_a_teeth`
   - `gear_b_teeth`
   - `gear_module`
   - `module_thickness`
   - `pressure_angle`
   - `bore_radius`

The two gears are positioned using the sum of their pitch radii, which keeps the assembly mathematically aligned when tooth counts or module size change.

## Engineering Value

This repository demonstrates:

- Automated industrial asset generation.
- Programmatic CAD feature placement.
- Mathematically aligned mechanical geometry.
- Script-driven model compilation.
- Parametric design patterns suitable for rapid iteration, design variants, and AI-assisted engineering workflows.
