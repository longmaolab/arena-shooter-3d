extends Node

signal player_list_changed()
signal connection_failed()
signal disconnected()

const PORT := 7777
const MAX_PLAYERS := 4
const HOST_PEER_ID := 1
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

const COLORS := [
	Color(0.30, 0.70, 1.00),  # blue
	Color(1.00, 0.55, 0.30),  # orange
	Color(0.50, 1.00, 0.40),  # green
	Color(1.00, 0.40, 0.85),  # pink
]

# peer_id -> { name, kills, deaths, color }
var players: Dictionary = {}
# Monotonic counter — guarantees stable, unique P# names even after disconnects.
var _next_player_index: int = 0

func is_server() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

func host_game() -> int:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		push_error("Host failed: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	_wire_signals()
	players[HOST_PEER_ID] = _make_player_entry()
	get_tree().change_scene_to_file(GAME_SCENE)
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

# Accept any of:
#   "127.0.0.1"            → ws://127.0.0.1:7777
#   "192.168.1.10:7777"    → ws://192.168.1.10:7777
#   "ws://host:port"       → as-is
#   "wss://abc.ngrok.io"   → as-is (TLS, e.g. through ngrok for browser play)
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

func _make_player_entry() -> Dictionary:
	_next_player_index += 1
	return {
		"name": "P%d" % _next_player_index,
		"kills": 0,
		"deaths": 0,
		"color": COLORS[(_next_player_index - 1) % COLORS.size()],
	}

func _on_peer_connected(peer_id: int) -> void:
	if not is_server():
		return
	players[peer_id] = _make_player_entry()
	player_list_changed.emit()
	# Single RPC: send the entire roster to the new peer (avoids N+1).
	_register_all_players.rpc_id(peer_id, players)
	# Tell existing peers about the new joiner.
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
