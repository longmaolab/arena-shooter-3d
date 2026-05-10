extends Node

signal player_list_changed()
signal connection_failed()
signal disconnected()

const PORT := 7777
const MAX_PLAYERS := 8
const HOST_PEER_ID := 1
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

const COLORS := [
	Color(0.30, 0.70, 1.00),
	Color(1.00, 0.55, 0.30),
	Color(0.50, 1.00, 0.40),
	Color(1.00, 0.40, 0.85),
	Color(0.85, 0.85, 0.85),
	Color(1.00, 0.85, 0.30),
	Color(0.60, 0.40, 1.00),
	Color(0.30, 1.00, 0.85),
]

# peer_id -> { name, kills, deaths, color, skin_index }
var players: Dictionary = {}
var _next_player_index: int = 0

# Set true when this Godot instance is the dedicated headless server
# (no local player, no HUD). See start_dedicated_server().
var is_dedicated: bool = false

# Default server URL — production tunnel address baked in so Join works
# even if server.json fetch fails (browser cache, offline, etc.).
# server.json is now a soft override, useful when you change tunnels.
var default_server_url: String = "wss://game.boobank.com/arena-shooter/ws"

# The skin the local player picked in the main menu (0..17 → character-a..r).
var local_skin_index: int = 0

# Display name typed by the user in the main menu (used in scoreboard and
# leaderboard). Empty falls back to auto "Player N".
var local_player_name: String = "Player"

# Number of bots the host requested in the main menu (0–3). Read by game.gd
# right after the host scene loads to spawn server-controlled opponents.
var desired_bot_count: int = 0

const SETTINGS_FILE := "user://settings.cfg"
const SKIN_COUNT := 18
const COMMON_NAMES := [
	"Alex", "Jordan", "Taylor", "Casey", "Riley", "Morgan", "Sam", "Charlie",
	"Drew", "Jamie", "Pat", "Robin", "Quinn", "Avery", "Blake", "Cameron",
	"Devon", "Reese", "Jesse", "Skyler", "Max", "Leo", "Mia", "Zoe",
]

func load_settings() -> void:
	# Sticky if the user already customized (saved file exists with name key),
	# otherwise pick a random common name + skin so first-time players and
	# multi-window tests don't all show up as identical "Player"s.
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK and cfg.has_section_key("player", "name"):
		local_player_name = cfg.get_value("player", "name", "")
		local_skin_index = cfg.get_value("player", "skin_index", 0)
		if local_player_name != "":
			return
	randomize()
	local_player_name = COMMON_NAMES[randi() % COMMON_NAMES.size()]
	local_skin_index = randi() % SKIN_COUNT

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", local_player_name)
	cfg.set_value("player", "skin_index", local_skin_index)
	cfg.save(SETTINGS_FILE)

func is_server() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

# Host a match. On native builds this binds a real WebSocket server (so
# friends on LAN can join). On web (browser) we can't bind a socket, so
# we fall back to Godot's OfflineMultiplayerPeer — same multiplayer API
# surface, but no networking. The kid's PLAY vs BOTS button works on
# both platforms.
func host_game() -> int:
	if OS.has_feature("web"):
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_wire_signals()
	else:
		var err := _create_server()
		if err != OK:
			return err
	players[HOST_PEER_ID] = _make_player_entry(local_skin_index, local_player_name)
	get_tree().change_scene_to_file(GAME_SCENE)
	return OK

# Headless dedicated server. No local player; pure referee.
# Triggered by `godot --headless -- --server` on the Mac.
func start_dedicated_server() -> int:
	is_dedicated = true
	var err := _create_server()
	if err != OK:
		push_error("Dedicated server failed to start: %s" % err)
		return err
	print("[server] listening on port %d" % PORT)
	# Deferred so we don't fight whoever's still setting up children when
	# main_menu calls us inside its own _ready (Godot 4.6 throws "Parent
	# node is busy adding/removing children" otherwise).
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
	return OK

func _create_server() -> int:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		push_error("Host failed: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	_wire_signals()
	return OK

func join_game(host_input: String) -> int:
	var peer := WebSocketMultiplayerPeer.new()
	var url := _resolve_url(host_input.strip_edges())
	var err := peer.create_client(url)
	if err != OK:
		push_error("Join failed (%s): %s" % [url, err])
		return err
	multiplayer.multiplayer_peer = peer
	_wire_signals()
	return OK

# Accept "127.0.0.1", "host:port", "ws://...", or "wss://...".
func _resolve_url(raw: String) -> String:
	if raw.begins_with("ws://") or raw.begins_with("wss://"):
		return raw
	if ":" in raw:
		return "ws://%s" % raw
	return "ws://%s:%d" % [raw, PORT]

func leave_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	_next_player_index = 0
	is_dedicated = false
	if get_tree().current_scene and get_tree().current_scene.scene_file_path != MAIN_MENU_SCENE:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _wire_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_ok):
		multiplayer.connected_to_server.connect(_on_connected_ok)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _make_player_entry(skin_index: int = 0, display_name: String = "", is_bot: bool = false) -> Dictionary:
	_next_player_index += 1
	var resolved_name: String = display_name if display_name != "" else "Player %d" % _next_player_index
	return {
		"name": resolved_name,
		"kills": 0,
		"deaths": 0,
		"color": COLORS[(_next_player_index - 1) % COLORS.size()],
		"skin_index": skin_index,
		# Server-authoritative combat state. Only meaningful on the server;
		# clients see this dict for display fields (name/color/skin) only.
		"health": 100,
		"invincible": false,
		# Consecutive kills without dying — drives the streak announcer.
		"streak": 0,
		"is_bot": is_bot,
	}

func _on_peer_connected(peer_id: int) -> void:
	if not is_server():
		return
	players[peer_id] = _make_player_entry()
	player_list_changed.emit()
	_register_all_players.rpc_id(peer_id, players)
	_register_player.rpc(peer_id, players[peer_id])

func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	player_list_changed.emit()
	if not is_server():
		return
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("server_despawn_player"):
		game.server_despawn_player(peer_id)

func _on_connected_ok() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	_next_player_index = 0
	disconnected.emit()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

@rpc("authority", "reliable", "call_remote")
func _register_player(peer_id: int, info: Dictionary) -> void:
	players[peer_id] = info
	player_list_changed.emit()

@rpc("authority", "reliable", "call_remote")
func _register_all_players(roster: Dictionary) -> void:
	players = roster
	player_list_changed.emit()

@rpc("authority", "reliable", "call_local")
func update_score(peer_id: int, kills: int, deaths: int) -> void:
	if not players.has(peer_id):
		return
	players[peer_id]["kills"] = kills
	players[peer_id]["deaths"] = deaths
	player_list_changed.emit()

@rpc("authority", "reliable", "call_local")
func reset_all_scores() -> void:
	for pid in players.keys():
		players[pid]["kills"] = 0
		players[pid]["deaths"] = 0
	player_list_changed.emit()
