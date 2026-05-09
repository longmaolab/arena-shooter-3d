extends Node3D

signal local_player_spawned(player: Node)

const KILLS_TO_WIN := 10
const NEW_GAME_DELAY := 5.0
const PLAYER_SCENE := preload("res://scenes/player.tscn")

# Server-authoritative combat constants. Damage is NOT trusted from clients.
const SERVER_MAX_HEALTH := 100
const SERVER_RESPAWN_INVINCIBILITY := 1.5
# Mirror of player.gd::WEAPONS but only the damage columns the server cares
# about. Index matches the player-side WEAPONS array (0=PISTOL, 1=SMG, 2=SHOTGUN).
# Shotgun "body"/"head" are *per pellet* — five pellets all landing means
# 5×18=90 body or 5×36=180 head at point blank.
const SERVER_WEAPON_DAMAGE := [
	{"body": 50, "head": 100},
	{"body": 25, "head": 50},
	{"body": 18, "head": 36},
]

@onready var spawn_points: Node3D = $SpawnPoints
@onready var players_root: Node3D = $Players
@onready var hud: CanvasLayer = $HUD

var game_over: bool = false

func _ready() -> void:
	add_to_group("game")
	# Seed the PRNG so the spawn-point picks aren't identical run-to-run.
	randomize()
	if NetworkManager.is_dedicated:
		hud.queue_free()
		var tc := get_node_or_null("TouchControls")
		if tc:
			tc.queue_free()
		return

	hud.bind_to_game(self)

	if NetworkManager.is_server():
		_do_spawn(NetworkManager.HOST_PEER_ID, _random_spawn_pos())
		_spawn_bots(NetworkManager.desired_bot_count)
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
		# Refresh host's own scoreboard — _register_player is call_remote.
		NetworkManager.player_list_changed.emit()
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
	# Bots use negative peer_ids and are server-controlled, so authority
	# must point at the host (the player_id is just an attribution tag).
	var is_bot: bool = peer_id < 0
	if is_bot:
		p.set_multiplayer_authority(NetworkManager.HOST_PEER_ID)
	else:
		p.set_multiplayer_authority(peer_id)
	# Player-side fields the player.gd uses to know which entity it is.
	p.player_peer_id = peer_id
	p._is_bot = is_bot
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

func _spawn_bots(count: int) -> void:
	if count <= 0:
		return
	if not NetworkManager.is_server():
		return
	for i in count:
		var bot_id := -(i + 1)  # -1, -2, -3
		# Register in NetworkManager so the scoreboard / kill feed find them.
		var bot_skin: int = randi() % 18
		var bot_name := "BOT %d" % (i + 1)
		var entry := NetworkManager._make_player_entry(bot_skin, bot_name, true)
		NetworkManager.players[bot_id] = entry
		NetworkManager.player_list_changed.emit()
		NetworkManager._register_player.rpc(bot_id, entry)
		_remote_spawn.rpc(bot_id, _random_spawn_pos())

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
func server_report_hit(victim_peer_id: int, weapon_idx: int, is_headshot: bool, hit_pos: Vector3) -> void:
	# Thin RPC wrapper that resolves the attacker from the network sender,
	# then delegates to the shared _process_hit. Bots bypass this entirely
	# by calling _process_hit directly with their own bot peer_id.
	if not NetworkManager.is_server() or game_over:
		return
	var attacker_peer_id := multiplayer.get_remote_sender_id()
	if attacker_peer_id == 0:
		# Local call from the host's human player.
		attacker_peer_id = NetworkManager.HOST_PEER_ID
	_process_hit(attacker_peer_id, victim_peer_id, weapon_idx, is_headshot, hit_pos)

func _process_hit(attacker_peer_id: int, victim_peer_id: int, weapon_idx: int, is_headshot: bool, hit_pos: Vector3) -> void:
	# Server-authoritative: damage is NOT taken from the client. Both the
	# weapon index and the headshot claim are hints — we clamp the weapon
	# index to a known table and re-validate the impact Y before granting
	# bonus damage.
	if not NetworkManager.is_server() or game_over:
		return
	if attacker_peer_id == victim_peer_id:
		return
	if not NetworkManager.players.has(attacker_peer_id):
		return
	if not NetworkManager.players.has(victim_peer_id):
		return
	var attacker_info: Dictionary = NetworkManager.players[attacker_peer_id]
	var victim_info: Dictionary = NetworkManager.players[victim_peer_id]
	var current_health: int = int(victim_info.get("health", SERVER_MAX_HEALTH))
	if current_health <= 0:
		return
	if bool(victim_info.get("invincible", false)):
		return
	# Sanity check: attacker must be alive to land hits.
	if int(attacker_info.get("health", SERVER_MAX_HEALTH)) <= 0:
		return
	# Validate the headshot claim against the server's view of the victim.
	var victim_node := get_player_node(victim_peer_id)
	var validated_headshot := false
	if is_headshot and victim_node and is_instance_valid(victim_node):
		var dy: float = hit_pos.y - victim_node.global_position.y
		validated_headshot = dy > 1.0 and dy < 2.5
	# Look up damage from the server-side weapon table (clamped, never trusted from client).
	var safe_idx: int = clampi(weapon_idx, 0, SERVER_WEAPON_DAMAGE.size() - 1)
	var dmg_row: Dictionary = SERVER_WEAPON_DAMAGE[safe_idx]
	var damage: int = int(dmg_row["head"]) if validated_headshot else int(dmg_row["body"])
	var new_health: int = max(0, current_health - damage)
	victim_info["health"] = new_health
	if victim_node and is_instance_valid(victim_node) and not victim_node.is_queued_for_deletion():
		# Route via multiplayer authority — for bots that's the host (positive
		# id), not the bot's negative attribution id which isn't a real peer.
		var rpc_target: int = victim_node.get_multiplayer_authority()
		victim_node.take_damage_remote.rpc_id(
			rpc_target, new_health, damage, attacker_peer_id)
	# Floating damage number visible to everyone (the shooter cares most, but
	# bystanders can see when their teammate is being chunked).
	spawn_damage_number.rpc(hit_pos, damage, validated_headshot)
	if new_health <= 0:
		_handle_kill(attacker_peer_id, victim_peer_id)

@rpc("authority", "unreliable", "call_local")
func spawn_damage_number(pos: Vector3, damage: int, is_headshot: bool) -> void:
	var label := Label3D.new()
	label.text = ("HEAD! -%d" % damage) if is_headshot else ("-%d" % damage)
	label.font_size = 64 if is_headshot else 48
	label.outline_size = 8
	label.modulate = Color(1, 0.30, 0.30) if is_headshot else Color(1, 0.92, 0.40)
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0028
	get_tree().current_scene.add_child(label)
	label.global_position = pos + Vector3(0, 0.4, 0)
	var rise_target: Vector3 = label.global_position + Vector3(randf_range(-0.3, 0.3), 1.4, 0)
	var tw := label.create_tween()
	tw.tween_property(label, "global_position", rise_target, 0.8)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(label.queue_free)

func _handle_kill(attacker_peer_id: int, victim_peer_id: int) -> void:
	# Called only from server_report_hit on the server. No client RPC entry.
	var attacker_info: Dictionary = NetworkManager.players.get(attacker_peer_id, {})
	var victim_info: Dictionary = NetworkManager.players.get(victim_peer_id, {})

	if attacker_info and attacker_peer_id != victim_peer_id:
		attacker_info["kills"] += 1
		NetworkManager.update_score.rpc(attacker_peer_id, attacker_info["kills"], attacker_info["deaths"])
	if victim_info:
		victim_info["deaths"] += 1
		NetworkManager.update_score.rpc(victim_peer_id, victim_info["kills"], victim_info["deaths"])

	var attacker_name: String = attacker_info.get("name", "?") if attacker_info else "?"
	var victim_name: String = victim_info.get("name", "?") if victim_info else "?"
	StatsStore.record_kill(attacker_name, victim_name)
	announce_kill.rpc(attacker_peer_id, victim_peer_id)

	# Streak tracking — increment attacker, reset victim, and announce at
	# meaningful thresholds (2 / 3 / 5 / 7 consecutive kills without dying).
	if victim_info:
		victim_info["streak"] = 0
	if attacker_info and attacker_peer_id != victim_peer_id:
		var streak: int = int(attacker_info.get("streak", 0)) + 1
		attacker_info["streak"] = streak
		if streak == 2 or streak == 3 or streak == 5 or streak == 7:
			announce_streak.rpc(attacker_peer_id, streak)

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

	# Server-driven respawn with invincibility window.
	if victim_info:
		victim_info["health"] = SERVER_MAX_HEALTH
		victim_info["invincible"] = true
	_respawn_player(victim_peer_id, _random_spawn_pos())
	_clear_invincibility(victim_peer_id)

func _respawn_player(peer_id: int, pos: Vector3) -> void:
	# Bots respawn server-side directly (no RPC); humans get the existing
	# respawn_player RPC which expects the receiver to know which player is
	# theirs via multiplayer.get_unique_id().
	var node := get_player_node(peer_id)
	if node and node._is_bot:
		node.respawn_at(pos)
		return
	respawn_player.rpc_id(peer_id, pos)

func _clear_invincibility(peer_id: int) -> void:
	await get_tree().create_timer(SERVER_RESPAWN_INVINCIBILITY).timeout
	if NetworkManager.players.has(peer_id):
		NetworkManager.players[peer_id]["invincible"] = false

@rpc("authority", "reliable", "call_local")
func announce_kill(attacker_peer_id: int, victim_peer_id: int) -> void:
	if hud and is_instance_valid(hud):
		hud.show_kill(attacker_peer_id, victim_peer_id)

@rpc("authority", "reliable", "call_local")
func announce_streak(peer_id: int, streak: int) -> void:
	if hud and is_instance_valid(hud):
		hud.show_streak(peer_id, streak)

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
			NetworkManager.players[pid]["health"] = SERVER_MAX_HEALTH
			NetworkManager.players[pid]["invincible"] = false
			NetworkManager.players[pid]["streak"] = 0
			_respawn_player(pid, _random_spawn_pos())

# ─── Helpers ─────────────────────────────────────────────────────────

func _random_spawn_pos() -> Vector3:
	# Score each spawn point by distance to the closest other player and
	# pick randomly from the top half. That avoids "respawn-and-die-again"
	# right next to the same enemy that just killed you, but keeps enough
	# randomness that you don't always spawn in the exact same corner.
	var pts := spawn_points.get_children()
	if pts.is_empty():
		return Vector3(0, 2, 0)
	# Threats = every player still in the scene with HP > 0. Includes the
	# victim's old death location, so the new spawn is far from where they
	# just got killed.
	var threats: Array = []
	for child in players_root.get_children():
		if int(child.health) <= 0:
			continue
		threats.append(child.global_position)
	if threats.is_empty():
		return pts[randi() % pts.size()].global_position
	var scored: Array = []
	for pt in pts:
		var pt_pos: Vector3 = pt.global_position
		var min_d: float = INF
		for tp in threats:
			var d: float = pt_pos.distance_to(tp)
			if d < min_d:
				min_d = d
		scored.append({"pt": pt_pos, "safety": min_d})
	scored.sort_custom(func(a, b): return a["safety"] > b["safety"])
	# Random from top half — safe but still varies between deaths.
	var pool_n: int = maxi(1, scored.size() / 2)
	return scored[randi() % pool_n]["pt"]

func get_player_node(peer_id: int) -> Node:
	return players_root.get_node_or_null(str(peer_id))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and game_over:
		NetworkManager.leave_game()
