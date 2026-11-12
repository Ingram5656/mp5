# MP5 app v0.7.2 (Godot 4.7)

**v0.7.2** fixes three warnings shown by Godot when v0.7.1 starts (2026-11-09, user screenshot):
- `garden.gd`: two local variables called `tr` hid `Object.tr()` → renamed `layer` and `ring_rect`.
- `garden.gd` and `select_view.gd`: two `x if c else null` expressions (a texture or null) → plain if/else.

Nothing else changed; everything is as in v0.7.1 (including the 20 Level B achievements and their icons).

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
