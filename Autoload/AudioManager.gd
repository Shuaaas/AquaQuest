extends Node
## AudioManager (Autoload Singleton)
##
## Central audio playback. Uses a small pool of AudioStreamPlayer nodes for
## SFX instead of instancing a new player per sound, which avoids GC churn
## and node-creation overhead on lower-end Android hardware. Music crossfades
## through two alternating players. Sound *assets* are looked up by id from
## a registry built at startup from Assets/Audio - this script contains no
## per-sound hardcoding.

const SFX_POOL_SIZE := 8

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player_index: int = 0

# sound_id -> AudioStream, populated by a registry/loader step (Assets/Audio scan
# or a manually authored Resources/Audio manifest). Left empty here intentionally -
# framework only.
var _sfx_registry: Dictionary = {}
var _music_registry: Dictionary = {}


func _ready() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		_music_players.append(player)

	EventBus.play_sfx_requested.connect(play_sfx)
	EventBus.play_music_requested.connect(play_music)
	EventBus.stop_music_requested.connect(stop_music)


## Called by whatever loads Assets/Audio at boot (e.g. a small loader in
## GameManager or a dedicated AudioRegistry Resource) to populate lookups.
func register_sfx(sfx_id: String, stream: AudioStream) -> void:
	_sfx_registry[sfx_id] = stream


func register_music(track_id: String, stream: AudioStream) -> void:
	_music_registry[track_id] = stream


func play_sfx(sfx_id: String) -> void:
	if not _sfx_registry.has(sfx_id):
		push_warning("AudioManager: unknown sfx_id '%s'" % sfx_id)
		return

	var player := _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_pool.size()
	player.stream = _sfx_registry[sfx_id]
	player.play()


func play_music(track_id: String, fade_time: float = 1.0) -> void:
	if not _music_registry.has(track_id):
		push_warning("AudioManager: unknown track_id '%s'" % track_id)
		return

	var next_index := (_active_music_player_index + 1) % _music_players.size()
	var outgoing := _music_players[_active_music_player_index]
	var incoming := _music_players[next_index]

	incoming.stream = _music_registry[track_id]
	incoming.volume_db = -80.0
	incoming.play()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, fade_time)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -80.0, fade_time)
		tween.chain().tween_callback(outgoing.stop)

	_active_music_player_index = next_index


func stop_music(fade_time: float = 1.0) -> void:
	var outgoing := _music_players[_active_music_player_index]
	if not outgoing.playing:
		return
	var tween := create_tween()
	tween.tween_property(outgoing, "volume_db", -80.0, fade_time)
	tween.tween_callback(outgoing.stop)
