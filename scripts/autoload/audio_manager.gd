extends Node

const FADE_DURATION: float = 1.5
const VOLUME_MIN_DB: float = -80.0
const VOLUME_MAX_DB: float = 0.0

var _player: AudioStreamPlayer
var _current_path: String = ""
var _pending_path: String = ""
var _tween: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	SceneManager.pre_scene_change.connect(stop_music)


func play_music(path: String) -> void:
	if path == _current_path and _player.playing:
		return
	if _tween:
		_tween.kill()
	_pending_path = path
	if _player.playing:
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", VOLUME_MIN_DB, FADE_DURATION)
		_tween.tween_callback(_start_pending_track)
	else:
		_start_pending_track()


func stop_music() -> void:
	if _tween:
		_tween.kill()
	_pending_path = ""
	if not _player.playing:
		return
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", VOLUME_MIN_DB, FADE_DURATION)
	_tween.tween_callback(func() -> void:
		_player.stop()
		_current_path = ""
	)


func _start_pending_track() -> void:
	if _pending_path.is_empty():
		return
	var stream: AudioStreamOggVorbis = load(_pending_path)
	stream.loop = true
	_player.stream = stream
	_current_path = _pending_path
	_pending_path = ""
	_player.volume_db = VOLUME_MIN_DB
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", VOLUME_MAX_DB, FADE_DURATION)
