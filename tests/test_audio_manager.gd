extends GutTest


func test_audio_manager_is_accessible() -> void:
	assert_not_null(AudioManager)


func test_audio_manager_has_play_music_method() -> void:
	assert_true(AudioManager.has_method("play_music"))


func test_audio_manager_has_stop_music_method() -> void:
	assert_true(AudioManager.has_method("stop_music"))
