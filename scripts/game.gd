extends Node3D

signal local_player_spawned(player: Node)

const KILLS_TO_WIN := 10
const NEW_GAME_DELAY := 5.0
const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var spawn_points: Node3D = $SpawnPoints
@onready var players_root: Node3D = $Players
@onready var hud: CanvasLayer = $HUD

var game_over: bool = false

func _ready() -> void:
	add_to_group("game")
	if NetworkManager.is_dedicated:
		hud.queue_free()
		var tc := get_node_or_null("TouchControls")
		if tc:
			tc.queue_free()
		return

	hud.bind_to_game(self)

	if NetworkManager.is_server():
		_do_spawn(NetworkManager.HOST_PEER_ID, _random_spawn_pos())
		# Push current leaderboard to host's HUD too.
		push_leaderboard.rpc(StatsStore.get_top())
	else:
		_client_ready.rpc_id(NetworkManager.HOST_PEER_ID,
			NetworkManager.local_skin_index,
			NetworkManager.local_player_name)

@rpc("any_peer", "reliable", "call_remote")
func _client_ready(skin_index: int, player_name: String) -> void:
	if not NetworkManager.is_server():
		return
	var new_peer_id := multiplayer.get_remote_sender_id()
	# Update the entry the server pre-created with this client's identity.
	if NetworkManager.players.has(new_peer_id):
		NetworkManager.players[new_peer_id]["skin_index"] = skin_index
		if player_name != "":
			NetworkManager.players[new_peer_id]["name"] = player_name
		NetworkManager._register_player.rpc(new_peer_id, NetworkManager.players[new_peer_id])
	for pid in NetworkManager.players.keys():
		if pid == new_peer_id:
			continue
		var existing := get_player_node(pid)
		if existing:
			_remote_spawn.rpc_id(new_peer_id, pid, existing.global_position)
	_remote_spawn.rpc(new_peer_id, _random_spawn_pos())
	# Send the new client the current leaderboard.
	push_leaderboard.rpc_id(new_peer_id, StatsStore.get_top())

func server_despawn_player(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	_remote_despawn.rpc(peer_id)

func _do_spawn(peer_id: int, spawn_pos: Vector3) -> void:
	if get_player_node(peer_id):
		return
	var p := PLAYER_SCENE.instantiate()
	p.name = str(peer_id)
	p.set_multiplayer_authority(peer_id)
	players_root.add_child(p, true)
	p.global_position = spawn_pos
	if NetworkManager.players.has(peer_id):
		var info: Dictionary = NetworkManager.players[peer_id]
		p.apply_identity(
			info.get("name", "P?"),
			info.get("color", Color.WHITE),
			info.get("skin_index", 0))
	if peer_id == multiplayer.get_unique_id():
		local_player_spawned.emit(p)

@rpc("authority", "reliable", "call_local")
func _remote_spawn(peer_id: int, spawn_pos: Vector3) -> void:
	_do_spawn(peer_id, spawn_pos)

@rpc("authority", "reliable", "call_local")
func _remote_despawn(peer_id: int) -> void:
	var node := get_player_node(peer_id)
	if node:
		node.queue_free()

# ─── Combat resolution (server authoritative) ───────────────────────

@rpc("any_peer", "reliable", "call_local")
func server_report_hit(victim_peer_id: int, damage: int) -> void:
	if not NetworkManager.is_server() or game_over:
		return
	var attacker_peer_id := multiplayer.get_remote_sender_id()
	if attacker_peer_id == 0:
		attacker_peer_id = NetworkManager.HOST_PEER_ID
	var victim := get_player_node(victim_peer_id)
	if victim == null or victim.health <= 0:
		return
	victim.take_damage_remote.rpc_id(victim_peer_id, damage, attacker_peer_id)

@rpc("any_peer", "reliable", "call_local")
func server_report_death(attacker_peer_id: int) -> void:
	if not NetworkManager.is_server() or game_over:
		return
	var victim_peer_id := multiplayer.get_remote_sender_id()
	if victim_peer_id == 0:
		victim_peer_id = NetworkManager.HOST_PEER_ID

	var attacker_info: Dictionary = NetworkManager.players.get(attacker_peer_id, {})
	var victim_info: Dictionary = NetworkManager.players.get(victim_peer_id, {})

	if attacker_info and attacker_peer_id != victim_peer_id:
		attacker_info["kills"] += 1
		NetworkManager.update_score.rpc(attacker_peer_id, attacker_info["kills"], attacker_info["deaths"])
	if victim_info:
		victim_info["deaths"] += 1
		NetworkManager.update_score.rpc(victim_peer_id, victim_info["kills"], victim_info["deaths"])

	# Persist to stats.json.
	var attacker_name: String = attacker_info.get("name", "?") if attacker_info else "?"
	var victim_name: String = victim_info.get("name", "?") if victim_info else "?"
	StatsStore.record_kill(attacker_name, victim_name)

	# Tell everyone to display the kill in the feed + center banner.
	announce_kill.rpc(attacker_peer_id, victim_peer_id)

	if attacker_info and attacker_info.get("kills", 0) >= KILLS_TO_WIN:
		game_over = true
		var participant_names: Array = []
		for pid in NetworkManager.players.keys():
			participant_names.append(NetworkManager.players[pid].get("name", "?"))
		StatsStore.record_match_end(attacker_name, participant_names)
		announce_winner.rpc(attacker_peer_id)
		push_leaderboard.rpc(StatsStore.get_top())
		_schedule_new_game()
		return

	respawn_player.rpc_id(victim_peer_id, _random_spawn_pos())

@rpc("authority", "reliable", "call_local")
func announce_kill(attacker_peer_id: int, victim_peer_id: int) -> void:
	if hud and is_instance_valid(hud):
		hud.show_kill(attacker_peer_id, victim_peer_id)

@rpc("authority", "reliable", "call_local")
func announce_winner(peer_id: int) -> void:
	game_over = true
	if hud and is_instance_valid(hud):
		hud.show_winner(peer_id)

@rpc("authority", "reliable", "call_local")
func push_leaderboard(rows: Array) -> void:
	StatsStore.update_cached_leaderboard(rows)
	if hud and is_instance_valid(hud):
		hud.show_leaderboard(rows)

@rpc("authority", "reliable", "call_local")
func respawn_player(pos: Vector3) -> void:
	var node := get_player_node(multiplayer.get_unique_id())
	if node:
		node.respawn_at(pos)

# ─── New-game cycle ─────────────────────────────────────────────────

func _schedule_new_game() -> void:
	if not NetworkManager.is_server():
		return
	new_game_countdown.rpc(NEW_GAME_DELAY)
	await get_tree().create_timer(NEW_GAME_DELAY).timeout
	if not is_inside_tree():
		return
	_start_new_game.rpc()

@rpc("authority", "reliable", "call_local")
func new_game_countdown(seconds: float) -> void:
	if hud and is_instance_valid(hud):
		hud.show_countdown(seconds)

@rpc("authority", "reliable", "call_local")
func _start_new_game() -> void:
	game_over = false
	NetworkManager.reset_all_scores()
	if hud and is_instance_valid(hud):
		hud.hide_winner()
	if NetworkManager.is_server():
		for pid in NetworkManager.players.keys():
			respawn_player.rpc_id(pid, _random_spawn_pos())

# ─── Helpers ─────────────────────────────────────────────────────────

func _random_spawn_pos() -> Vector3:
	var pts := spawn_points.get_children()
	if pts.is_empty():
		return Vector3(0, 2, 0)
	var p: Node3D = pts[randi() % pts.size()]
	return p.global_position

func get_player_node(peer_id: int) -> Node:
	return players_root.get_node_or_null(str(peer_id))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and game_over:
		NetworkManager.leave_game()
