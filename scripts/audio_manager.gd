extends Node

## AudioManager - Handles background music and sound effects using real project audio assets

const BGM_STREAM: AudioStream = preload("res://assets/sound/background_music.wav")
const LEVEL_COMPLETE_STREAM: AudioStream = preload("res://assets/sound/level_complete.mp3")
const LEVEL_FAIL_STREAM: AudioStream = preload("res://assets/sound/level_fail.mp3")
const STAR_STREAM: AudioStream = preload("res://assets/sound/star_sound.mp3")
const COIN_STREAM: AudioStream = preload("res://assets/sound/coin_sound.wav")
const RIGHT_STREAM: AudioStream = preload("res://assets/sound/right_answer.mp3")
const WRONG_STREAM: AudioStream = preload("res://assets/sound/wrong_answer.mp3")
const ELECTRIC_FLOW_STREAM: AudioStream = preload("res://assets/sound/electric_flow.wav")

var music_player: AudioStreamPlayer
var win_player: AudioStreamPlayer
var lose_player: AudioStreamPlayer
var star_player: AudioStreamPlayer
var coin_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var flow_player: AudioStreamPlayer

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	win_player = AudioStreamPlayer.new()
	lose_player = AudioStreamPlayer.new()
	star_player = AudioStreamPlayer.new()
	coin_player = AudioStreamPlayer.new()
	sfx_player = AudioStreamPlayer.new()
	flow_player = AudioStreamPlayer.new()

	add_child(music_player)
	add_child(win_player)
	add_child(lose_player)
	add_child(star_player)
	add_child(coin_player)
	add_child(sfx_player)
	add_child(flow_player)

	# Balance volumes
	music_player.volume_db = -14.0
	win_player.volume_db = -2.0
	lose_player.volume_db = -2.0
	star_player.volume_db = -1.0
	coin_player.volume_db = -2.0
	sfx_player.volume_db = -4.0
	flow_player.volume_db = -3.0

	# Setup background music
	music_player.stream = BGM_STREAM
	music_player.finished.connect(_restart_music)

	if GameState.music_enabled:
		music_player.play()

func _restart_music() -> void:
	if GameState.music_enabled and is_instance_valid(music_player):
		music_player.play()

func set_music_enabled(enabled: bool) -> void:
	if enabled:
		if not music_player.playing:
			music_player.play()
	else:
		music_player.stop()

# =============================================================
# GAME SFX PLAYBACK USING USER AUDIO ASSETS
# =============================================================

func play_win() -> void:
	play_level_complete()

func play_victory() -> void:
	play_level_complete()

func play_level_complete() -> void:
	if not GameState.sfx_enabled:
		return
	win_player.stream = LEVEL_COMPLETE_STREAM
	win_player.pitch_scale = 1.0
	win_player.play()

func play_lose() -> void:
	play_level_fail()

func play_fail() -> void:
	play_level_fail()

func play_level_fail() -> void:
	if not GameState.sfx_enabled:
		return
	lose_player.stream = LEVEL_FAIL_STREAM
	lose_player.pitch_scale = 1.0
	lose_player.play()

func play_star(pitch: float = 1.0) -> void:
	if not GameState.sfx_enabled:
		return
	star_player.stream = STAR_STREAM
	star_player.pitch_scale = pitch
	star_player.play()

func play_coin(pitch: float = 1.0) -> void:
	if not GameState.sfx_enabled:
		return
	coin_player.stream = COIN_STREAM
	coin_player.pitch_scale = pitch
	coin_player.play()

func play_right() -> void:
	if not GameState.sfx_enabled:
		return
	sfx_player.stream = RIGHT_STREAM
	sfx_player.pitch_scale = 1.0
	sfx_player.play()

func play_wrong() -> void:
	if not GameState.sfx_enabled:
		return
	sfx_player.stream = WRONG_STREAM
	sfx_player.pitch_scale = 1.0
	sfx_player.play()

func play_click() -> void:
	if not GameState.sfx_enabled:
		return
	sfx_player.stream = RIGHT_STREAM
	sfx_player.pitch_scale = 1.4
	sfx_player.play()

func play_place(correct: bool) -> void:
	if correct:
		play_right()
	else:
		play_wrong()

func play_undo() -> void:
	if not GameState.sfx_enabled:
		return
	sfx_player.stream = WRONG_STREAM
	sfx_player.pitch_scale = 1.2
	sfx_player.play()

func play_hint() -> void:
	if not GameState.sfx_enabled:
		return
	sfx_player.stream = RIGHT_STREAM
	sfx_player.pitch_scale = 1.15
	sfx_player.play()

func play_electric_flow(pitch: float = 1.0) -> void:
	if not GameState.sfx_enabled:
		return
	flow_player.stream = ELECTRIC_FLOW_STREAM
	flow_player.pitch_scale = pitch
	flow_player.play()

func stop_electric_flow() -> void:
	if is_instance_valid(flow_player) and flow_player.playing:
		flow_player.stop()
