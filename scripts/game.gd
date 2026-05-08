extends Node3D

signal local_player_spawned(player: Node)

const KILLS_TO_WIN := 10
const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var spawn_points: Node3D = $SpawnPoints
@onready var players_root: Node3D = $Players
@onready var hud: CanvasLayer = $HUD

var game_over: bool = false

func _ready() -> void:
	add_to_group("game")
	hud.bind_to_game(self)

	if NetworkManager.is_server():
		_do_spawn(NetworkManager.HOST_PEER_ID, _random_spawn_pos())
	else:
		_client_ready.rpc_id(NetworkManager.HOST_PEER_ID)

@rpc("any_peer", "reliable", "call_remote")
func _client_ready() -> void:
	if not NetworkManager.is_server():
		return
	var new_peer_id := multiplayer.get_remote_sender_id()
	# Catch the new client up on every existing player (server-side truth)
	for pid in NetworkManager.players.keys():
		if pid == new_peer_id:
			continue
		var existing := get_player_node(pid)
		if existing:
			_remote_spawn.rpc_id(new_peer_id, pid, existing.global_position)
	# Broadcast new player spawn to everyone (call_local: also creates on host)
	_remote_spawn.rpc(new_peer_id, _random_spawn_pos())

func server_despawn_player(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	_remote_despawn.rpc(peer_id)

func _do_spawn(peer_id: int, spawn_pos: Vector3) -> void:
	if get_player_node(peer_id):
		return
	var p := PLAYER_SCENE.instantiate()
	p.name = str(peer_id)
	# Authority must be set BEFORE add_child so _ready() reads it correctly.
	p.set_multiplayer_authority(peer_id)
	players_root.add_child(p, true)
	p.global_position = spawn_pos
	if NetworkManager.players.has(peer_id):
		var info: Dictionary = NetworkManager.players[peer_id]
		p.apply_identity(info.get("name", "P?"), info.get("color", Color.WHITE))
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
	# Update scores (authoritative)
	var attacker_info: Dictionary = NetworkManager.players.get(attacker_peer_id, {})
	var victim_info: Dictionary = NetworkManager.players.get(victim_peer_id, {})
	if attacker_info and attacker_peer_id != victim_peer_id:
		attacker_info["kills"] += 1
		NetworkManager.update_score.rpc(attacker_peer_id, attacker_info["kills"], attacker_info["deaths"])
	if victim_info:
		victim_info["deaths"] += 1
		NetworkManager.update_score.rpc(victim_peer_id, victim_info["kills"], victim_info["deaths"])
	# Win check
	if attacker_info and attacker_info.get("kills", 0) >= KILLS_TO_WIN:
		game_over = true
		announce_winner.rpc(attacker_peer_id)
		return
	respawn_player.rpc_id(victim_peer_id, _random_spawn_pos())

@rpc("authority", "reliable", "call_local")
func announce_winner(peer_id: int) -> void:
	game_over = true
	hud.show_winner(peer_id)

@rpc("authority", "reliable", "call_local")
func respawn_player(pos: Vector3) -> void:
	# call_local lets the host respawn themselves when they're the victim.
	# rpc_id targets only the victim, so only they execute this.
	var node := get_player_node(multiplayer.get_unique_id())
	if node:
		node.respawn_at(pos)

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
