# MP5 app v0.5.4 (Godot 4.7)

v0.5.4 restructures the whole app into **Model–View–Presenter** layers. Features, screens and rules are the
same as v0.5.3. Architecture notes: `design/架构说明_v0.5.4.md`.

## Run
- Whole app: open `app_v0.5.4/main.tscn` and press F6.
- Carrot game only: open `app_v0.5.4/carrot_game.tscn` and press F6 (Trainee Dentist, Chinese).
- **Model tests:** open `app_v0.5.4/tests/run_tests.tscn` and press F6 — 11 checks of the game rules,
  entry test and scoring, shown on screen and in the Output panel. They do not touch the database or files.

## Layout
```
scripts/
  models/      rules, data, files — no UI          rocking_model, entry_test_model, evaluation,
                                                   achievement_db, achievement_defs, round_log,
                                                   report_exporter, settings_model,
                                                   keyboard_moment_source, sim_sensor
  views/       draw and report user actions        app_view + connect/entry_test/select/achievements/
                                                   history views, carrot_view, report_view, toasts,
                                                   gauges, ui_kit, palette, strings
  presenters/  connect models and views            app_presenter (main.tscn), carrot_presenter
                                                   (carrot_game.tscn), report, achievements, history
tests/         run_tests.tscn
```
Rules: views never load models or presenters and never touch files; models never load views or
presenters and never create UI nodes.

Everything else (achievements, evaluation report, history, data locations) is as described for v0.5.0–v0.5.3
in `版本记录.md`. All thresholds are prototype placeholders, not validated values.
