/*
    Parametric OpenSCAD gear assembly.

    OpenSCAD compiles this declarative script into constructive solid geometry.
    The code below defines tooth profiles with polar coordinates, repeats them
    around each pitch circle, and places two gears at the mathematically correct
    center distance so the pitch circles are tangent.
*/

$fn = 96;

gear_a_teeth = 28;
gear_b_teeth = 18;
module_thickness = 8;
gear_module = 2.4;
pressure_angle = 20;
bore_radius = 4.2;
hub_radius_factor = 0.36;
backlash_degrees = 0.45;

function pitch_radius(teeth, module_size) = teeth * module_size / 2;
function addendum(module_size) = module_size;
function dedendum(module_size) = 1.25 * module_size;
function outer_radius(teeth, module_size) = pitch_radius(teeth, module_size) + addendum(module_size);
function root_radius(teeth, module_size) = pitch_radius(teeth, module_size) - dedendum(module_size);
function polar(radius, angle_degrees) = [radius * cos(angle_degrees), radius * sin(angle_degrees)];

/*
    A single tooth is represented as a flank polygon.

    Industrial gears normally use an involute curve. This demo keeps the mesh
    compact for portfolio review while preserving the important parametric
    relationships: pitch radius, root radius, outer radius, tooth count, angular
    pitch, backlash, and pressure-angle-informed flank width.
*/
module tooth_profile(teeth, module_size, pressure_angle_degrees, backlash) {
    tooth_pitch = 360 / teeth;
    root_r = root_radius(teeth, module_size);
    pitch_r = pitch_radius(teeth, module_size);
    outer_r = outer_radius(teeth, module_size);
    root_half_angle = tooth_pitch * 0.46 - backlash;
    pitch_half_angle = tooth_pitch * 0.27 - backlash * 0.5;
    outer_half_angle = tooth_pitch * 0.18;
    pressure_offset = tan(pressure_angle_degrees) * 0.38;

    polygon(points = [
        polar(root_r, -root_half_angle),
        polar(pitch_r, -pitch_half_angle - pressure_offset),
        polar(outer_r, -outer_half_angle),
        polar(outer_r, outer_half_angle),
        polar(pitch_r, pitch_half_angle + pressure_offset),
        polar(root_r, root_half_angle)
    ]);
}

module gear_2d(teeth, module_size, pressure_angle_degrees, backlash) {
    root_r = root_radius(teeth, module_size);
    union() {
        circle(r = root_r);
        for (tooth_index = [0 : teeth - 1]) {
            rotate(tooth_index * 360 / teeth)
                tooth_profile(teeth, module_size, pressure_angle_degrees, backlash);
        }
    }
}

module spoked_web(teeth, module_size, bore_r, hub_factor) {
    pitch_r = pitch_radius(teeth, module_size);
    hub_r = pitch_r * hub_factor;
    spoke_count = teeth < 22 ? 5 : 6;
    difference() {
        circle(r = pitch_r * 0.82);
        circle(r = hub_r);
        for (spoke_index = [0 : spoke_count - 1]) {
            rotate(spoke_index * 360 / spoke_count)
                translate([pitch_r * 0.48, 0, 0])
                    square([pitch_r * 0.48, pitch_r * 0.16], center = true);
        }
    }
    circle(r = hub_r);
    circle(r = bore_r * 1.35);
}

module parametric_gear(teeth, module_size, thickness, bore_r, pressure_angle_degrees, backlash, hub_factor) {
    pitch_r = pitch_radius(teeth, module_size);
    difference() {
        union() {
            linear_extrude(height = thickness, center = true, convexity = 10)
                gear_2d(teeth, module_size, pressure_angle_degrees, backlash);
            linear_extrude(height = thickness * 1.22, center = true, convexity = 10)
                spoked_web(teeth, module_size, bore_r, hub_factor);
            cylinder(h = thickness * 1.55, r = pitch_r * hub_factor, center = true);
        }
        cylinder(h = thickness * 2.2, r = bore_r, center = true);
    }
}

module pitch_circle(teeth, module_size, thickness) {
    color([0.1, 0.8, 1.0, 0.22])
        translate([0, 0, thickness * 0.62])
            linear_extrude(height = 0.35, center = true)
                difference() {
                    circle(r = pitch_radius(teeth, module_size) + 0.12);
                    circle(r = pitch_radius(teeth, module_size) - 0.12);
                }
}

module gear_pair() {
    radius_a = pitch_radius(gear_a_teeth, gear_module);
    radius_b = pitch_radius(gear_b_teeth, gear_module);
    center_distance = radius_a + radius_b;
    gear_b_mesh_phase = 180 / gear_b_teeth;

    color([0.78, 0.82, 0.88])
        parametric_gear(
            gear_a_teeth,
            gear_module,
            module_thickness,
            bore_radius,
            pressure_angle,
            backlash_degrees,
            hub_radius_factor
        );
    pitch_circle(gear_a_teeth, gear_module, module_thickness);

    translate([center_distance, 0, 0])
        rotate([0, 0, 180 + gear_b_mesh_phase])
            color([0.32, 0.68, 0.94])
                parametric_gear(
                    gear_b_teeth,
                    gear_module,
                    module_thickness,
                    bore_radius * 0.82,
                    pressure_angle,
                    backlash_degrees,
                    hub_radius_factor
                );

    translate([center_distance, 0, 0])
        pitch_circle(gear_b_teeth, gear_module, module_thickness);

    color([0.12, 0.13, 0.14])
        translate([center_distance * 0.5, 0, -module_thickness * 0.72])
            cube([center_distance + radius_b * 0.9, 4.0, 1.4], center = true);
}

gear_pair();
