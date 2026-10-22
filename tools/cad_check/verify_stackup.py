"""Verify HydroCoaster platter stackup, rear cavity, and cutout placement against cad/coaster_casing.scad.

Values are read from the .scad itself (expressions resolved), so this fails loudly if a
constant is edited and the contact chain silently breaks. Complements the firmware parity
harness (tools/uji_fsm) with the mechanical equivalent: a runnable check, not a render.

The checks compare the model against measured parts, not only against itself. A stack of
internally consistent constants that no longer fits the ESP32 is what let the 22mm chassis
pass while the USB opening sat 7.7mm below the port. The board parts now come from the
seller spec sheets, not from eyeballed renders.

Run from the project root:
    python3 tools/cad_check/verify_stackup.py
"""
import re, sys, pathlib

SCAD = pathlib.Path(__file__).resolve().parents[2] / "cad" / "coaster_casing.scad"

src = SCAD.read_text()
raw = dict(re.findall(r"^(\w+)\s*=\s*([^;]+);", src, re.M))

def resolve(name, seen=()):
    if name in seen:
        raise ValueError(f"circular definition: {name}")
    expr = raw[name]
    expr = re.sub(r"[A-Za-z_]\w*",
                  lambda m: repr(resolve(m.group(0), seen + (name,))) if m.group(0) in raw else m.group(0),
                  expr)
    return eval(expr, {"__builtins__": {}}, {})

def c(name):
    if name not in raw:
        raise AssertionError(f"constant {name} not found in {SCAD.name}")
    return float(resolve(name))

total_h  = c("total_h");  front_floor_th = c("front_floor_th"); front_rim_h = c("front_rim_h")
acr_th   = c("acr_th");   spacer_th = c("spacer_th");  bar_th = c("bar_th");  platter_th = c("platter_th")
disc_z   = c("disc_z");   bar_z  = c("bar_z");   platter_z  = c("platter_z")
pcb_w    = c("pcb_w");    pcb_l  = c("pcb_l")
cavity_w = c("cavity_w"); cavity_l = c("cavity_l"); rear_front_y = c("rear_front_y")
floor_th = c("floor_th")
coaster_dia = c("coaster_dia"); wall_th = c("wall_th"); lid_th = c("lid_th")
rear_half_span = c("rear_half_span"); rear_corner_r = c("rear_corner_r")
usb_z    = c("usb_z");    usb_h = c("usb_h");    usb_w = c("usb_w")
rear_center_y = c("rear_center_y")

# Measured parts, not model constants. Change these when the part changes.
FEMALE_HDR_H  = 8.5    # 1x15 female header
ESP32_PCB_TH  = 1.6
RF_SHIELD_H   = 2.6
USB_PORT_Z0   = floor_th + 1.2 + ESP32_PCB_TH + FEMALE_HDR_H  # port sits on the ESP32 PCB top
USB_PORT_Z1   = USB_PORT_Z0 + 3.2
ACRYLIC_DIA   = 100.0

ok = []
def check(label, cond, detail):
    ok.append((label, bool(cond), detail))

# Platter contact chain: every junction must be zero gap, or weight bypasses the load cell.
check("disc kontak lantai", disc_z == front_floor_th, f"disc_z={disc_z} lantai={front_floor_th}")
check("spacer menutup disc->bar", bar_z == disc_z + acr_th + spacer_th, f"bar_z={bar_z}")
check("celah bar->platter nol", platter_z == bar_z + bar_th, f"platter_z={platter_z}")
check("spacer memberi ruang defleksi", spacer_th >= 1.5, f"spacer_th={spacer_th} mm")

# The cup must rest on the platter, never on the front rim.
proud = (platter_z + platter_th) - front_rim_h
check("platter menonjol di atas bibir", 0.3 <= proud <= 1.0, f"proud={proud:.2f} mm")
check("bibir depan lebih rendah dari belakang", front_rim_h < total_h, f"{front_rim_h} < {total_h}")

# Vertical room under the lid, against the measured ESP32 header stack.
interior_h = total_h - floor_th - lid_th
stack_h = 1.2 + ESP32_PCB_TH + FEMALE_HDR_H + ESP32_PCB_TH + RF_SHIELD_H
check("interior >= tumpukan header+shield", interior_h - stack_h >= 1.0,
      f"interior={interior_h:.1f} stack={stack_h:.1f} sisa={interior_h - stack_h:.1f}")

# USB opening must contain the port, or the cable cannot be plugged in.
check("USB dalam rongga perfboard", 0 < usb_z - floor_th and usb_z + usb_h <= total_h,
      f"z {usb_z:.1f}..{usb_z + usb_h:.1f} dalam {floor_th}..{total_h}")
check("lubang USB memuat port", usb_z <= USB_PORT_Z0 and usb_z + usb_h >= USB_PORT_Z1,
      f"lubang {usb_z:.1f}..{usb_z + usb_h:.1f} vs port {USB_PORT_Z0:.1f}..{USB_PORT_Z1:.1f}")
check("lubang USB > lebar port", usb_w >= 12.0, f"usb_w={usb_w}")
check("lubang USB sejajar port", abs(c("usb_x") - c("esp_pcb_x")) < 1e-6,
      f"usb_x={c('usb_x'):.2f} vs pusat ESP32 {c('esp_pcb_x'):.2f}")
# Containing the port means the opening edges clear the shell, not just that it is wide.
PORT_W = 7.5   # measured micro-USB shell on the DevKit V1
_hole = (c("usb_x") - usb_w / 2, c("usb_x") + usb_w / 2)
_port = (c("esp_pcb_x") - PORT_W / 2, c("esp_pcb_x") + PORT_W / 2)
check("lubang USB memuat selubung", _hole[0] <= _port[0] and _hole[1] >= _port[1],
      f"lubang {_hole[0]:.2f}..{_hole[1]:.2f} vs selubung {_port[0]:.2f}..{_port[1]:.2f}")
# The chassis hull ends at rear_back_y + rear_corner_r (138), not at the cavity wall (130).
# A cut that stops at the cavity leaves a skin and the port has no opening from outside.
_outer_y = c("rear_back_y") + c("rear_corner_r")
_cut_y1 = c("usb_cut_y0") + c("usb_cut_l")
check("lubang USB tembus dinding luar", _cut_y1 > _outer_y,
      f"potongan sampai y {_cut_y1:.1f} vs permukaan luar {_outer_y:.1f}")

# Vibration grille has to break through the outer wall, otherwise it is a blind pocket.
# The wall face is the convex hull of the front circle and the four rear corner circles,
# so it moves inward as y grows; the far vent slot is the one at risk.
import math
_hull_r = coaster_dia / 2 + wall_th
_circles = [((0.0, 0.0), _hull_r)] + [
    ((sx * rear_half_span, cy), rear_corner_r)
    for sx in (-1, 1)
    for cy in (rear_front_y, c("rear_back_y"))
]
_pts = sorted({(round(cx + r * math.cos(k * math.pi / 720), 4),
               round(cy + r * math.sin(k * math.pi / 720), 4))
              for (cx, cy), r in _circles for k in range(1440)})
def _cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
_lower, _upper = [], []
for _p in _pts:
    while len(_lower) >= 2 and _cross(_lower[-2], _lower[-1], _p) <= 0:
        _lower.pop()
    _lower.append(_p)
for _p in reversed(_pts):
    while len(_upper) >= 2 and _cross(_upper[-2], _upper[-1], _p) <= 0:
        _upper.pop()
    _upper.append(_p)
_hull = _lower[:-1] + _upper[:-1]
def hull_x_at(y):
    best = -1e9
    for i in range(len(_hull)):
        a, b = _hull[i], _hull[(i + 1) % len(_hull)]
        if (a[1] - y) * (b[1] - y) <= 0 and abs(a[1] - b[1]) > 1e-12:
            t = (y - a[1]) / (b[1] - a[1])
            best = max(best, a[0] + t * (b[0] - a[0]))
    return best

check("DHT11 di wadah depan", c("dht_front_y") < rear_front_y,
      f"dht_front_y={c('dht_front_y')} < septum {rear_front_y}")

# HX711 header faces outward (+x). Verify the whole module, header included, clears the
# load-cell bar and stays inside the front well, or the printed wall cuts it.
_hx_x, _hx_w = c("hx_x"), c("hx_w")
_hx_hdr_w, _hx_hdr_l = c("hx_hdr_w"), c("hx_hdr_l")
_hx_y, _hx_l = c("hx_y"), c("hx_l")
_hx_hdr_x0 = _hx_x + _hx_w / 2
_bar_x1 = c("bar_w") / 2
check("HX711 tidak menyentuh batang", _hx_x - _hx_w / 2 > _bar_x1,
      f"tepi PCB {_hx_x - _hx_w / 2:.2f} > batang {_bar_x1:.2f} (celah {(_hx_x - _hx_w / 2) - _bar_x1:.2f} mm)")
_well_r = coaster_dia / 2
_hx_far = max(abs(_hx_hdr_x0), abs(_hx_x + _hx_w / 2),
              *[math.hypot(abs(_hx_hdr_x0), _hx_y + sy * (_hx_l + _hx_hdr_l) / 2) for sy in (-1, 1)])
check("HX711 di dalam wadah depan", _hx_far < _well_r,
      f"radius terjauh {_hx_far:.1f} < rongga {_well_r:.1f}")
_hx_top = c("disc_z") + acr_th + c("hx_th") + c("hx_hdr_h")
check("header HX711 di bawah piringan", _hx_top < platter_z,
      f"atas header {_hx_top:.1f} < piringan {platter_z:.1f}")
check("DHT11 muat lebar wadah", abs(c("dht_front_x")) + c("dht_front_w") / 2 < coaster_dia / 2 - wall_th,
      f"tepi x={abs(c('dht_front_x')) + c('dht_front_w') / 2:.1f} < dinding {coaster_dia / 2 - wall_th:.1f}")

# ESP32 and buzzer share the 50.8 x 70 mm board: the buzzer runs lengthwise along the right
# strip because 32 mm crosswise does not fit the 18 mm in front of the ESP32.
_esp_x0, _esp_w = c("esp_pcb_x0"), c("esp_pcb_w")
_bz_x0, _bz_y0 = c("buzzer_pcb_x0"), c("buzzer_pcb_y0")
_bz_w, _bz_l = c("buzzer_pcb_w"), c("buzzer_pcb_l")
_bz_x, _bz_y = c("buzzer_x"), c("buzzer_y")
_board_x0, _board_y0 = -pcb_w / 2, rear_front_y + 2
_board_x1, _board_y1 = pcb_w / 2, _board_y0 + pcb_l
_esp_x1 = _esp_x0 + _esp_w
_esp_hdr_x1 = _esp_x0 + _esp_w / 2 + 12.7 + 1.27  # right pin row plus half header width

check("buzzer di dalam papan (x)", _board_x0 <= _bz_x0 and _bz_x0 + _bz_w <= _board_x1,
      f"buzzer {_bz_x0:.1f}..{_bz_x0 + _bz_w:.1f} dalam papan {_board_x0:.1f}..{_board_x1:.1f}")
check("buzzer di dalam papan (y)", _board_y0 <= _bz_y0 and _bz_y0 + _bz_l <= _board_y1,
      f"buzzer {_bz_y0:.1f}..{_bz_y0 + _bz_l:.1f} dalam papan {_board_y0:.1f}..{_board_y1:.1f}")
check("ESP32 di dalam papan", _board_x0 <= _esp_x0 and _esp_x1 <= _board_x1,
      f"ESP32 {_esp_x0:.1f}..{_esp_x1:.1f} dalam papan {_board_x0:.1f}..{_board_x1:.1f}")
check("buzzer tidak menabrak header ESP32", _bz_x0 >= _esp_hdr_x1,
      f"tepi buzzer {_bz_x0:.2f} >= header {_esp_hdr_x1:.2f} "
      f"(celah {_bz_x0 - _esp_hdr_x1:.2f} mm)")
# The screw post at x 29 has r 1.4 mm, so its inner edge is 27.6.
check("buzzer tidak menabrak pilar sekrup", _bz_x0 + _bz_w <= 29.0 - 1.4,
      f"tepi buzzer {_bz_x0 + _bz_w:.1f} vs pilar {29.0 - 1.4:.1f}")
# Grille is 3x3 at +/-2.6 mm with 1.0 mm holes: it must sit inside the 12 mm can.
check("kisi suara di dalam can", 2.6 + 1.0 <= c("buzzer_can_d") / 2,
      f"kisi {2.6 + 1.0:.1f} <= radius can {c('buzzer_can_d') / 2:.1f}")
check("can sejajar pusat kisi", abs(_bz_x - (_bz_x0 + _bz_w / 2)) < 1e-9 and _bz_y > _bz_y0,
      f"can ({_bz_x:.2f}, {_bz_y:.1f}) dari PCB x0 {_bz_x0:.1f} lebar {_bz_w:.1f}")
# Can top must stay under the lid, or the printed cover presses on the module.
_can_top = c("buzzer_pcb_z") + ESP32_PCB_TH + c("buzzer_can_h")
_lid_under = total_h - lid_th
check("can buzzer di bawah tutup", _can_top < _lid_under,
      f"puncak can {_can_top:.1f} < tutup {_lid_under:.1f}")

# The 4-pin row mod, soldered, only works if every pin lands on a board hole.
# Column grid x = -21.59 + 2.54k (18 columns); row grid y = 63.79 + 2.54k (24 rows).
GRID_X0, GRID_Y0, PITCH = -21.59, 63.79, 2.54
def on_grid(v, origin):
    return abs((v - origin) / PITCH - round((v - origin) / PITCH)) < 1e-6

_esp_pin_x = c("esp_pcb_x") - 11.43, c("esp_pcb_x") + 11.43
check("pin ESP32 di kolom lubang", all(on_grid(x, GRID_X0) for x in _esp_pin_x),
      f"x {_esp_pin_x[0]:.2f} / {_esp_pin_x[1]:.2f} vs grid {GRID_X0} + n*{PITCH}")
_esp_pin_y0 = c("esp_pcb_y") - 17.78
check("pin ESP32 di baris lubang", on_grid(_esp_pin_y0, GRID_Y0),
      f"baris pertama {_esp_pin_y0:.2f} vs grid {GRID_Y0} + n*{PITCH}")
check("pin buzzer di grid", on_grid(_bz_x, GRID_X0) and on_grid(c("buzzer_pin_y"), GRID_Y0),
      f"({_bz_x:.2f}, {c('buzzer_pin_y'):.2f})")

# Every module pin exits horizontally (photo evidence), so each one lands on a jumper
# header soldered to the board. All four headers must sit on the hole grid, or the
# jumper cannot be seated. A 3-pin header has its centre on a hole; a 4-pin header
# spans an odd number of pitches, so its centre falls halfway between two holes.
def pins_on_grid(cx, cy, n_pins):
    half = (n_pins - 1) / 2 * PITCH
    return (on_grid(cx - half, GRID_X0) and on_grid(cy, GRID_Y0)
            and on_grid(cx + half, GRID_X0))

for _name, _x, _y, _n in (("buzzer", "buzzer_hdr_x", "buzzer_hdr_y", 3),
                          ("DHT11", "dht_hdr_x", "dht_hdr_y", 3),
                          ("HX711", "hx_land_x", "hx_land_y", 4)):
    check(f"header {_name} di grid", pins_on_grid(c(_x), c(_y), _n),
          f"pusat ({c(_x):.2f}, {c(_y):.2f}), {_n} pin")

# The motor header runs along y, not x, so its pins span rows instead of columns.
check("header motor sejajar baris",
      on_grid(c("mtr_hdr_x"), GRID_X0) and on_grid(c("mtr_hdr_y") - PITCH, GRID_Y0)
      and on_grid(c("mtr_hdr_y") + PITCH, GRID_Y0),
      f"x {c('mtr_hdr_x'):.2f}, y {c('mtr_hdr_y') - PITCH:.2f}..{c('mtr_hdr_y') + PITCH:.2f}")
# Motor header body (2.54 wide, 7.62 long) must clear the buzzer PCB and its can.
check("header motor di luar badan buzzer",
      c("mtr_hdr_y") - PITCH - 1.27 >= c("buzzer_pcb_y0") + c("buzzer_pcb_l"),
      f"header y mulai {c('mtr_hdr_y') - PITCH - 1.27:.2f} vs buzzer {c('buzzer_pcb_y0') + c('buzzer_pcb_l'):.2f}")
check("header motor di dalam papan (x)",
      _board_x0 <= c("mtr_hdr_x") - 1.27 and c("mtr_hdr_x") + 1.27 <= _board_x1,
      f"x {c('mtr_hdr_x') - 1.27:.2f}..{c('mtr_hdr_x') + 1.27:.2f}")

# Modules sit flat on tape, so their PCB underside has to clear the board surface.
_board_top = floor_th + 1.2 + 1.6
check("buzzer datar di atas papan", c("buzzer_pcb_z") >= _board_top,
      f"PCB bawah {c('buzzer_pcb_z'):.1f} >= papan {_board_top:.1f}")

# DHT11 is rotated 180 mm2: 14 mm across x, 32 mm along y, pins leaving toward the septum.
check("DHT11 diputar sejajar x", c("dht_front_w") < c("dht_front_l"),
      f"{c('dht_front_w')} x {c('dht_front_l')} mm")
_dht_far = math.hypot(abs(c("dht_front_x")) + c("dht_front_w") / 2,
                      c("dht_front_y") + c("dht_front_l") / 2)
check("DHT11 di dalam akrilik", _dht_far < ACRYLIC_DIA / 2,
      f"sudut terjauh r {_dht_far:.1f} < {ACRYLIC_DIA / 2:.1f}")

# Vibration motor hangs under the lid; its coin motor must clear the ESP32 RF shield.
_rf_top = floor_th + 1.2 + ESP32_PCB_TH + FEMALE_HDR_H + ESP32_PCB_TH + RF_SHIELD_H
_mtr_under = c("mtr_z") - c("mtr_can_h")
check("motor menempel di bawah tutup", abs(c("mtr_z") + c("mtr_th") - _lid_under) < 1e-6,
      f"atas PCB {c('mtr_z') + c('mtr_th'):.1f} = tutup {_lid_under:.1f}")
check("motor di bawah tutup", _mtr_under > _rf_top,
      f"bawah motor {_mtr_under:.1f} > shield RF {_rf_top:.1f} (celah {_mtr_under - _rf_top:.1f} mm)")
check("motor di dalam tutup (x/y)",
      abs(c("mtr_x")) + 11.5 <= c("lid_w") / 2 and
      c("mtr_y") + 10.5 <= c("rear_center_y") + c("lid_l") / 2,
      f"motor x {c('mtr_x') - 11.5:.1f}..{c('mtr_x') + 11.5:.1f}, y {c('mtr_y') - 10.5:.1f}..{c('mtr_y') + 10.5:.1f}")

# Load cell 80 mm must sit inside the front well, corners included.
_bar_corner = math.hypot(c("bar_w") / 2, c("bar_l") / 2)
check("batang load cell di wadah depan", _bar_corner < coaster_dia / 2,
      f"sudut r={_bar_corner:.1f} < rongga {coaster_dia / 2:.1f}")
check("batang tidak menembus septum", c("bar_l") / 2 < rear_front_y,
      f"ujung depan {c('bar_l') / 2:.1f} < septum {rear_front_y:.1f}")


# Acrylic disc needs real radial clearance: laser cut and FDM both drift.
radial_gap = (coaster_dia - ACRYLIC_DIA) / 2
check("celah radial >= 2.5mm", radial_gap >= 2.5, f"celah={radial_gap:.1f} mm per sisi")

check("pcb_w < cavity_w", pcb_w < cavity_w, f"{pcb_w} < {cavity_w}")
check("pcb_l < cavity_l", pcb_l < cavity_l, f"{pcb_l} < {cavity_l}")
check("perfboard dalam rongga", rear_front_y + 2 + pcb_l <= rear_front_y + cavity_l + 1e-9,
      f"ujung={rear_front_y + 2 + pcb_l} vs {rear_front_y + cavity_l}")
check("floor_th >= 1.2", floor_th >= 1.2, f"floor_th={floor_th}")

# Sambungan seam y=56: kerah 3.5 mm milik part depan membungkus hidung rear,
# dikunci dua baut M3x8 horizontal. Angka di bawah menjaga margin cetak dan ulir.
joint_band = c("joint_band"); joint_clear = c("joint_clear"); joint_inset = c("joint_inset")
joint_wall = c("joint_wall"); joint_y = c("joint_y"); joint_d = c("joint_d")
joint_pilot = c("joint_pilot"); joint_end = c("joint_pilot_end")
check("baut seam di dalam kerah",
      joint_y - joint_d / 2 >= rear_front_y + 0.5 and joint_y + joint_d / 2 <= rear_front_y + joint_band - 0.5,
      f"lubang {joint_y - joint_d / 2:.1f}..{joint_y + joint_d / 2:.1f} dalam band {rear_front_y:.0f}..{rear_front_y + joint_band:.0f}")
check("clearance seam 0.2..0.4", 0.2 <= joint_clear <= 0.4, f"clearance={joint_clear} mm")
check("pilot seam buta ke rongga", joint_end - cavity_w / 2 >= 5.0,
      f"web={joint_end - cavity_w / 2:.1f} mm (rongga x={cavity_w / 2:.0f})")
# Cek web di atas tidak menjamin lubang pilot berada di dalam material: di y=joint_y
# batas hull adalah garis singgung cakram depan ke cakram sudut BELAKANG, sedangkan
# cakram sudut depan berada di dalam hull dan tidak menentukan batas.
check("pilot seam masuk ke material hidung", hull_x_at(joint_y) - joint_inset > joint_end,
      f"hidung x<={hull_x_at(joint_y) - joint_inset:.2f} > ujung pilot {joint_end:.1f}")
# Lubang pilar tutup di x=29 (empat lubang M3) harus lepas dari pilot seam.
check("pilot seam lepas pilar tutup", joint_end - 29.0 >= (joint_pilot + 2.8) / 2,
      f"celah={joint_end - 29.0 - (joint_pilot + 2.8) / 2:.2f} mm")
check("ulir M3x8 cukup", 8.0 - (joint_wall + joint_clear) >= 3.0,
      f"engagement~{8.0 - (joint_wall + joint_clear):.1f} mm")
check("kerah tidak menabrak tutup", c("lid_w") / 2 + 2.0 <= rear_half_span + rear_corner_r - joint_inset,
      f"tutup {c('lid_w') / 2:.1f} vs kerah dalam {rear_half_span + rear_corner_r - joint_inset:.1f}")
# A1 Mini 180x180, sisakan 2.5 mm tiap sisi untuk brim/skirt.
check("part depan muat bed (y)", coaster_dia / 2 + wall_th + rear_front_y + joint_band <= 175.0,
      f"panjang {coaster_dia / 2 + wall_th + rear_front_y + joint_band:.1f} mm")
check("part depan muat bed (x)", coaster_dia + 2 * wall_th <= 175.0,
      f"lebar {coaster_dia + 2 * wall_th:.1f} mm")
check("part belakang muat bed (y)", c("rear_back_y") + rear_corner_r - rear_front_y <= 175.0,
      f"panjang {c('rear_back_y') + rear_corner_r - rear_front_y:.0f} mm")

bad = [n for n, p, _ in ok if not p]
for n, p, d in ok:
    print(f"{'PASS' if p else 'FAIL'}  {n:34s} {d}")
print(f"\n{len(ok) - len(bad)}/{len(ok)} lulus")
if bad:
    print("GAGAL:", ", ".join(bad))

sys.exit(1 if bad else 0)
