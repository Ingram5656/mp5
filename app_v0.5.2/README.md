# MP5 app v0.5.2 (Godot 4.7)

v0.5.2 — **evaluation and feedback** for the carrot game (Rocking Challenge, Level A).
Everything else is the same as v0.5.1, plus three flavour-text edits the user made to the achievements.

## Run
- Whole app: open `app_v0.5.2/main.tscn` and press F6.
- Carrot game only: open `app_v0.5.2/carrot_game.tscn` and press F6.

## What is new
- **Score for every round** (`scripts/evaluation.gd`): six dimensions with the agreed weights —
  safety 25, accuracy 25, stability 20, rhythm & symmetry 15, efficiency 10, direction purity 5.
  Direction purity needs a real sensor; in keyboard mode it is left out and the others are re-weighted.
  Cleared rounds get S (≥ 90), A, B, C (≥ 60) or D; a round that was not cleared is always **F**,
  but its report is still produced in full. All difficulties use the same scale.
- **Standard curve**: per half-rock, rise : hold : fall = 0.4 : 0.6 : 0.4 with the peak at the green-zone
  centre, stretched to the player's own half-rock so timing and shape are judged separately.
- **Result panel**: shows grade and score, and a third button **Report**.
- **Report** (`scripts/report_view.gd`): the round's moment curve against the standard curve with the green
  zone, limit lines, "too hard" and "hold done" marks; off-axis moment and pull force charts when a sensor
  is used; grade, total and the six dimension scores with the numbers behind them.
  **Save to folder** writes `…report_<time>.png`, `…_scores.csv` and `…_samples.csv` (samples plus the standard curve)
  into a folder you choose.
- **History** (button under Achievements on the game selection page): every round, newest first, with date,
  difficulty, result, grade and score, and **View report**. Reports are rebuilt from the round's CSV log, so
  rounds played in v0.5.0 / v0.5.1 can be opened too; their score is saved the first time.
- CSV logs now put several events of one frame together separated by ";" and record the off-axis and pull limits.

Formulas, thresholds and a check on simulated rounds: `design/评估方法_v0.5.2.md`.
All thresholds are placeholders, not validated values. Change history: `版本记录.md` in the project root.
