extends Node
## Build 015b autoload "GameAudio": audio buses, background music and the
## sound setting (ON / LOW / OFF).
##
## - Buses: "Music" and "SFX" (sends to Master) come from res://default_bus_layout.tres,
##   loaded by the engine at start-up. Sfx.play() routes to "SFX". Don't create
##   buses at runtime: in the web export, buses added with AudioServer.add_bus()
##   after start-up are silent (sample playback never reaches the speakers).
##   ensure_buses() is only a desktop fallback if the layout file goes missing.
## - Music: two looping generated chiptune tracks (tools/gen_music.py):
##   "level" for normal levels, "boss" for the Trustin Judeau fight.
## - M key (anywhere) or the speaker icon (HUD on touch, title screen) cycles
##   ON -> LOW -> OFF. Saved in user://audio.cfg.
## - Web: browsers start the AudioContext suspended; Godot resumes it on the
##   first key / mouse / touch event, and the export's head_include adds a
##   belt-and-braces unlock for iOS Safari (see README "Build 015b").

signal setting_changed(index: int)

const SETTINGS_PATH := "user://audio.cfg"
const LEVELS := [1.0, 0.4, 0.0]
const LEVEL_NAMES := ["SOUND ON", "SOUND LOW", "SOUND OFF"]
const MUSIC_DB := -7.0
const TRACKS := {
	"level": preload("res://assets/audio/music_level.wav"),
	"boss": preload("res://assets/audio/music_boss.wav"),
}

var setting := 0
var track := ""
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	_load()
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = "Music"
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_apply()


static func ensure_buses() -> void:
	for n in ["Music", "SFX"]:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_M or k.keycode == KEY_M:
			cycle()
			get_viewport().set_input_as_handled()


## ON -> LOW -> OFF -> ON. Returns the new setting index.
func cycle() -> int:
	set_setting((setting + 1) % LEVELS.size())
	Sfx.play(self, "click", -6.0)
	return setting


func set_setting(i: int) -> void:
	setting = clampi(i, 0, LEVELS.size() - 1)
	_apply()
	_save()
	setting_changed.emit(setting)


func is_muted() -> bool:
	return float(LEVELS[setting]) <= 0.0


func setting_name() -> String:
	return LEVEL_NAMES[setting]


func _apply() -> void:
	var v: float = LEVELS[setting]
	AudioServer.set_bus_mute(0, v <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


func play_music(name: String) -> void:
	if not TRACKS.has(name):
		stop_music()
		return
	if track == name and _music.playing:
		return
	track = name
	_music.stream = TRACKS[name]
	_music.play()


func stop_music() -> void:
	track = ""
	if _music != null:
		_music.stop()


func is_music_playing() -> bool:
	return _music != null and _music.playing


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		setting = clampi(int(cf.get_value("audio", "setting", 0)), 0, LEVELS.size() - 1)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "setting", setting)
	cf.save(SETTINGS_PATH)
