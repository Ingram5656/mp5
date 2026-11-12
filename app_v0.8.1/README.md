# MP5 app v0.8.1 (Godot 4.7)

**v0.8.1** fixes v0.8.0's page animation: after the entry test the selection page came up far taller than
the window (the board ran off the bottom and everything under the level buttons disappeared). The page
slide now moves the page's top and bottom offsets together instead of setting `position`, so the page always
stays the size of the page area. The report's slide-in was changed the same way. Nothing else changed.

Run: `app_v0.8.1/main.tscn`.

---

**v0.8.0** — interface sounds, screen transitions, bunny's notes, soft cover picture.
1. **Sounds** (`scripts/views/sfx_player.gd`, files in `assets/sfx/`): every button clicks (`ui_click.wav`),
   every screen change swooshes (`ui_swoosh.wav`). No game sounds yet. Both sounds were synthesised as
   placeholders — drop in a file with the same name to replace one. Sounds play when the whole app is run
   from `main.tscn` (the games run on their own have none).
2. **Transitions:**
   - pages of the app (connection, entry test, selection, achievements, history): the old page sinks and
     fades, the new one rises into place with a small bounce (`app_view.gd`, `show_page`);
   - app ↔ game: a cocoa-ink circle closes on the middle of the screen, the game is swapped in, the circle
     opens again (`scripts/views/screen_transition.gd`);
   - evaluation report: rises in from below, drops away when closed (`report_presenter.gd`).
3. **Bunny's notes:** the report's "coach's notes" are now "兔子点评 / Bunny's notes", with the level's bunny
   by the title (cheerful when there is nothing to fix, concentrating when there is).
4. **Cover picture** on the selection page: no hard ink frame — the edges fade softly into the wood, a warm
   soft shadow sits underneath, and switching Level A / B cross-fades the pictures.
Tests: 19 (unchanged; this version only changes views).

Run: `app_v0.8.1/main.tscn`, `balloon_game.tscn`, `carrot_game.tscn`, `tests/run_tests.tscn`.

---

**v0.7.2.1** (version number chosen by the user) adds an "at a glance" part to the top of the evaluation
report, for both levels. The curve is kept below it.
1. Cards: one per balloon (Level B) or per full rock (Level A) — result, ramp speed (slow / right / fast,
   Level B), hold steadiness (stars).
2. Force band: the whole round as one coloured strip (relaxed / building up / on target / too fast /
   above the safe line) with the share of time in each.
3. Coach's notes (v0.8.0: bunny's notes): up to two things to improve and one thing done well, in plain sentences.
When the report opens, the cards and notes pop in one after another and the band fills from left to right.
Logic: `scripts/models/report_insights.gd`; drawing: `scripts/views/report_view.gd`. Tests: 19.

---


v0.6.0 adds **Rocking Challenge Level B, "Bunny's Balloons" (兔子的气球)** — a one-direction moment-control
game that trains building force slowly and steadily. Everything else is as in v0.5.4 (MVP layers, see
`design/架构说明_v0.6.0.md`).

## Run
- Whole app: open `app_v0.6.1/main.tscn` and press F6. On the game selection page, "Rocking Challenge"
  now has a **Level A / Level B** choice.
- Balloon game only: open `app_v0.6.1/balloon_game.tscn` and press F6 (Trainee Dentist, Chinese).
- Carrot game only: open `app_v0.6.1/carrot_game.tscn` and press F6.
- **Model tests:** open `app_v0.6.1/tests/run_tests.tscn` and press F6 — 17 checks (11 from v0.5.4 plus
  6 for the balloon game).

## The balloon game
- Push (positive target-axis moment): the pump handle goes down and the balloon grows with the moment.
- Follow the dashed ring as it grows (a ramp, then a plateau at the balloon's target size), then hold
  inside the target for 1.5 s: the balloon is tied to the big carrot. Let go back to the start for the next one.
- Ahead of the ring for 0.25 s = **leak** (start that balloon again, no mistake counted).
  Above 0.40 N·m = **pop** (one mistake; let go back to the start before carrying on).
- Five balloons tied → the carrot floats away with the bunny.

| Difficulty | Hints | Timer | Pops allowed | Targets (N·m) | Ramp (s) | Hold band |
|---|---|---|---|---|---|---|
| Intern | dashed ring, text, live curve along the bottom | no | 5 | 0.15–0.25 | 4.0 ± 0.5 | ±0.05 |
| Trainee Dentist | dashed ring | 90 s | 3 | 0.15–0.30 | 3.0 ± 0.5 | ±0.04 |
| Master Dentist | target marks only | 90 s | 0 | 0.20–0.32 | 2.5 ± 0.5 | ±0.03 |

Keyboard (no sensor): → / D / E / ↑ add force slowly (0.10 N·m/s), ← / A / Q / ↓ let go; the value stays
where it is when no key is held. Shift = too hard, S = off-axis, Esc = back, F3 = debug numbers.

Balloon rounds are saved in the History page with their own evaluation report
(`design/评估方法_v0.6.0.md`); CSV logs are `user://carrot_logs/rocking_B_*.csv`. The 20 achievements
still belong to Level A only.

## New and changed files
```
balloon_game.tscn
scripts/models/balloon_model.gd          rules of Level B
scripts/models/evaluation_balloon.gd     scoring + CSV reader for Level B
scripts/models/keyboard_ramp_source.gd   keyboard input that holds its value
scripts/views/balloon_view.gd            the balloon scene
scripts/presenters/balloon_presenter.gd
changed: round_log (file prefix/columns), achievement_db (balloon rounds → history only),
         achievement_defs (GAME_BALLOON), report_view / report_presenter / report_exporter (both games),
         history view/presenter (game column, per-game report), select_view (Level A/B), app_presenter,
         strings, tests/run_tests.gd
```
Art: `assets/balloon_game/` (30 PNGs + `cover_balloon.png` cropped from the preview). All thresholds are
prototype placeholders, not validated values.
