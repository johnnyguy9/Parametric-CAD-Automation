# AI-Driven Parametric CAD Automation

Programmatic CAD automation repository demonstrating industrial asset generation with FreeCAD Python and OpenSCAD. The project converts high-level parameters into exact spatial geometry: a manufacturable mounting bracket and a paired gear assembly.

## Executive Summary

This repository demonstrates how automation can turn engineering intent into 3D assets. Instead of manually sketching features, the scripts define parameter contracts, validate dimensions, calculate feature placement mathematically, and compile geometry through mature CAD kernels.

Core signals:

- Python-driven FreeCAD generation.
- OpenCASCADE-backed boolean solid modeling.
- Parametric bolt-hole arrays and wall features.
- Scripted OpenSCAD gear assembly using pitch geometry and tooth profile logic.
- Inspection metadata for dimensions, hole centers, and model metrics.
- Documentation for review, execution, and extension.

## System Architecture

```text
Parametric-CAD-Automation
|-- freecad_bracket_generator.py
|   |-- BracketParameters validation
|   |-- Base, wall, and rib solid generation
|   |-- Equidistant bolt-hole placement
|   |-- Boolean cutting and fillet pass
|   `-- FreeCAD document publication
|-- parametric_gear_assembly.scad
|   |-- Gear parameter definitions
|   |-- Pitch/root/outer radius functions
|   |-- Tooth profile generation
|   |-- Hub, spoke, bore, pitch-circle modules
|   `-- Correct center-distance gear pairing
`-- docs
    `-- TECHNICAL_REVIEW.md
```

## Core Technologies

### Python

Python is the automation layer for the FreeCAD model. It validates inputs, computes placement, orchestrates boolean operations, and publishes data-rich CAD objects.

### FreeCAD

FreeCAD provides the document model and the `Part` API. The script delegates exact B-Rep operations to the OpenCASCADE C++ kernel through FreeCAD's Python bindings.

### OpenSCAD

OpenSCAD provides script-to-solid compilation. The gear assembly uses functions, modules, trigonometry, and constructive solid geometry to produce a parametric mechanism.

## Implementation Instructions

### FreeCAD Bracket

Open FreeCAD and run:

```python
exec(open("freecad_bracket_generator.py").read())
```

Tune values in `BracketParameters` to regenerate variants:

- `length`
- `width`
- `thickness`
- `wall_height`
- `bolt_count`
- `bolt_diameter`
- `bolt_edge_margin`
- `rib_count`

The script prints hole-center tables and model metadata to the FreeCAD console.

### OpenSCAD Gear Assembly

Open `parametric_gear_assembly.scad` in OpenSCAD and preview or render.

Primary parameters:

- `gear_a_teeth`
- `gear_b_teeth`
- `gear_module`
- `gear_thickness`
- `pressure_angle`
- `bore_radius`
- `backlash_degrees`

The gear pair is positioned by the sum of pitch radii, preserving meshing alignment when tooth counts or module size change.

## Review Guide

See [docs/TECHNICAL_REVIEW.md](docs/TECHNICAL_REVIEW.md) for validation notes, geometry assumptions, and reviewer checkpoints.

## Engineering Value

This repository demonstrates:

- Automated industrial asset generation.
- Programmatic spatial reasoning.
- Feature placement through mathematics instead of manual drafting.
- CAD-kernel integration from scripting languages.
- Clean documentation for technical review.
- A foundation for AI-assisted design variant generation.
