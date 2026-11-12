extends RefCounted
## Model (input source helper) — the key combinations shared by both keyboard sources (v0.8.3).
## The keyboard stands in for the sensor, so it has to be able to play every situation the evaluation
## and the achievements look at, not only a good round. Keys that can be held together:
##   speed      Z = slow (×0.35)            X or Ctrl = fast (×3)
##   strength   hold 1 – 5: 1 too light · 2 low · 3 right · 4 high · 5 past the target (not yet too hard)
##   Shift      too hard (pop / overload)
##   G / H      small / large hand tremor
##   S          off-axis moment            P = pulling too hard
##   F          automatic standard movement; combines with all of the above
##              (F + X ramps too fast, F + 1 holds too light, F + G trembles …)
##   R          (carrot game, with F) keep pushing the same side
## `active` lists what is in effect this frame, for the view to show (no words here).

const SLOW := 0.35
const FAST := 3.0


## The keys held now.
static func state() -> Dictionary:
	var level := 0
	var level_keys := [[KEY_1, KEY_KP_1], [KEY_2, KEY_KP_2], [KEY_3, KEY_KP_3], [KEY_4, KEY_KP_4], [KEY_5, KEY_KP_5]]
	for i in level_keys.size():
		for k in level_keys[i]:
			if Input.is_key_pressed(k):
				level = i + 1
	var fast := Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_CTRL)
	var slow := Input.is_key_pressed(KEY_Z)
	return {
		"right": Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_E),
		"left": Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q),
		"up": Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W),
		"down": Input.is_key_pressed(KEY_DOWN),
		"speed": FAST if fast and not slow else (SLOW if slow and not fast else 1.0),
		"fast": fast and not slow,
		"slow": slow and not fast,
		"level": level,
		"over": Input.is_key_pressed(KEY_SHIFT),
		"wobble": 2 if Input.is_key_pressed(KEY_H) else (1 if Input.is_key_pressed(KEY_G) else 0),
		"offaxis": Input.is_key_pressed(KEY_S),
		"pull": Input.is_key_pressed(KEY_P),
		"auto": Input.is_key_pressed(KEY_F),
		"same": Input.is_key_pressed(KEY_R),
	}


## Codes of what is in effect, in a fixed order: auto, same, fast, slow, level1–5, over, wobble,
## wobble_big, offaxis, pull.
static func active(st: Dictionary) -> PackedStringArray:
	var a := PackedStringArray()
	if st["auto"]:
		a.append("auto")
		if st["same"]:
			a.append("same")
	if st["fast"]:
		a.append("fast")
	if st["slow"]:
		a.append("slow")
	if int(st["level"]) > 0:
		a.append("level%d" % int(st["level"]))
	if st["over"]:
		a.append("over")
	if int(st["wobble"]) == 1:
		a.append("wobble")
	elif int(st["wobble"]) == 2:
		a.append("wobble_big")
	if st["offaxis"]:
		a.append("offaxis")
	if st["pull"]:
		a.append("pull")
	return a


## Hand tremor: two sines plus a little noise, `amp` N·m at the largest.
static func tremor(t: float, amp: float) -> float:
	if amp <= 0.0:
		return 0.0
	return amp * (0.65 * sin(t * TAU * 5.3) + 0.35 * sin(t * TAU * 8.9 + 1.3)) + randf_range(-0.15, 0.15) * amp
