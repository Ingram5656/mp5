# MP5 app v0.2.1 (Godot 4.7)

Flow: sensor connection -> "How it works" -> entry test (three locks) -> "Connection successful" -> game selection.

New in v0.2.1: EN / 中文 language switch at the top right. It works on every page, including open popups,
and the choice is remembered between runs (user://mp5_settings.cfg).

## Run
Open `app_v0.2.1/main.tscn` in Godot and press F6.

## Text
All on-screen text is in `scripts/strings.gd` ("en" and "zh"). Chinese uses a system CJK font
(Microsoft YaHei on Windows).

## Simulated input (keyboard)
Left / Right = direction, Up / Down = force, Q / E = moment.

Target ranges are placeholders for interface testing only, not validated or clinical values.
See `版本记录.md` in the project root for the change history.
