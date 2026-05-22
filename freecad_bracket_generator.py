"""
Parametric FreeCAD mounting bracket generator.

Run this script inside the FreeCAD Python console or through FreeCADCmd:

    exec(open("freecad_bracket_generator.py").read())

The script intentionally uses FreeCAD's native Part workbench API. The Python
layer defines the parametric construction logic, while FreeCAD delegates the
heavy boundary-representation operations to its OpenCASCADE C++ geometry kernel.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import FreeCAD as App
import Part


@dataclass(frozen=True)
class BracketParameters:
    """Dimensional inputs for the generated mechanical bracket."""

    length: float = 120.0
    width: float = 54.0
    thickness: float = 8.0
    wall_height: float = 72.0
    wall_thickness: float = 8.0
    bolt_diameter: float = 8.0
    bolt_count: int = 4
    bolt_edge_margin: float = 18.0
    wall_hole_diameter: float = 7.0
    fillet_radius: float = 2.0
    rib_count: int = 3
    rib_thickness: float = 6.0

    def validate(self) -> None:
        """Fail early if dimensions cannot produce a manufacturable solid."""

        if self.length <= 0 or self.width <= 0 or self.thickness <= 0:
            raise ValueError("Base length, width, and thickness must be positive.")
        if self.wall_height <= self.thickness:
            raise ValueError("Wall height must be greater than base thickness.")
        if self.bolt_count < 2:
            raise ValueError("At least two base bolt holes are required for alignment.")
        if self.bolt_diameter >= self.width:
            raise ValueError("Bolt diameter must be smaller than bracket width.")
        usable_span = self.length - 2.0 * self.bolt_edge_margin
        if usable_span <= 0:
            raise ValueError("Bolt edge margin leaves no usable span for bolt centers.")
        if self.fillet_radius < 0:
            raise ValueError("Fillet radius cannot be negative.")


def bolt_center_positions(params: BracketParameters) -> list[App.Vector]:
    """
    Return perfectly aligned, equidistant bolt-hole centers along the base.

    The bolt array is calculated mathematically instead of placed manually. This
    is the core CAD automation advantage: downstream geometry remains valid when
    length, count, or margins change.
    """

    span = params.length - 2.0 * params.bolt_edge_margin
    pitch = span / float(params.bolt_count - 1)
    y_center = params.width * 0.5
    z_center = params.thickness * 0.5

    return [
        App.Vector(params.bolt_edge_margin + pitch * index, y_center, z_center)
        for index in range(params.bolt_count)
    ]


def wall_hole_positions(params: BracketParameters) -> list[App.Vector]:
    """
    Return wall mounting holes centered in the vertical face.

    The two holes are vertically aligned and symmetric around the wall center,
    which makes the output stable for CNC, additive, or drawing generation.
    """

    x_positions = (params.length * 0.33, params.length * 0.67)
    y_center = params.width - params.wall_thickness * 0.5
    z_center = params.thickness + params.wall_height * 0.56
    return [App.Vector(x_value, y_center, z_center) for x_value in x_positions]


def inspection_table(params: BracketParameters) -> list[dict[str, object]]:
    """
    Build a structured feature table for downstream review or reporting.

    CAD automation is strongest when the model and its inspection metadata are
    generated from the same parameter source.
    """

    rows: list[dict[str, object]] = []
    for index, center in enumerate(bolt_center_positions(params), start=1):
        rows.append({
            "feature": f"base_bolt_{index}",
            "diameter": params.bolt_diameter,
            "center_mm": (round(center.x, 3), round(center.y, 3), round(center.z, 3)),
            "axis": "+Z",
        })

    for index, center in enumerate(wall_hole_positions(params), start=1):
        rows.append({
            "feature": f"wall_mount_{index}",
            "diameter": params.wall_hole_diameter,
            "center_mm": (round(center.x, 3), round(center.y, 3), round(center.z, 3)),
            "axis": "-Y",
        })
    return rows


def shape_metrics(shape: Part.Shape) -> dict[str, float]:
    """Return engineering metrics that help validate generated geometry."""

    bounds = shape.BoundBox
    return {
        "volume_mm3": round(shape.Volume, 3),
        "surface_area_mm2": round(shape.Area, 3),
        "bounds_x_mm": round(bounds.XLength, 3),
        "bounds_y_mm": round(bounds.YLength, 3),
        "bounds_z_mm": round(bounds.ZLength, 3),
    }


def make_base(params: BracketParameters) -> Part.Shape:
    """Create the horizontal mounting plate as an OpenCASCADE box primitive."""

    return Part.makeBox(params.length, params.width, params.thickness)


def make_wall(params: BracketParameters) -> Part.Shape:
    """
    Create the vertical rear wall of the L-bracket.

    FreeCAD's Python object creates a high-level box primitive, then the C++
    kernel stores and evaluates the exact B-Rep faces, edges, and vertices.
    """

    origin = App.Vector(0.0, params.width - params.wall_thickness, params.thickness)
    return Part.makeBox(params.length, params.wall_thickness, params.wall_height, origin)


def make_rib(params: BracketParameters, x_center: float) -> Part.Shape:
    """
    Create one triangular gusset rib joining the base to the vertical wall.

    The rib is modeled as a prism extruded from a triangular face. This produces
    a strong bracket form while keeping the generation logic parametric.
    """

    y_back = params.width - params.wall_thickness
    y_front = max(params.width * 0.45, y_back - params.wall_height * 0.42)
    z_top = params.thickness + params.wall_height * 0.72
    half_rib = params.rib_thickness * 0.5

    triangle_points = [
        App.Vector(x_center, y_back, params.thickness),
        App.Vector(x_center, y_back, z_top),
        App.Vector(x_center, y_front, params.thickness),
    ]
    wire = Part.makePolygon(triangle_points + [triangle_points[0]])
    face = Part.Face(wire)
    rib = face.extrude(App.Vector(half_rib, 0.0, 0.0))
    rib.translate(App.Vector(-half_rib, 0.0, 0.0))
    return rib


def make_cylinder_cut(center: App.Vector, radius: float, depth: float, axis: App.Vector) -> Part.Shape:
    """
    Build a cylindrical cutting tool for boolean subtraction.

    The axis argument determines which bracket face the hole passes through.
    Boolean cuts are sent to OpenCASCADE, so the resulting holes are true
    analytic cylinders rather than tessellated approximations.
    """

    return Part.makeCylinder(radius, depth, center, axis)


def fuse_all(shapes: Iterable[Part.Shape]) -> Part.Shape:
    """Fuse a collection of shapes into one solid using robust kernel booleans."""

    iterator = iter(shapes)
    fused = next(iterator)
    for shape in iterator:
        fused = fused.fuse(shape)
    return fused.removeSplitter()


def apply_bolt_holes(solid: Part.Shape, params: BracketParameters) -> Part.Shape:
    """Cut the parametric base and wall bolt-hole arrays from the bracket."""

    result = solid
    base_hole_radius = params.bolt_diameter * 0.5
    wall_hole_radius = params.wall_hole_diameter * 0.5

    for center in bolt_center_positions(params):
        cutter_origin = App.Vector(center.x, center.y, -params.thickness)
        cutter = make_cylinder_cut(cutter_origin, base_hole_radius, params.thickness * 3.0, App.Vector(0, 0, 1))
        result = result.cut(cutter)

    for center in wall_hole_positions(params):
        cutter_origin = App.Vector(center.x, params.width + params.wall_thickness, center.z)
        cutter = make_cylinder_cut(cutter_origin, wall_hole_radius, params.wall_thickness * 4.0, App.Vector(0, -1, 0))
        result = result.cut(cutter)

    return result.removeSplitter()


def apply_fillets(solid: Part.Shape, params: BracketParameters) -> Part.Shape:
    """
    Apply a controlled edge fillet to improve manufactured part quality.

    Fillets are intentionally conservative because overly large radii can fail
    on short edges after boolean hole operations.
    """

    if params.fillet_radius <= 0:
        return solid

    candidate_edges = []
    for edge in solid.Edges:
        candidate_edges.append(edge)

    try:
        return solid.makeFillet(params.fillet_radius, candidate_edges).removeSplitter()
    except Exception as exc:
        App.Console.PrintWarning(f"Fillet operation skipped: {exc}\n")
        return solid


def build_bracket(params: BracketParameters) -> Part.Shape:
    """Build the complete parametric bracket as a single FreeCAD Part shape."""

    params.validate()
    base = make_base(params)
    wall = make_wall(params)

    rib_spacing = params.length / float(params.rib_count + 1)
    ribs = [make_rib(params, rib_spacing * (index + 1)) for index in range(params.rib_count)]

    bracket = fuse_all([base, wall] + ribs)
    bracket = apply_bolt_holes(bracket, params)
    bracket = apply_fillets(bracket, params)
    return bracket


def write_inspection_report(
    shape: Part.Shape,
    params: BracketParameters,
    output_path: str = "bracket_inspection_report.txt",
) -> Path:
    """
    Write a lightweight generated-model report next to the CAD document.

    The report is deliberately plain text so it can be consumed by humans, CI
    logs, or later automation without additional dependencies.
    """

    report_path = Path(output_path)
    metrics = shape_metrics(shape)
    lines = [
        "Parametric Mounting Bracket Inspection Report",
        "=" * 52,
        "",
        "Parameters:",
    ]
    for key, value in params.__dict__.items():
        lines.append(f"- {key}: {value}")

    lines.extend(["", "Computed Model Metrics:"])
    for key, value in metrics.items():
        lines.append(f"- {key}: {value}")

    lines.extend(["", "Hole Feature Table:"])
    for row in inspection_table(params):
        lines.append(
            "- {feature}: diameter={diameter}mm center={center_mm} axis={axis}".format(**row)
        )

    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return report_path


def publish_to_document(shape: Part.Shape, params: BracketParameters) -> App.Document:
    """Create a FreeCAD document object so the generated solid is visible/editable."""

    document = App.newDocument("Parametric_Mounting_Bracket")
    feature = document.addObject("Part::Feature", "Generated_Parametric_Bracket")
    feature.Shape = shape

    for key, value in params.__dict__.items():
        feature.addProperty("App::PropertyString", key, "Generation Parameters")
        setattr(feature, key, str(value))

    document.recompute()
    App.Console.PrintMessage("Parametric bracket generated successfully.\n")
    App.Console.PrintMessage(f"Model metrics: {shape_metrics(shape)}\n")
    App.Console.PrintMessage(f"Hole feature table: {inspection_table(params)}\n")
    try:
        report_path = write_inspection_report(shape, params)
        App.Console.PrintMessage(f"Inspection report written to: {report_path.resolve()}\n")
    except OSError as exc:
        App.Console.PrintWarning(f"Inspection report skipped: {exc}\n")
    return document


def main() -> App.Document:
    """Entry point used by the FreeCAD Python console."""

    parameters = BracketParameters(
        length=120.0,
        width=54.0,
        thickness=8.0,
        wall_height=72.0,
        wall_thickness=8.0,
        bolt_diameter=8.0,
        bolt_count=4,
        bolt_edge_margin=18.0,
    )
    bracket_shape = build_bracket(parameters)
    return publish_to_document(bracket_shape, parameters)


if __name__ == "__main__":
    main()
