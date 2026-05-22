/*
    Parametric OpenSCAD gear assembly.

    This file demonstrates script-to-solid generation for an interlocking gear
    pair. The model exposes core mechanical parameters, computes pitch geometry
    from those parameters, builds an involute-inspired tooth profile, and places
    both gears at the correct center distance.
*/

$fn = 120;

gear_a_teeth = 28;
gear_b_teeth = 18;
gear_module = 2.4;
gear_thickness = 8;
pressure_angle = 20;
backlash_degrees = 0.42;
bore_radius = 4.2;
hub_radius_factor = 0.36;
spoke_ratio = 0.16;

function pitch_radius(teeth, module_size) = teeth * module_size / 2;
function addendum(module_size) = module_size;
function dedendum(module_size) = 1.25 * module_size;
function outer_radius(teeth, module_size) = pitch_radius(teeth, module_size) + addendum(module_size);
function root_radius(teeth, module_size) = pitch_radius(teeth, module_size) - dedendum(module_size);
function base_radius(teeth, module_size, pressure) = pitch_radius(teeth, module_size) * cos(pressure);
function rad_to_deg(value) = value * 180 / PI;
function polar(radius, angle_degrees) = [radius * cos(angle_degrees), radius * sin(angle_degrees)];

/*
    Approximate involute flank point.

    OpenSCAD trigonometric functions consume degrees, while the involute
    parameter t is naturally expressed in radians. rad_to_deg bridges that
    difference so the formula remains readable.
*/
function involute_point(base_r, t) = [
    base_r * (cos(rad_to_deg(t)) + t * sin(rad_to_deg(t))),
    base_r * (sin(rad_to_deg(t)) - t * cos(rad_to_deg(t)))
];

function involute_t_at_radius(base_r, target_r) =
    sqrt(max((target_r * target_r) / (base_r * base_r) - 1, 0));

module involute_tooth(teeth, module_size, pressure, backlash) {
    tooth_pitch = 360 / teeth;
    root_r = root_radius(teeth, module_size);
    outer_r = outer_radius(teeth, module_size);
    base_r = base_radius(teeth, module_size, pressure);
    t_outer = involute_t_at_radius(base_r, outer_r);
    flank_steps = 5;
    tooth_half_angle = tooth_pitch * 0.25 - backlash * 0.5;
    root_half_angle = tooth_pitch * 0.48 - backlash;

    left_flank = [
        for (i = [0 : flank_steps])
            let (
                t = t_outer * i / flank_steps,
                p = involute_point(base_r, t),
                angle = atan2(p[1], p[0]),
                radius = sqrt(p[0] * p[0] + p[1] * p[1])
            )
            polar(radius, angle - tooth_half_angle)
    ];

    right_flank = [
        for (i = [flank_steps : -1 : 0])
            let (
                t = t_outer * i / flank_steps,
                p = involute_point(base_r, t),
                angle = atan2(p[1], p[0]),
                radius = sqrt(p[0] * p[0] + p[1] * p[1])
            )
            polar(radius, -angle + tooth_half_angle)
    ];

    polygon(points = concat(
        [polar(root_r, -root_half_angle)],
        left_flank,
        right_flank,
        [polar(root_r, root_half_angle)]
    ));
}

module gear_outline_2d(teeth, module_size, pressure, backlash) {
    root_r = root_radius(teeth, module_size);
    union() {
        circle(r = root_r);
        for (tooth_index = [0 : teeth - 1]) {
            rotate(tooth_index * 360 / teeth)
                involute_tooth(teeth, module_size, pressure, backlash);
        }
    }
}

module hub_and_spokes_2d(teeth, module_size, bore_r, hub_factor, spoke_width_ratio) {
    pitch_r = pitch_radius(teeth, module_size);
    hub_r = pitch_r * hub_factor;
    web_r = pitch_r * 0.82;
    spoke_count = teeth < 22 ? 5 : 6;

    difference() {
        union() {
            circle(r = hub_r);
            for (spoke_index = [0 : spoke_count - 1]) {
                rotate(spoke_index * 360 / spoke_count)
                    translate([web_r * 0.5, 0, 0])
                        square([web_r, pitch_r * spoke_width_ratio], center = true);
            }
        }
        circle(r = bore_r);
    }
}

module parametric_gear(teeth, module_size, thickness, bore_r, pressure, backlash, hub_factor, spoke_width_ratio) {
    pitch_r = pitch_radius(teeth, module_size);
    difference() {
        union() {
            linear_extrude(height = thickness, center = true, convexity = 12)
                gear_outline_2d(teeth, module_size, pressure, backlash);

            linear_extrude(height = thickness * 1.18, center = true, convexity = 8)
                hub_and_spokes_2d(teeth, module_size, bore_r, hub_factor, spoke_width_ratio);

            cylinder(h = thickness * 1.45, r = pitch_r * hub_factor, center = true);
        }
        cylinder(h = thickness * 2.4, r = bore_r, center = true);
    }
}

module pitch_circle(teeth, module_size, thickness) {
    color([0.1, 0.82, 1.0, 0.24])
        translate([0, 0, thickness * 0.62])
            linear_extrude(height = 0.32, center = true)
                difference() {
                    circle(r = pitch_radius(teeth, module_size) + 0.12);
                    circle(r = pitch_radius(teeth, module_size) - 0.12);
                }
}

module centerline(distance, thickness) {
    color([0.12, 0.13, 0.14])
        translate([distance * 0.5, 0, -thickness * 0.72])
            cube([distance, 3.6, 1.25], center = true);
}

module gear_pair() {
    radius_a = pitch_radius(gear_a_teeth, gear_module);
    radius_b = pitch_radius(gear_b_teeth, gear_module);
    center_distance = radius_a + radius_b;
    gear_b_mesh_phase = 180 / gear_b_teeth;

    echo("gear_a_pitch_radius", radius_a);
    echo("gear_b_pitch_radius", radius_b);
    echo("center_distance", center_distance);

    color([0.78, 0.82, 0.88])
        parametric_gear(
            gear_a_teeth,
            gear_module,
            gear_thickness,
            bore_radius,
            pressure_angle,
            backlash_degrees,
            hub_radius_factor,
            spoke_ratio
        );
    pitch_circle(gear_a_teeth, gear_module, gear_thickness);

    translate([center_distance, 0, 0])
        rotate([0, 0, 180 + gear_b_mesh_phase])
            color([0.32, 0.68, 0.94])
                parametric_gear(
                    gear_b_teeth,
                    gear_module,
                    gear_thickness,
                    bore_radius * 0.82,
                    pressure_angle,
                    backlash_degrees,
                    hub_radius_factor,
                    spoke_ratio
                );

    translate([center_distance, 0, 0])
        pitch_circle(gear_b_teeth, gear_module, gear_thickness);

    centerline(center_distance + radius_b * 0.9, gear_thickness);
}

gear_pair();
