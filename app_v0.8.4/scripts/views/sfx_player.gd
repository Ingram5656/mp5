extends Node
## View — interface sounds (v0.8.0; v0.8.2: the user's Kenney sounds and the "too much force" sound):
##   click    — every button in the app, the games and the report (toggles too), found automatically
##              (assets/sfx/ui_click.ogg, from Kenney Interface Sounds select_002)
##   swoosh   — changing screens (pages, opening a game, coming back, opening / closing a report)
##              (ui_swoosh.ogg, from switch_006)
##   overload — too much force: the carrot game's overload mistake, a popped balloon
##              (ui_overload.ogg, from error_005)
##   back     — buttons that go back (games' "Back to games", Back on Achievements and History), instead
##              of the click (ui_back.ogg, from glass_006). A view marks such a button with
##              set_meta("sfx", "back"); the mark is read when the button is pressed, so it may be set
##              before or after the button enters the tree.
## Sounds live in assets/sfx/ — replace a file with one of the same name to change the sound.
## v0.8.2: each sound may be .ogg, .wav or .mp3 (looked for in that order), so a downloaded .ogg can be
## dropped in as ui_click.ogg / ui_swoosh.ogg without converting; it wins over the placeholder .wav.
## Any node can ask for the swoosh with get_tree().call_group("mp5_sfx", "play_swoosh").
## v0.8.3 (revised): game sounds, played by name with get_tree().call_group("mp5_sfx", "play_game", name):
##   carrot_rock      — a push starts (one of carrot_rock_01 … carrot_rock_NN at random)
##   carrot_pull_out  — the carrot comes out       carrot_crack — a crack (overload)
##   carrot_snap      — the carrot snaps           game_win / game_fail — the result board of either game
## v0.8.4: balloon game — balloon_leak, balloon_pop, balloon_tie, balloon_flyaway (one-shot) and
##   balloon_inflate, a loop that plays while the force is rising: set_loop(name, on, pitch).
## A name with numbered files (name_01, name_02 …) plays one of them at random, never the same twice in a
## row. assets/sfx/音效对照.md lists which original file each one was made from.

const CLICK_PATH := "res://assets/sfx/ui_click"     # + .ogg / .wav / .mp3 (v0.8.2)
const SWOOSH_PATH := "res://assets/sfx/ui_swoosh"
const OVERLOAD_PATH := "res://assets/sfx/ui_overload"
const BACK_PATH := "res://assets/sfx/ui_back"
const EXTENSIONS := [".ogg", ".wav", ".mp3"]
const CLICK_DB := -6.0
const SWOOSH_DB := -9.0
const OVERLOAD_DB := -4.0
const BACK_DB := -6.0
const GROUP := "mp5_sfx"
const SFX_DIR := "res://assets/sfx/"
const GAME_DB := {"carrot_rock": -8.0, "carrot_pull_out": -3.0, "carrot_crack": -4.0, "carrot_snap": -2.0,
	"game_win": -5.0, "game_fail": -5.0,   # v0.8.3 (revised)
	"balloon_inflate": -8.0, "balloon_leak": -6.0, "balloon_pop": -2.0, "balloon_tie": -5.0,
	"balloon_flyaway": -4.0}   # v0.8.4
const LOOP_FADE := 12.0   # v0.8.4: dB per 0.1 s when a loop fades in / out
const MAX_VARIANTS := 40

var _click: AudioStreamPlayer
var _swoosh: AudioStreamPlayer
var _overload: AudioStreamPlayer
var _back: AudioStreamPlayer
var _last_swoosh_ms := -1000
var _game_streams := {}    # name → Array of AudioStream (v0.8.3)
var _game_players := {}    # name → AudioStreamPlayer
var _game_last := {}       # name → index played last time
var _loops := {}           # v0.8.4: name → {"player", "on", "pitch"}


func _ready() -> void:
	add_to_group(GROUP)
	_click = _player(CLICK_PATH, CLICK_DB, 4)
	_swoosh = _player(SWOOSH_PATH, SWOOSH_DB, 1)
	_overload = _player(OVERLOAD_PATH, OVERLOAD_DB, 2)
	_back = _player(BACK_PATH, BACK_DB, 2)
	# every button that is (or will be) in the tree clicks
	get_tree().node_added.connect(_on_node_added)
	_hook_tree(get_tree().root)


func _player(path: String, db: float, voices: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	for ext in EXTENSIONS:
		if ResourceLoader.exists(path + ext):
			p.stream = load(path + ext)
			break
	p.volume_db = db
	p.max_polyphony = voices
	add_child(p)
	return p


func _hook_tree(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_hook_tree(c)


func _on_node_added(n: Node) -> void:
	var b := n as BaseButton
	if b != null and not b.has_meta("_sfx_hooked"):
		b.set_meta("_sfx_hooked", true)
		b.pressed.connect(_on_button_pressed.bind(b))


func _on_button_pressed(b: BaseButton) -> void:
	if is_instance_valid(b) and str(b.get_meta("sfx", "")) == "back" and _back.stream != null:
		_back.play()
	else:
		play_click()


func play_click() -> void:
	if _click.stream == null:
		return
	_click.pitch_scale = randf_range(0.95, 1.06)
	_click.play()


## Screen change. Two requests closer than 0.2 s play once (a page change inside a cover transition).
func play_swoosh() -> void:
	var now := Time.get_ticks_msec()
	if _swoosh.stream == null or now - _last_swoosh_ms < 200:
		return
	_last_swoosh_ms = now
	_swoosh.play()


## Too much force (v0.8.2): an overload mistake in the carrot game, a popped balloon.
func play_overload() -> void:
	if _overload.stream == null:
		return
	_overload.play()


# ------------------------------------------------------------------ game sounds (v0.8.3, revised)
func _find(path_no_ext: String) -> AudioStream:
	for ext in EXTENSIONS:
		if ResourceLoader.exists(path_no_ext + ext):
			return load(path_no_ext + ext)
	return null


## Loads a game sound the first time it is asked for: name.ext, or name_01.ext, name_02.ext … as variants.
func _game_variants(sound: String) -> Array:
	if _game_streams.has(sound):
		return _game_streams[sound]
	var list: Array = []
	var single := _find(SFX_DIR + sound)
	if single != null:
		list.append(single)
	else:
		for i in range(1, MAX_VARIANTS + 1):
			var st := _find(SFX_DIR + "%s_%02d" % [sound, i])
			if st == null:
				break
			list.append(st)
	_game_streams[sound] = list
	var p := AudioStreamPlayer.new()
	p.volume_db = float(GAME_DB.get(sound, -6.0))
	p.max_polyphony = 3
	add_child(p)
	_game_players[sound] = p
	return list


func play_game(sound: String) -> void:
	var list := _game_variants(sound)
	if list.is_empty():
		return
	var i := 0
	if list.size() > 1:
		i = randi() % list.size()
		if i == int(_game_last.get(sound, -1)):
			i = (i + 1) % list.size()
	_game_last[sound] = i
	var p: AudioStreamPlayer = _game_players[sound]
	p.stream = list[i]
	p.pitch_scale = randf_range(0.95, 1.05) if list.size() > 1 else 1.0
	p.play()


# ------------------------------------------------------------------ loops (v0.8.4)
## A sound that keeps playing while `on` (the balloon inflating while the force rises). It fades in and
## out instead of starting and stopping hard; pitch follows the caller (higher as the balloon grows).
func set_loop(sound: String, on: bool, pitch := 1.0) -> void:
	if not _loops.has(sound):
		if not on:
			return
		var found := _find(SFX_DIR + sound)
		if found == null:
			return
		var st: AudioStream = found.duplicate() as AudioStream
		var ogg := st as AudioStreamOggVorbis
		var wav := st as AudioStreamWAV
		var mp3 := st as AudioStreamMP3
		if ogg != null:
			ogg.loop = true
		elif wav != null:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		elif mp3 != null:
			mp3.loop = true
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.volume_db = -60.0
		add_child(p)
		_loops[sound] = {"player": p, "on": false, "pitch": 1.0}
	var lp: Dictionary = _loops[sound]
	lp["on"] = on
	lp["pitch"] = clampf(pitch, 0.5, 2.0)


func stop_loops() -> void:
	for k in _loops:
		_loops[k]["on"] = false


func _process(delta: float) -> void:
	for k in _loops:
		var lp: Dictionary = _loops[k]
		var p: AudioStreamPlayer = lp["player"]
		var full := float(GAME_DB.get(k, -6.0))
		if lp["on"]:
			if not p.playing:
				p.play()
			p.volume_db = minf(full, p.volume_db + LOOP_FADE * 10.0 * delta)
			p.pitch_scale = lerpf(p.pitch_scale, float(lp["pitch"]), minf(1.0, 8.0 * delta))
		elif p.playing:
			p.volume_db -= LOOP_FADE * 10.0 * delta
			if p.volume_db <= -50.0:
				p.stop()
				p.volume_db = -60.0
