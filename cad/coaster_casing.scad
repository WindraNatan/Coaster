// HydroCoaster - Two-Part Capsule Enclosure (Rear 28mm, Front Rim 23.2mm)
// Dibagi di y = rear_front_y (56) supaya tiap part muat di bed A1 Mini 175 mm.
// Kompartemen belakang 28mm memberi interior bersih 23.3mm di bawah tutup, cukup
// untuk female header 8.5mm + PCB + shield RF + kabel jumper.
// Bibir depan sengaja lebih rendah dari piringan atas supaya gelas hanya menumpu
// pada piringan, bukan pada bibir sasis.

$fn = 64; // Resolusi kurva lingkaran halus

// FRAME: Z-up — +X = kanan dari depan (sisi kaca), +Y = ke belakang, +Z = atas.
// Viewer web/casing_3d.html Y-up memetakan (x,y,z)_html = (-X, Z, Y)_scad, jadi angka
// x di HTML berlawanan tanda dengan x di file ini. Posisi modul di bawah sudah
// dicerminkan agar model ini sama dengan rakitan build (patokan HTML).

// --- PARAMETER DIMENSI PRESISI (mm) ---
floor_th       = 2.5;   // Tebal lantai dasar sasis
wall_th        = 2.4;   // Tebal dinding luar sasis
total_h        = 28.0;  // Tinggi kompartemen belakang

// Wadah Tatakan Depan (Tatakan Gelas Bebas 360 Derajat)
coaster_dia    = 106.0; // Piringan akrilik 100mm menyisakan 3mm celah tiap sisi
front_floor_th = 3.5;   // Lantai depan; piringan bawah duduk langsung di lantai

// --- TUMPUKAN TATAKAN (rantai kontak, satu sumber kebenaran) ---
acr_th        = 3.0;   // Tebal piringan akrilik
spacer_th     = 2.0;   // Spacer ujung tetap: ruang defleksi ujung bebas
bar_w         = 12.7;  // Lebar batang load cell
bar_th        = 12.7;  // Tinggi batang load cell
bar_l         = 80.0;  // Panjang batang load cell (spek kit: 12.7 x 12.7 x 80)
platter_th    = 3.0;   // Tebal piringan atas
platter_proud = 1.0;   // Tonjolan piringan di atas bibir depan

disc_z    = front_floor_th;               // 3.5  — piringan bawah kontak lantai
bar_z     = disc_z + acr_th + spacer_th;  // 8.5  — batang duduk di spacer
platter_z = bar_z + bar_th;               // 21.2 — piringan atas duduk di ujung bebas
// Bibir depan dihitung dari rantai ini, bukan angka bebas: kalau salah satu tebal
// berubah, bibir ikut turun dan gelas tidak akan menyentuh sasis.
front_rim_h = platter_z + platter_th - platter_proud; // 23.2 — di bawah puncak piringan

// Batas depan kompartemen elektronik. Rongga depan r=53, jadi septum >= 2.5mm.
rear_front_y = 56.0;

// Kompartemen Belakang (Rongga Bersih untuk Perfboard 50.8 x 70 mm)
pcb_w          = 50.8;  // Lebar fisik perfboard (rongga cavity_w = 54 mm, sisa 3.2 mm)
pcb_l          = 70.0;  // Panjang perfboard fisik (tidak dipotong)
cavity_w       = 54.0;  // Lebar rongga dalam bersih
cavity_l       = 74.0;  // Panjang rongga PCB: 56..130, papan 58..128
rear_center_y  = rear_front_y + cavity_l / 2; // 93.0 — pusat rongga PCB
rear_back_y    = rear_front_y + cavity_l;     // 130.0 — dinding belakang
// Pilar di ujung rongga supaya tidak menabrak papan maupun motor di dinding kiri.
screw_y_front  = rear_front_y + 3;   // 59
screw_y_back   = rear_back_y - 3;    // 127

// Sudut kapsul belakang: separuh lebar dan radius sudut yang dipakai hull.
rear_half_span = 30.0;
rear_corner_r  = 8.0;

// Sambungan seam: kerah milik part depan membungkus hidung rear yang di-inset.
// Band 5 mm menaruh baut M3x8 di tengah: lubang clearance Ø3,2 (y 56,9..60,1)
// punya margin 0,9 mm ke kedua ujung kerah. Band 3,5 mm tidak cukup — ujungnya
// di 59,5, lubang yang sama akan terbuka keluar kerah.
joint_band   = 5.0;                 // y 56..61
joint_clear  = 0.3;                 // gap radial + aksial antar part
joint_wall   = 3.5;                 // tebal dinding kerah
joint_inset  = joint_wall + joint_clear; // 3.8 — hidung rear
joint_z      = 14.0;                // sumbu baut, di dinding vertikal
joint_y      = rear_front_y + joint_band / 2; // 58.5 — tengah kerah, margin 0.9 mm
joint_d      = 3.2;                 // clearance baut M3
joint_pilot  = 2.5;                 // pilot ulir M3
joint_pilot_end = 34.0;             // ujung dalam pilot, sisa 7 mm ke rongga

// Dimensi Bibir Dudukan Tutup Atas (Shoulder Step)
lid_w          = 64.0;  // Lebar penutup atas
lid_l          = cavity_l + 4.0; // 78.0 — hanya menutupi kompartemen elektronik
lid_th         = 2.2;   // Tebal penutup atas

// Mulut colokan USB belakang. Port micro-USB ESP32 duduk di z 13.8..17.8
// (riser 1.2 + papan 1.6 + female header 8.5 + tebal PCB 1.6).
// Bukaan ikut bergeser bersama ESP32; kalau tetap di tengah, sisa 1.2 mm di satu sisi
// tidak cukup untuk selubung plug micro-USB.
usb_z          = floor_th + 10.0; // 12.5
usb_h          = 8.0;
usb_w          = 15.0;
usb_x          = -5.08;           // = posisi pusat ESP32
// Potongan harus menembus dinding luar. Badan kapsul berakhir di y = 138 (sudut belakang
// r 8 di y 130); potongan lama berhenti di 137.4 dan menyisakan kulit 0.6 mm, jadi
// lubangnya buta dari luar.
usb_cut_y0     = rear_back_y - 1;               // 129.0
usb_cut_l      = rear_corner_r + wall_th + 6;   // 16.4 -> 145.4

// Pilihan Part untuk Diekspor ("front", "rear", "lid", "all")
part_to_render = "all";
assert(part_to_render == "front" || part_to_render == "rear" ||
       part_to_render == "lid" || part_to_render == "all",
       "part_to_render harus front, rear, lid, atau all");

// --- POSISI ESP32 & BUZZER ---
// Buzzer modul 13 x 32 mm (spek: 3.2 x 1.3 x 1 cm) dipasang memanjang di strip kanan.
// Melintang butuh 32 mm di strip depan yang hanya 18 mm, jadi harus diputar.
// Kolom lubang papan: x = -21.59 + 2.54k (18 kolom, margin 3.81 ke tepi).
// Baris lubang papan: y = 63.79 + 2.54k (24 baris, margin 5.79 dari tepi depan).
// Papan 58..128; rongga 56..130.
esp_pcb_w     = 25.4;                   // DevKit V1: lebar PCB 25.4, baris pin 22.86 (9 pitch)
esp_pcb_l     = 48.26;                  // 15 pin per sisi, pangkal pin 6.35 di luar baris tepi
esp_pcb_x     = -5.08;                  // pusat; baris pin -16.51 dan 6.35 = kolom grid
esp_pcb_x0    = esp_pcb_x - esp_pcb_w / 2;  // -17.78
// 15 pin span 35.56; pusat dipilih supaya semua pin jatuh di baris grid (84.11..119.67),
// sekaligus menaruh papan sedekat mungkin ke dinding belakang (tepi 126.02).
esp_pcb_y     = 101.89;
buzzer_pcb_w  = 13.0;
buzzer_pcb_l  = 32.0;                   // spek 3.2 cm, diukur dari ujung bodi ke baris pin
// 3 pin di pitch 2.54. Pin tengah di kolom grid 16.51, jadi bodi 10.01..23.01:
// 2.39 mm ke tepi papan dan 2.39 mm ke tepi PCB ESP32.
buzzer_x      = 16.51;
buzzer_pcb_x0 = buzzer_x - buzzer_pcb_w / 2;  // 10.01
// Pin belakang modul di baris grid 91.73, jadi seluruh bodi masih di papan.
buzzer_pin_y  = 91.73;
buzzer_pcb_y0 = buzzer_pin_y - buzzer_pcb_l;  // 59.73
buzzer_y      = buzzer_pcb_y0 + 10.0;         // 69.73, can di ujung depan
buzzer_can_d  = 12.0;                   // tidak ada di spek; diperkirakan dari foto modul
buzzer_can_h  = 10.0;                   // spek: modul 32 x 13 x 10 mm
// Pin modul keluar mendatar dari ujung PCB (foto), bukan tegak ke bawah, jadi modul
// tidak bisa disolder langsung ke papan. Buzzer, motor, dan DHT11 ditempel datar,
// lalu disambung jumper female-female ke header male yang disolder di baris grid.
buzzer_lift     = 0.5;                  // tape 3M di bawah PCB modul
mod_pin_l       = 7.0;                  // panjang pin mendatar modul
mod_pin_span    = 5.08;                 // 3 pin, 2 pitch
hdr_h           = 2.5;                  // header male di atas papan
buzzer_pcb_z    = floor_th + 1.2 + 1.6 + buzzer_lift;  // 5.8
// Header pendarat jumper. Pin modul buzzer berakhir di y 98.73; baris 104.43 (k=16)
// menyisakan 1.70 mm supaya rumah jumper tidak menumpuk header.
buzzer_hdr_x    = 16.51;               // 3 pin x 13.97..19.05
buzzer_hdr_y    = 104.43;
mtr_hdr_x       = 21.59;                // kolom grid k=17 (lubang paling kanan)
mtr_hdr_y       = 96.81;

// --- POSISI DHT11 (wadah depan kiri) ---
// Modul 32 x 14 mm (spek), diputar: pin 3 keluar dari tepi pendek (foto), jadi tepi 14 mm
// menghadap septum dan jumper 3-pin bisa naik lurus lewat terowongan.
// Wadah depan terbuka penuh ke atas, jadi tidak perlu kisi ventilasi di dinding.
dht_front_w = 14.0;  // lebar PCB (x)
dht_front_l = 32.0;  // panjang PCB (y), pin di tepi +y
dht_front_h = 7.1;   // PCB 1.6 + bodi DHT 5.5
dht_front_x = -24.0; // pusat; x -31..-17
dht_front_y = 6.0;   // pusat; y -10..22, sudut terjauh r 37.9 < 50
dht_pcb_z   = disc_z + acr_th;        // 6.5, duduk di akrilik seperti HX711
dht_hdr_x   = -3.81; // kolom grid k=7; 3 pin x -6.35..-1.27 di mulut terowongan
dht_hdr_y   = 63.79; // baris grid k=0

// --- POSISI HX711 (wadah depan kanan) ---
// Papan modul duduk di atas piringan akrilik bawah, di luar jalur defleksi batang.
// Pin 4 keluar mendatar dari tepi LUAR (+x): jumper keluar menjauhi batang, lalu menyusur
// dinding kanan ke terowongan septum. Kalau pin menghadap ke dalam, jumper harus lewat
// celah sempit antara PCB dan batang load cell.
// Ukuran dari foto kit: PCB ±34.5 x 21 mm saat dikalibrasi ke disc akrilik Ø100.
hx_x      = 25.0;   // pusat modul; tepi kiri x = 7.75, batang berakhir x = 6.35
hx_y      = 6.0;    // modul memanjang sejajar sumbu x, bukan tegak
hx_w      = 34.5;
hx_l      = 21.0;
hx_th     = 1.6;
hx_hdr_l  = 10.16;  // header 4-pin, pitch 2.54
hx_hdr_w  = 2.54;
hx_hdr_h  = 8.5;    // header female 1x4, tegak di tepi luar (foto kit)
// Header pendarat jumper HX711 di papan. Empat pin ganjil-genap, jadi pusatnya harus
// di tengah antar-kolom: pin di x -1.27, 1.27, 3.81, 6.35.
hx_land_x = 2.54;
hx_land_y = 71.41;  // baris grid k=3

// --- POSISI MOTOR GETAR (menggantung di bawah tutup) ---
// Modul 23 x 21 mm (spek). Tidak muat di papan: bersama ESP32 hanya sisa 18 mm di depan,
// dan sela papan ke dinding cuma 1.6 mm. Digantung di bawah tutup di atas kaleng RF ESP32,
// jadi getaran merambat ke bodi, bukan ke load cell.
// Header male 1x3 dilepas; kabel disolder langsung ke pad. Kalau header tetap, pin 11.5 mm
// menembus shield RF (atas shield 15.5, bawah PCB modul 24.2, pin sampai 12.7).
mtr_x     = -5.08;                         // sejajar pusat ESP32
mtr_y     = 100.0;                         // di atas badan ESP32 (y 77.76..126.02)
mtr_th    = 1.6;                           // tebal PCB modul
mtr_can_h = 3.0;                           // tebal motor koin
mtr_z     = total_h - lid_th - mtr_th;     // 24.2, PCB menempel di bawah tutup

// MODUL UTAMA

// Cangkang luar bersama. Tiap part mengambil setengahnya lewat intersection dengan
// bidang y, jadi geometri luar tetap identik dengan sasis utuh.
module body_hull() {
    hull() {
        cylinder(h = front_rim_h, d = coaster_dia + 2 * wall_th);
        translate([-rear_half_span, rear_back_y, 0]) cylinder(h = total_h, r = rear_corner_r);
        translate([ rear_half_span, rear_back_y, 0]) cylinder(h = total_h, r = rear_corner_r);
        translate([-rear_half_span, rear_front_y, 0]) cylinder(h = total_h, r = rear_corner_r);
        translate([ rear_half_span, rear_front_y, 0]) cylinder(h = total_h, r = rear_corner_r);
    }
}

// Footprint 2D body_hull. Offset negatif membentuk bidang dalam kerah dan hidung,
// jadi radius tiap lingkaran tidak perlu ditulis ulang.
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

// Kerah part depan: dinding luar asli, dikurangi sampai setebal joint_wall.
// Mulai y=55, 1 mm di dalam part depan, supaya menyambung dengan badannya.
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

// Potongan yang menyeberangi bidang sambungan. Kedua part memakai geometri yang sama
// supaya dinding septum dan bahu tutup bertemu tanpa langkah.
module seam_cuts() {
    // Terowongan saluran kabel HX711 -> ESP32, menembus septum 52..58
    translate([-8, 52, floor_th])
        cube([16, rear_front_y - 52 + 2, 8]);

    // Bahu dudukan tutup, mulai 2 mm di depan seam
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

        // Cekungan tatakan depan
        translate([0, 0, front_floor_th])
            cylinder(h = total_h + 2, d = coaster_dia);

        seam_cuts();

        // Clearance M3 menembus kedua dinding kerah
        translate([-60, joint_y, joint_z])
            rotate([0, 90, 0]) cylinder(h = 120, d = joint_d);
    }
}

module rear_module() {
    difference() {
        union() {
            // Badan penuh mulai setelah band sambungan
            intersection() {
                body_hull();
                translate([-100, rear_front_y + joint_band + joint_clear, -1])
                    cube([200, 200, total_h + 2]);
            }
            // Hidung inset di band sambungan, masuk ke kerah part depan
            intersection() {
                body_hull();
                translate([-100, rear_front_y, -1])
                    cube([200, joint_band + joint_clear, total_h + 2]);
                body_prism(joint_inset);
            }
        }

        // Rongga bersih belakang
        translate([-cavity_w / 2, rear_front_y, floor_th])
            cube([cavity_w, cavity_l, total_h - floor_th]);

        seam_cuts();

        // Lubang colokan USB belakang (ikut pergeseran ESP32)
        translate([usb_x - usb_w / 2, usb_cut_y0, usb_z])
            cube([usb_w, usb_cut_l, usb_h]);

        // Empat lubang sekrup M3 di bahu dinding luar
        translate([-29, screw_y_front, 14]) cylinder(h = total_h, d = 2.8);
        translate([ 29, screw_y_front, 14]) cylinder(h = total_h, d = 2.8);
        translate([-29, screw_y_back,  14]) cylinder(h = total_h, d = 2.8);
        translate([ 29, screw_y_back,  14]) cylinder(h = total_h, d = 2.8);

        // Pilot M3 seam: buta, berhenti 7 mm dari dinding rongga x=27
        for (s = [-1, 1])
            translate([s * joint_pilot_end, joint_y, joint_z])
                rotate([0, s * 90, 0]) cylinder(h = 26, d = joint_pilot);
    }
}

// Sasis utuh untuk pratinjau perakitan; ekspor cetak memakai front dan rear terpisah.
module capsule_chassis() {
    union() { front_module(); rear_module(); }
}

module capsule_lid() {
    difference() {
        // Plat Penutup Rata (Flush Lid) — hanya di atas kompartemen PCB
        translate([-(lid_w - 0.6) / 2, rear_center_y - (lid_l - 0.6) / 2, 0])
            cube([lid_w - 0.6, lid_l - 0.6, lid_th]);

        // 4 Lubang Baut M3 Countersunk
        translate([-29, screw_y_front, -1]) cylinder(h = lid_th + 2, d = 3.2);
        translate([ 29, screw_y_front, -1]) cylinder(h = lid_th + 2, d = 3.2);
        translate([-29, screw_y_back,  -1]) cylinder(h = lid_th + 2, d = 3.2);
        translate([ 29, screw_y_back,  -1]) cylinder(h = lid_th + 2, d = 3.2);

        // Kisi Lubang Suara Buzzer — 3x3, seluruhnya di dalam can 9.5mm
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

// RENDERING
if (part_to_render == "front") {
    front_module();
} else if (part_to_render == "rear") {
    rear_module();
} else if (part_to_render == "lid") {
    capsule_lid();
} else {
    // Mode Perakitan Lengkap
    color("DimGray") capsule_chassis();
    color("SlateGray", 0.7) translate([0, 0, total_h]) capsule_lid();

    // Piringan akrilik bawah (duduk di lantai)
    color("Cyan", 0.4) translate([0, 0, disc_z]) cylinder(h = acr_th, d = 100);
    // Spacer ujung tetap: hanya ujung utara yang bertumpu, ujung selatan menggantung
    color("Gainsboro") translate([-6.35, 30, disc_z + acr_th]) cube([12.7, 10, spacer_th]);
    // Batang load cell 80 mm (spek kit), cantilever: ujung belakang tetap, ujung depan bebas
    color("Silver") translate([-bar_w / 2, -40, bar_z]) cube([bar_w, bar_l, bar_th]);
    // Piringan atas — duduk di ujung bebas batang
    color("Peru", 0.6) translate([0, 0, platter_z]) cylinder(h = platter_th, d = 100);

    // Modul HX711 (wadah depan kanan), 34.5 x 21 mm. Header 4-pin di tepi luar supaya
    // kabel keluar menjauh dari batang load cell: tepi kiri PCB 1.4 mm dari batang.
    color("ForestGreen")
        translate([hx_x - hx_w / 2, hx_y - hx_l / 2, disc_z + acr_th])
            cube([hx_w, hx_l, hx_th]);
    color("Black")
        translate([hx_x + hx_w / 2, hx_y - hx_hdr_l / 2, disc_z + acr_th + hx_th])
            cube([hx_hdr_w, hx_hdr_l, hx_hdr_h]);

    // Modul DHT11 diputar: pin 3 keluar mendatar ke +y, jumper naik lurus lewat
    // terowongan septum (x -8..8, y 52..56).
    color("DodgerBlue")
        translate([dht_front_x - dht_front_w / 2, dht_front_y - dht_front_l / 2, dht_pcb_z])
            cube([dht_front_w, dht_front_l, dht_front_h]);
    color("Silver")
        translate([dht_front_x - mod_pin_span / 2, dht_front_y + dht_front_l / 2,
                   dht_pcb_z + 0.5])
            cube([mod_pin_span, mod_pin_l, 0.6]);

    // Papan Perfboard 50.8 x 70 penuh (drop-in rongga PCB)
    color("SaddleBrown", 0.8)
        translate([-pcb_w / 2, rear_front_y + 2, floor_th + 1.2])
            cube([pcb_w, pcb_l, 1.6]);

    // Modul ESP32 DevKit V1, digeser 2 pitch ke kiri dari pusat papan.
    color("DimGray")
        translate([esp_pcb_x0, esp_pcb_y - esp_pcb_l / 2, floor_th + 1.2 + 1.6 + 8.5])
            cube([esp_pcb_w, esp_pcb_l, 1.6]);

    // Modul buzzer 13 x 32 mm duduk datar di strip kanan papan dengan tape 0.5 mm.
    // Pin keluar mendatar dari tepi belakang PCB (foto MH-FMD), jadi modul tidak bisa
    // disolder ke papan; jumper 3-pin female-female turun ke header male di papan.
    color("SteelBlue")
        translate([buzzer_pcb_x0, buzzer_pcb_y0, buzzer_pcb_z])
            cube([buzzer_pcb_w, buzzer_pcb_l, 1.6]);
    color("Black")
        translate([buzzer_x, buzzer_y, buzzer_pcb_z + 1.6])
            cylinder(h = buzzer_can_h, d = buzzer_can_d);
    color("Silver")
        translate([buzzer_x - mod_pin_span / 2, buzzer_pcb_y0 + buzzer_pcb_l, buzzer_pcb_z + 0.5])
            cube([mod_pin_span, mod_pin_l, 0.6]);
    // Header male 3-pin tempat jumper mendarat, deret sejajar x di baris grid 104.43.
    color("DimGray")
        translate([buzzer_hdr_x - 3.81, buzzer_hdr_y - 1.27, floor_th + 1.2 + 1.6])
            cube([7.62, 2.54, hdr_h]);
    // Header motor 3-pin, deret sejajar y di kolom grid 21.59. Deret y-nya mulai 93.00,
    // di belakang tepi PCB buzzer (91.73), jadi tidak menumpuk modul buzzer.
    color("DimGray")
        translate([mtr_hdr_x - 1.27, mtr_hdr_y - 3.81, floor_th + 1.2 + 1.6])
            cube([2.54, 7.62, hdr_h]);
    // Header DHT11 3-pin, di mulut terowongan septum.
    color("DimGray")
        translate([dht_hdr_x - 3.81, dht_hdr_y - 1.27, floor_th + 1.2 + 1.6])
            cube([7.62, 2.54, hdr_h]);
    // Header pendarat jumper HX711 4-pin, satu baris di belakang header DHT.
    color("DimGray")
        translate([hx_land_x - 5.08, hx_land_y - 1.27, floor_th + 1.2 + 1.6])
            cube([10.16, 2.54, hdr_h]);
    // Modul motor getar 23 x 21 mm, PCB menempel di bawah tutup, motor koin menggantung.
    // Pin 3 keluar mendatar ke -x; kabel disolder ke pad karena header male 11.5 mm
    // akan menembus shield RF di bawahnya. Rumah jumper tidak dipakai: tebal 2.5 mm
    // dari bidang pin (25.0) akan menembus tutup bawah 25.8.
    color("DimGray")
        translate([mtr_x - 11.5, mtr_y - 10.5, mtr_z])
            cube([23, 21, mtr_th]);
    color("Silver")
        translate([mtr_x - 4.5, mtr_y - 4.5, mtr_z - mtr_can_h])
            cylinder(h = mtr_can_h, d = 9);
    // Pin 3 keluar mendatar ke +x, ke arah header pendarat di x 21.59. Kalau dibalik
    // ke -x, kabel harus menyeberang papan 41 mm; posisi ini hanya 11.7 mm dari header.
    color("Silver")
        translate([mtr_x + 11.5, mtr_y - mod_pin_span / 2, mtr_z + 0.5])
            cube([mod_pin_l, mod_pin_span, 0.6]);
}
