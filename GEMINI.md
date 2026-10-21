# Aturan Proyek: Smart Hydration Coaster

1. **Skill Aktif Otomatis (Tanpa Perlu Slash Command):**
   - Selalu terapkan `ponytail` (default: `full`), `antislop`, dan `antislop-code` pada setiap tugas koding, komentar, dokumentasi, maupun UI.
   - Gunakan `ponytail-audit` ketika diminta mencari kode berlebih atau melakukan audit keringkasan repositori.

2. **Konteks & Aturan Tiga Port 1:1:**
   - Baca `HANDOFF_AGENT.md` dan `PRD_Smart_Hydration_Coaster.md` sebagai acuan utama.
   - Logika FSM hidup di tiga tempat dan wajib selalu identik 1:1:
     1. `SmartHydrationCoaster/fsm.h`
     2. `test_simulation.py`
     3. `web/index.html` (`class CoasterFSM`)
   - Setiap perubahan logika FSM wajib disalin ke ketiga port dan diverifikasi dengan `python test_simulation.py` serta harness C++ `tools/uji_fsm/uji_fsm.cpp`.

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, read `antislop.md` (core) and then the skill for the task:
- UI / visual: `skills/antislop-ui/SKILL.md`
- Copy & text: `skills/antislop-copywriting/SKILL.md`
- People: `skills/antislop-human/SKILL.md`
- Mobile / responsive: `skills/antislop-layoutmobile/SKILL.md`
- Code comments: `skills/antislop-code/SKILL.md`
Before starting, ask the user when antislop applies: during the work, or after it is done.
<!-- antislop:end -->
