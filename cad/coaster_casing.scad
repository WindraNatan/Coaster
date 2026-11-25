// Casing dua part terpisah di y=rear_front_y (56) agar muat di bed A1 Mini (175 mm).
// Bibir depan lebih rendah dari piringan atas agar gelas tidak menyentuh sasis.

$fn = 64;

floor_th       = 2.5;
wall_th        = 2.4;
total_h        = 28.0;

coaster_dia    = 106.0;
front_floor_th = 3.5;

acr_th        = 3.0;
spacer_th     = 2.0;  // ruang defleksi ujung bebas load cell
bar_w         = 12.7;
bar_th        = 12.7;
bar_l         = 80.0;
platter_th    = 3.0;
platter_proud = 1.0;

disc_z    = front_floor_th;
bar_z     = disc_z + acr_th + spacer_th;
platter_z = bar_z + bar_th;
// Hitung bibir depan dari rantai kontak agar perubahan tebal tetap menyisakan tonjolan piringan.
front_rim_h = platter_z + platter_th - platter_proud;

// Batas septum (rongga depan r=53, menyisakan >= 2.5 mm).
rear_front_y = 56.0;

pcb_w          = 50.8;
pcb_l          = 70.0;
cavity_w       = 54.0;
cavity_l       = 74.0;
rear_center_y  = rear_front_y + cavity_l / 2;
rear_back_y    = rear_front_y + cavity_l;
screw_y_front  = rear_front_y + 3;
screw_y_back   = rear_back_y - 3;

rear_half_span = 30.0;
rear_corner_r  = 8.0;

// Band 5 mm menempatkan lubang M3x8 di tengah kerah dengan margin 0.9 mm.
joint_band   = 5.0;
joint_clear  = 0.3;
joint_wall   = 3.5;
joint_inset  = joint_wall + joint_clear;
joint_z      = 14.0;
joint_y      = rear_front_y + joint_band / 2;
joint_d      = 3.2;
joint_pilot  = 2.5;
joint_pilot_end = 34.0;  // pilot buta; menyisakan 7 mm ke rongga

lid_w          = 64.0;
lid_l          = cavity_l + 4.0;
lid_th         = 2.2;

// Posisi x mengikuti offset ESP32 agar plug micro-USB tidak terjepit satu sisi.
usb_z          = floor_th + 10.0;
usb_h          = 8.0;
usb_w          = 15.0;
usb_x          = -5.08;
// Potongan harus menembus dinding luar kapsul (y=138), bukan berhenti di rongga (y=130).
usb_cut_y0     = rear_back_y - 1;
usb_cut_l      = rear_corner_r + wall_th + 6;

part_to_render = "all";
assert(part_to_render == "front" || part_to_render == "rear" ||
       part_to_render == "lid" || part_to_render == "all",
       "part_to_render harus front, rear, lid, atau all");

// Buzzer dipasang memanjang di strip kanan karena 32 mm tidak muat melintang di depan ESP32 (18 mm).
// Grid lubang perfboard: x = -21.59 + 2.54k, y = 63.79 + 2.54k.
esp_pcb_w     = 25.4;
esp_pcb_l     = 48.26;
esp_pcb_x     = -5.08;
esp_pcb_x0    = esp_pcb_x - esp_pcb_w / 2;
esp_pcb_y     = 101.89;
buzzer_pcb_w  = 13.0;
buzzer_pcb_l  = 32.0;
buzzer_x      = 16.51;
buzzer_pcb_x0 = buzzer_x - buzzer_pcb_w / 2;
buzzer_pin_y  = 91.73;
buzzer_pcb_y0 = buzzer_pin_y - buzzer_pcb_l;
buzzer_y      = buzzer_pcb_y0 + 10.0;
buzzer_can_d  = 12.0;
buzzer_can_h  = 10.0;
// Pin keluar mendatar sehingga modul ditempel tape dan disambung kabel female ke titik solder papan.
buzzer_lift     = 0.5;
mod_pin_l       = 7.0;
mod_pin_span    = 5.08;
hdr_h           = 2.5;
buzzer_pcb_z    = floor_th + 1.2 + 1.6 + buzzer_lift;
buzzer_hdr_x    = 16.51;
buzzer_hdr_y    = 104.43;
mtr_hdr_x       = 21.59;
mtr_hdr_y       = 96.81;

// DHT11 menghadap +y agar kabel 3 pin naik lurus lewat terowongan septum.
dht_front_w = 14.0;
dht_front_l = 32.0;
dht_front_h = 7.1;
dht_front_x = -24.0;
dht_front_y = 6.0;
dht_pcb_z   = disc_z + acr_th;
dht_hdr_x   = -3.81;
dht_hdr_y   = 63.79;

// Header HX711 menghadap +x (menjauhi batang load cell) agar kabel menyusur dinding kanan.
hx_x      = 25.0;
hx_y      = 6.0;
hx_w      = 34.5;
hx_l      = 21.0;
hx_th     = 1.6;
hx_hdr_l  = 10.16;
hx_hdr_w  = 2.54;
hx_hdr_h  = 8.5;
// Pusat 4 pin berada di antara dua kolom grid karena jumlah pin genap.
hx_land_x = 2.54;
hx_land_y = 71.41;

// Motor digantung di bawah tutup karena papan penuh; header dilepas agar pin tidak menembus shield RF.
mtr_x     = -5.08;
mtr_y     = 100.0;
mtr_th    = 1.6;
mtr_can_h = 3.0;
mtr_z     = total_h - lid_th - mtr_th;

module body_hull() {
    hull() {
        cylinder(h = front_rim_h, d = coaster_dia + 2 * wall_th);
        translate([-rear_half_span, rear_back_y, 0]) cylinder(h = total_h, r = rear_corner_r);
        translate([ rear_half_span, rear_back_y, 0]) cylinder(h = total_h, r = rear_corner_r);
        translate([-rear_half_span, rear_front_y, 0]) cylinder(h = total_h, r = rear_corner_r);
        translate([ rear_half_span, rear_front_y, 0]) cylinder(h = total_h, r = rear_corner_r);
    }
}

module body_hull2d() {
    hull() {
        circle(d = coaster_dia + 2 * wall_th);
        translate([-rear_half_span, rear_front_y]) circle(r = rear_corner_r);
        translate([ rear_half_span, rear_front_y]) circle(r = rear_corner_r);
        translate([-rear_half_span, rear_back_y]) circle(r = rear_corner_r);
        translate([ rear_half_span, rear_back_y]) circle(r = rear_corner_r);
    }
}

module body_prism(inset) {
    linear_extrude(height = total_h + 2)
        offset(delta = -inset) body_hull2d();
}

// Kerah mulai y=55 (1 mm di dalam part depan) agar menyatu dengan badan depan.
module seam_collar() {
    difference() {
        intersection() {
            body_hull();
            translate([-100, rear_front_y - 1, -1])
                cube([200, joint_band + 1, total_h + 2]);
        }
        body_prism(joint_wall);
    }
}

// Potongan bersama di bidang sambungan agar septum dan bahu tutup sejajar antar part.
module seam_cuts() {
    translate([-8, 52, floor_th])
        cube([16, rear_front_y - 52 + 2, 8]);

    translate([-lid_w / 2, rear_center_y - lid_l / 2, total_h - lid_th])
        cube([lid_w, lid_l, lid_th + 1]);
}

module front_module() {
    difference() {
        union() {
            intersection() {
                body_hull();
                translate([-100, -100, -1]) cube([200, rear_front_y + 100, total_h + 2]);
            }
            seam_collar();
        }

        translate([0, 0, front_floor_th])
            cylinder(h = total_h + 2, d = coaster_dia);

        seam_cuts();

        translate([-60, joint_y, joint_z])
            rotate([0, 90, 0]) cylinder(h = 120, d = joint_d);
    }
}

module rear_module() {
    difference() {
        union() {
            intersection() {
                body_hull();
                translate([-100, rear_front_y + joint_band + joint_clear, -1])
                    cube([200, 200, total_h + 2]);
            }
            intersection() {
                body_hull();
                translate([-100, rear_front_y, -1])
                    cube([200, joint_band + joint_clear, total_h + 2]);
                body_prism(joint_inset);
            }
        }

        translate([-cavity_w / 2, rear_front_y, floor_th])
            cube([cavity_w, cavity_l, total_h - floor_th]);

        seam_cuts();

        translate([usb_x - usb_w / 2, usb_cut_y0, usb_z])
            cube([usb_w, usb_cut_l, usb_h]);

        translate([-29, screw_y_front, 14]) cylinder(h = total_h, d = 2.8);
        translate([ 29, screw_y_front, 14]) cylinder(h = total_h, d = 2.8);
        translate([-29, screw_y_back,  14]) cylinder(h = total_h, d = 2.8);
        translate([ 29, screw_y_back,  14]) cylinder(h = total_h, d = 2.8);

        for (s = [-1, 1])
            translate([s * joint_pilot_end, joint_y, joint_z])
                rotate([0, s * 90, 0]) cylinder(h = 26, d = joint_pilot);
    }
}

module capsule_chassis() {
    union() { front_module(); rear_module(); }
}

module capsule_lid() {
    difference() {
        translate([-(lid_w - 0.6) / 2, rear_center_y - (lid_l - 0.6) / 2, 0])
            cube([lid_w - 0.6, lid_l - 0.6, lid_th]);

        translate([-29, screw_y_front, -1]) cylinder(h = lid_th + 2, d = 3.2);
        translate([ 29, screw_y_front, -1]) cylinder(h = lid_th + 2, d = 3.2);
        translate([-29, screw_y_back,  -1]) cylinder(h = lid_th + 2, d = 3.2);
        translate([ 29, screw_y_back,  -1]) cylinder(h = lid_th + 2, d = 3.2);

        translate([buzzer_x, buzzer_y, -1]) {
            for (dx = [-2.6:2.6:2.6]) {
                for (dy = [-2.6:2.6:2.6]) {
                    translate([dx, dy, 0])
                        cylinder(h = lid_th + 2, d = 2.0);
                }
            }
        }
    }
}

if (part_to_render == "front") {
    front_module();
} else if (part_to_render == "rear") {
    rear_module();
} else if (part_to_render == "lid") {
    capsule_lid();
} else {
    color("DimGray") capsule_chassis();
    color("SlateGray", 0.7) translate([0, 0, total_h]) capsule_lid();

    color("Cyan", 0.4) translate([0, 0, disc_z]) cylinder(h = acr_th, d = 100);
    color("Gainsboro") translate([-6.35, 30, disc_z + acr_th]) cube([12.7, 10, spacer_th]);
    color("Silver") translate([-bar_w / 2, -40, bar_z]) cube([bar_w, bar_l, bar_th]);
    color("Peru", 0.6) translate([0, 0, platter_z]) cylinder(h = platter_th, d = 100);

    color("ForestGreen")
        translate([hx_x - hx_w / 2, hx_y - hx_l / 2, disc_z + acr_th])
            cube([hx_w, hx_l, hx_th]);
    color("Black")
        translate([hx_x + hx_w / 2, hx_y - hx_hdr_l / 2, disc_z + acr_th + hx_th])
            cube([hx_hdr_w, hx_hdr_l, hx_hdr_h]);

    color("DodgerBlue")
        translate([dht_front_x - dht_front_w / 2, dht_front_y - dht_front_l / 2, dht_pcb_z])
            cube([dht_front_w, dht_front_l, dht_front_h]);
    color("Silver")
        translate([dht_front_x - mod_pin_span / 2, dht_front_y + dht_front_l / 2,
                   dht_pcb_z + 0.5])
            cube([mod_pin_span, mod_pin_l, 0.6]);

    color("SaddleBrown", 0.8)
        translate([-pcb_w / 2, rear_front_y + 2, floor_th + 1.2])
            cube([pcb_w, pcb_l, 1.6]);

    color("DimGray")
        translate([esp_pcb_x0, esp_pcb_y - esp_pcb_l / 2, floor_th + 1.2 + 1.6 + 8.5])
            cube([esp_pcb_w, esp_pcb_l, 1.6]);

    color("SteelBlue")
        translate([buzzer_pcb_x0, buzzer_pcb_y0, buzzer_pcb_z])
            cube([buzzer_pcb_w, buzzer_pcb_l, 1.6]);
    color("Black")
        translate([buzzer_x, buzzer_y, buzzer_pcb_z + 1.6])
            cylinder(h = buzzer_can_h, d = buzzer_can_d);
    color("Silver")
        translate([buzzer_x - mod_pin_span / 2, buzzer_pcb_y0 + buzzer_pcb_l, buzzer_pcb_z + 0.5])
            cube([mod_pin_span, mod_pin_l, 0.6]);
    color("DimGray")
        translate([buzzer_hdr_x - 3.81, buzzer_hdr_y - 1.27, floor_th + 1.2 + 1.6])
            cube([7.62, 2.54, hdr_h]);
    color("DimGray")
        translate([mtr_hdr_x - 1.27, mtr_hdr_y - 3.81, floor_th + 1.2 + 1.6])
            cube([2.54, 7.62, hdr_h]);
    color("DimGray")
        translate([dht_hdr_x - 3.81, dht_hdr_y - 1.27, floor_th + 1.2 + 1.6])
            cube([7.62, 2.54, hdr_h]);
    color("DimGray")
        translate([hx_land_x - 5.08, hx_land_y - 1.27, floor_th + 1.2 + 1.6])
            cube([10.16, 2.54, hdr_h]);
    color("DimGray")
        translate([mtr_x - 11.5, mtr_y - 10.5, mtr_z])
            cube([23, 21, mtr_th]);
    color("Silver")
        translate([mtr_x - 4.5, mtr_y - 4.5, mtr_z - mtr_can_h])
            cylinder(h = mtr_can_h, d = 9);
    // Pin modul motor harus keluar ke +x menuju header (diverifikasi verify_stackup.py).
    color("Silver")
        translate([mtr_x + 11.5, mtr_y - mod_pin_span / 2, mtr_z + 0.5])
            cube([mod_pin_l, mod_pin_span, 0.6]);
}
