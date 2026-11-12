extends Node
## Presenter — the whole app (v0.5.4; v0.6.0: Rocking Challenge Level B, the balloon game; v0.8.0: sounds and transitions). Root script of main.tscn.
## Flow (unchanged since v0.3.x): sensor connection → instructions → entry test (three locks) → success
## → game selection, plus Achievements and History pages, and the two Rocking Challenge games (carrot, balloons).
##
## MVP layout (design/架构说明_v0.6.0.md):
##   models/      rules, data and files — no UI nodes (except the simulated sensor, which reads the keyboard)
##   views/       pages and widgets — draw what they are given, report user actions with signals
##   presenters/  this file and its helpers — own the models and views, decide what happens next

const SettingsModel := preload("res://app_v0.8.2.1/scripts/models/settings_model.gd")
const SimSensor := preload("res://app_v0.8.2.1/scripts/models/sim_sensor.gd")
const EntryTestModel := preload("res://app_v0.8.2.1/scripts/models/entry_test_model.gd")
const AchievementDB := preload("res://app_v0.8.2.1/scripts/models/achievement_db.gd")
const AppView := preload("res://app_v0.8.2.1/scripts/views/app_view.gd")
const AchievementsPresenter := preload("res://app_v0.8.2.1/scripts/presenters/achievements_presenter.gd")
const HistoryPresenter := preload("res://app_v0.8.2.1/scripts/presenters/history_presenter.gd")
const CarrotPresenter := preload("res://app_v0.8.2.1/scripts/presenters/carrot_presenter.gd")
const BalloonPresenter := preload("res://app_v0.8.2.1/scripts/presenters/balloon_presenter.gd")
const SfxPlayer := preload("res://app_v0.8.2.1/scripts/views/sfx_player.gd")
const ScreenTransition := preload("res://app_v0.8.2.1/scripts/views/screen_transition.gd")

const VERSION := "v0.8.2.1"
const GAME_COUNT := 3
const DIFFICULTY_COUNT := 3

enum State { CONNECT, TEST, DONE, SELECT }
var state: State = State.CONNECT

# models
var settings: SettingsModel
var sensor: SimSensor
var entry: EntryTestModel
var db: AchievementDB

# view and helper presenters
var view: AppView
var achievements: AchievementsPresenter
var history: HistoryPresenter
var game: Node = null
var sfx: SfxPlayer                 # v0.8.0: button clicks and screen-change swoosh
var transition: ScreenTransition   # v0.8.0: cover transition between the app and a game

# what is on screen (kept so it can be re-sent when the language changes)
var page := "connect"
var conn := ["cs_not", "plain"]
var selected_game := 0
var selected_difficulty := 0
var selected_level := 0   # Rocking Challenge: 0 = Level A (carrot), 1 = Level B (balloons)
var _modal_next: Callable = Callable()


func _ready() -> void:
	# v0.8.0: added first, so it hears about every button made after it
	sfx = SfxPlayer.new()
	add_child(sfx)
	transition = ScreenTransition.new()
	add_child(transition)
	settings = SettingsModel.new()
	settings.load_settings()
	sensor = SimSensor.new()
	add_child(sensor)
	entry = EntryTestModel.new()
	db = AchievementDB.new()

	view = AppView.new()
	view.setup({
		"lang": settings.lang,
		"entry_targets": {
			"dir_target": EntryTestModel.DIR_TARGET, "dir_tol": EntryTestModel.DIR_TOL,
			"force_min": EntryTestModel.FORCE_MIN, "force_max": EntryTestModel.FORCE_MAX,
			"moment_min": EntryTestModel.MOMENT_MIN, "moment_max": EntryTestModel.MOMENT_MAX,
		},
		"game_count": GAME_COUNT,
		"difficulty_count": DIFFICULTY_COUNT,
		"ach_filter": 0,
	})
	add_child(view)
	achievements = AchievementsPresenter.new(db, view.ach_page)
	history = HistoryPresenter.new(db, view.hist_page, self)

	view.language_selected.connect(_on_language)
	view.modal_closed.connect(_on_modal_closed)
	view.page_changed.connect(sfx.play_swoosh)
	view.connect_page.connect_pressed.connect(_on_connect)
	view.connect_page.continue_pressed.connect(_start_entry_test)
	view.test_page.help_pressed.connect(_show_instructions)
	view.select_page.game_selected.connect(_on_game_selected)
	view.select_page.difficulty_selected.connect(_on_difficulty)
	view.select_page.level_selected.connect(_on_level)
	view.select_page.start_pressed.connect(_on_start)
	view.select_page.recheck_pressed.connect(_on_recheck)
	view.select_page.achievements_pressed.connect(_show_achievements)
	view.select_page.history_pressed.connect(_show_history)
	view.ach_page.back_pressed.connect(_show_select)
	view.hist_page.back_pressed.connect(_show_select)

	view.set_sensor_status("st_not_connected", "idle")
	view.connect_page.set_conn_status(conn[0], conn[1])
	view.test_page.reset()
	view.select_page.show_selection(selected_game, selected_difficulty)
	view.select_page.set_achievement_count(db.unlocked_count(), db.total_count())
	view.set_language(settings.lang)


# ------------------------------------------------------------------ language
func _on_language(new_lang: String) -> void:
	if not settings.set_lang(new_lang):
		return
	view.set_language(new_lang)
	view.connect_page.set_conn_status(conn[0], conn[1])
	if page == "achievements":
		achievements.render()
	elif page == "history":
		history.render()


# ------------------------------------------------------------------ dialog
func _show_modal(title_key: String, body_key: String, button_key: String,
		on_close: Callable = Callable(), body_args: Array = []) -> void:
	_modal_next = on_close
	view.show_modal(title_key, body_key, button_key, body_args)


func _on_modal_closed() -> void:
	var next := _modal_next
	_modal_next = Callable()
	if next.is_valid():
		next.call()


func _show_instructions() -> void:
	_show_modal("help_title", "help_body", "btn_start")


func _show_page(p: String, sub_key: String) -> void:
	page = p
	view.show_page(p, sub_key)


# ------------------------------------------------------------------ connect page
func _set_conn(key: String, tone: String) -> void:
	conn = [key, tone]
	view.connect_page.set_conn_status(key, tone)


func _on_connect(source_index: int) -> void:
	view.connect_page.set_buttons(false, false)
	if source_index == 1:
		_set_conn("cs_usb", "fault")
		view.set_sensor_status("st_unavailable", "fault")
		view.connect_page.set_buttons(true, false)
		return
	_set_conn("cs_connecting", "busy")
	view.set_sensor_status("st_connecting", "busy")
	await get_tree().create_timer(0.8).timeout
	if sensor.connect_sensor():
		_set_conn("cs_connected", "ok")
		view.set_sensor_status("st_connected", "ok")
		view.connect_page.set_buttons(true, true)
		view.connect_page.focus_continue()
	else:
		view.connect_page.set_buttons(true, false)


# ------------------------------------------------------------------ entry test
func _start_entry_test() -> void:
	entry.reset()
	view.test_page.reset()
	_show_page("test", "sub_entry")
	state = State.TEST
	_show_instructions()


func _process(delta: float) -> void:
	if state != State.TEST or not sensor.is_valid():
		return
	var sample: Dictionary = sensor.read()
	var opened := entry.step(delta, sample, view.is_modal_open())
	view.test_page.show_sample(sample, [entry.progress(0), entry.progress(1), entry.progress(2)])
	for i in opened:
		view.test_page.set_lock(i, true)
	if entry.all_unlocked():
		state = State.DONE
		await get_tree().create_timer(0.5).timeout
		_show_modal("ok_title", "ok_body", "btn_continue", _show_select)


# ------------------------------------------------------------------ game selection
func _show_select() -> void:
	state = State.SELECT
	view.select_page.set_achievement_count(db.unlocked_count(), db.total_count())
	_show_page("select", "sub_select")
	view.select_page.focus_start()


func _on_game_selected(i: int) -> void:
	selected_game = i
	view.select_page.show_selection(selected_game, selected_difficulty)


func _on_difficulty(i: int) -> void:
	selected_difficulty = i
	view.select_page.show_selection(selected_game, selected_difficulty)


func _on_level(i: int) -> void:
	selected_level = i
	view.select_page.show_selection(selected_game, selected_difficulty, selected_level)


func _on_recheck() -> void:
	sensor.reset_values()
	_start_entry_test()


func _on_start() -> void:
	if selected_game == 0:
		_launch_rocking()
		return
	_show_modal("soon_title", "soon_body", "btn_ok", Callable(), [
		"game%d_title" % selected_game, "diff%d_name" % selected_difficulty])


## Rocking Challenge, Level A (carrot game) or Level B (balloon game). The app is hidden while the game runs
## and comes back on the game selection page when the player goes back.
func _launch_rocking() -> void:
	if transition.busy or game != null:
		return
	sfx.play_swoosh()
	transition.play(_open_rocking)   # v0.8.0: the cover closes, the game is swapped in, the cover opens


func _open_rocking() -> void:
	view.visible = false
	var g = BalloonPresenter.new() if selected_level == 1 else CarrotPresenter.new()
	g.difficulty = selected_difficulty
	g.lang = settings.lang
	g.sensor = null  # simulated sensor: each game uses its own keyboard input
	g.db = db
	g.exit_requested.connect(_on_game_exit)
	add_child(g)
	game = g


func _on_game_exit() -> void:
	if transition.busy:
		return
	sfx.play_swoosh()
	transition.play(_close_game)


func _close_game() -> void:
	if game != null:
		game.queue_free()
		game = null
	view.visible = true
	_show_select()


# ------------------------------------------------------------------ achievements and history
func _show_achievements() -> void:
	db.load_db()
	achievements.render()
	_show_page("achievements", "sub_achievements")


func _show_history() -> void:
	db.load_db()
	view.hist_page.show_status("")
	history.render()
	_show_page("history", "sub_history")
