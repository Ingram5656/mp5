# MP5 Dental Extraction Trainer — Changelog (English)

Project: `E:\mp-5` (Godot 4.7). Newest version first.
English translation of the Chinese changelog (created 2026-11-12 for the week-6 report; the original is unchanged).
Checksums, base versions and validation status are recorded in the full version record.

**Current version: v0.8.4.** Run `app_v0.8.4/main.tscn` (F6). Comparison build: v0.8.2.1 (later versions do not build on it).

---

## v0.8.4 — 2026-11-12 · Balloon sounds; Quit training
- Balloon game sounds: an inflating sound while the force is rising (pitch rises as the balloon grows, fades
  out when the force stops rising); leak, pop, tie and the carrot floating away. Sources and licences:
  `assets/sfx/音效对照.md` (the leak sound is CC BY 4.0 and needs a credit).
- "Quit training" button next to "Sensor check" on the selection page; a dialog asks first (Cancel is the
  default, Esc = Cancel), then the program saves and closes.
- Synced to GitHub; a macOS build is produced automatically.

## v0.8.3 — 2026-11-10 · Keyboard combinations (part 1)
- Without a sensor, the keyboard can now simulate every force pattern; keys can be held together:
  - Speed: Z = slow ramp, X / Ctrl = fast ramp
  - Strength: hold 1–5 = too light, low, on target, high, past the target
  - Other: Shift = excessive force, G / H = tremor, S = off-axis, P = pulling too hard
  - Auto: hold F for the standard movement; combines with the keys above (F + X, F + 1, F + G ...)
- F1 shows all keys; the active combination is shown at the bottom of the screen. Rule tests: 20.
- Revision (same day): in-game sounds — rocking, cracking, snapping, pulling out; level cleared / failed.

## v0.8.2.1 — 2026-11-10 · Comparison build: target plot, ramp-speed gauge, coach's notes
- For comparison only. The report overview shows a target plot, a ramp-speed gauge (Level B) and coach's notes.

## v0.8.2 — 2026-11-09 · Cover colour fix; final UI sounds
- Cover images no longer look over-saturated (shader applied the texture colour twice).
- Sounds accept .ogg / .wav / .mp3. Kenney Interface Sounds in use, plus an overload warning sound.
- Larger result panels; report opens in sequence (overview → six scores → grade stamp).

## v0.8.1 — 2026-11-09 · Selection page layout fix
- Page transitions no longer change the page size (selection board overflowed the window in v0.8.0).

## v0.8.0 — 2026-11-09 · Sounds, transitions, bunny's notes
- "Coach's notes" renamed "Bunny's notes", with a happy or focused bunny.
- Button click and screen-change sounds; page and game transitions; soft-edged cover images.

## v0.7.2.1 — 2026-11-09 · Report overview
- Report adds per-trial score cards, a force band (share of time in each state) and coach's notes.
  The original curve is kept under "Detailed curve".

## v0.7.2 — 2026-11-09 · Startup warnings fixed
- Three GDScript warnings fixed; no change to features or visuals.

## Assets — 2026-11-09 · Level B achievement icons
- 20 hand-drawn icons added for Bunny's Balloons achievements.

## v0.7.1 — 2026-11-09 · 20 achievements for Level B
- Six groups (Intern, Trainee Dentist, Master Dentist, Technique, Cumulative, Just for fun).
- Levels A and B are tracked separately; old saves are upgraded. Achievements page lists 40. Rule tests: 18.

## v0.7.0 — 2026-11-08 · New visual style "Garden Signpost"
- Whole app redesigned to Design v2.0: garden background, content on wooden signs, cocoa outlines.
- Pill buttons with a solid lip; ZCOOL KuaiLe title font; 10 hand-drawn UI assets.

## Design v2.0 — 2026-11-08 · "Garden Signpost"
- New UI specification derived from the games' art style.

## v0.6.1 — 2026-11-08 · Bunny paw position fix (Level B)

## v0.6.0 — 2026-11-08 · Rocking Challenge Level B "Bunny's Balloons"
- Gradual force ramp: inflate each balloon along the reference ring, hold 1.5 s, tie it to the carrot.
- Too fast = leak (no mistake); over the limit = pop (mistake). Five balloons clear the level.
- Level B scoring replaces "rhythm and symmetry" with "ramp control".

## v0.5.4 — 2026-11-08 · Model–View–Presenter refactor
- Whole app split into models, views and presenters; rule tests added (`tests/run_tests.tscn`).

## v0.5.3 — 2026-11-07 · Language-switch error fixed

## v0.5.2 — 2026-11-07 · Evaluation and feedback
- Six weighted scores: safety 25%, accuracy 25%, stability 20%, rhythm 15%, efficiency 10%, direction purity 5%.
- Grades S–D for cleared rounds, F for failed rounds. Report can be saved; History page added.

## v0.5.1 — 2026-11-07 · Hand-drawn achievement icons (Level A)

## v0.5.0 — 2026-11-07 · Achievement system
- 20 achievements for Pull the Carrot; pop-up notice; Achievements page; local database.

## v0.4.1 — 2026-11-06 · Selection page shows Pull the Carrot

## v0.4.0 — 2026-11-06 · Rocking Challenge Level A "Pull the Carrot"
- Alternating moment: push into the green zone, hold 0.5 s, return to centre; 6 full rocks to clear.
- Over the limit = mistake (carrot cracks); too many mistakes snaps the carrot. Per-frame CSV log.

## v0.3.1 — 2026-11-05 · Minor fixes
## v0.3.0 — 2026-11-05 · UI redesign to Design v1 ("Precision Instrument")
## v0.2.1 — 2026-11-05 · English / Chinese switch
## v0.2.0 — 2026-11-05 · Game selection page
## v0.1.0 — 2026-11-05 · First entry test (three locks, keyboard simulation)
