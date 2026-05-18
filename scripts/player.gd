extends CharacterBody3D

signal local_health_changed(new_health: int)
signal local_ammo_changed(new_ammo: int)
signal local_damage_taken(amount: int)
signal local_died()
signal local_respawned()
signal local_hit_marker()
signal local_weapon_changed(weapon_index: int, weapon_name: String, ammo_count: int, max_ammo: int)

const SPEED            := 6.0
const SPRINT_SPEED     := 10.0
const JUMP_VELOCITY    := 8.5
const GRAVITY          := 24.0
const MOUSE_SENSITIVITY := 0.0022
const TOUCH_LOOK_SENSITIVITY := 0.005
const MAX_HEALTH       := 100
# Per-weapon stats. Damage values live on the server (game.gd::SERVER_WEAPON_DAMAGE)
# so clients can never inflate them.
const WEAPONS := [
	{"name": "PISTOL",  "fire_rate": 0.40, "max_ammo": 12, "spread": 0.00, "pellets": 1, "reload_time": 1.2},
	{"name": "SMG",     "fire_rate": 0.12, "max_ammo": 30, "spread": 0.02, "pellets": 1, "reload_time": 1.4},
	{"name": "SHOTGUN", "fire_rate": 0.80, "max_ammo": 8,  "spread": 0.18, "pellets": 5, "reload_time": 2.2},
]
const SYNC_INTERVAL    := 0.05
const RESPAWN_INVINCIBILITY := 2.5  # matches game.gd::SERVER_RESPAWN_INVINCIBILITY

const SKIN_COUNT := 18
const SKIN_PATH_PREFIX := "res://models/characters/character-"
const MODEL_SCALE := 0.95

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_SPRINT := "sprint"
const ANIM_DIE := "die"
const LOOPED_ANIMS := [ANIM_IDLE, ANIM_WALK, ANIM_SPRINT]

const SFX_SHOOT := preload("res://audio/shoot.ogg")
const SFX_HIT := preload("res://audio/hit.ogg")
const SFX_DEATH := preload("res://audio/death.ogg")
const SFX_RESPAWN := preload("res://audio/respawn.ogg")

var health: int = MAX_HEALTH
# Default to SMG (index 1) so the v6.0–v6.8 feel is preserved.
var current_weapon: int = 1
var weapon_ammo: Array[int] = [12, 30, 8]
var can_shoot: bool = true
var is_reloading: bool = false
var is_invincible: bool = false
var sync_timer: float = 0.0
var _game: Node = null
var _current_skin: int = -1
var _anim_player: AnimationPlayer = null
var _current_anim: String = ""

# Bot integration. game.gd::_do_spawn fills these in right after instancing.
# `player_peer_id` is the *attribution* id (positive for humans, negative
# for bots); `is_multiplayer_authority()` answers a different question
# (who controls this body — the host for bots, the player themselves for
# humans).
var _is_bot: bool = false
var player_peer_id: int = 0

# First-person weapon meshes parented under Camera3D. Built once on local
# authority spawn; nil for remote-viewed players and bots so remote
# observers don't see a floating gun glued to someone else's face.
var _weapon_views: Array[Node3D] = []

# Seconds remaining where the shoot action is ignored after a click that
# re-captured the mouse. Keeps the "click to resume" gesture from
# accidentally firing a shot.
var _recapture_shot_suppress: float = 0.0

# Bot AI state — only meaningful when _is_bot is true and we're on the host.
const BOT_VIEW_RANGE := 22.0
const BOT_LOSE_RANGE := 30.0
const BOT_FIRE_INTERVAL := 0.7
const BOT_WANDER_BOUND := 25.0
const BOT_ENGAGE_IDEAL := 12.0
enum BotState { WANDER = 0, ENGAGE = 1 }
var _bot_state: int = BotState.WANDER
var _bot_target: Node = null
var _bot_wander_target: Vector3 = Vector3.ZERO
var _bot_state_time: float = 0.0
var _bot_fire_cooldown: float = 0.0

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var muzzle: MeshInstance3D = $Camera3D/MuzzleFlash
@onready var model_holder: Node3D = $ModelHolder
@onready var name_label: Label3D = $NameLabel
@onready var audio_3d: AudioStreamPlayer3D = $Audio3D
@onready var audio_2d: AudioStreamPlayer = $Audio2D

static func skin_letter(idx: int) -> String:
	var clamped: int = clamp(idx, 0, SKIN_COUNT - 1)
	return String.chr("a".unicode_at(0) + clamped)

static func skin_path(idx: int) -> String:
	return "%s%s.glb" % [SKIN_PATH_PREFIX, skin_letter(idx)]

func _ready() -> void:
	add_to_group("player")
	muzzle.visible = false
	ray.add_exception(self)
	call_deferred("_setup_authority_visuals")

func _setup_authority_visuals() -> void:
	_game = get_tree().get_first_node_in_group("game")
	# Hold off on broadcasting _remote_state for ~1.5 s after spawn. A late-
	# joining peer's game scene hasn't loaded yet, and continuous 20 Hz state
	# RPCs would otherwise spam "Node not found: Game/Players/N" errors on
	# their console for several frames. By the time the grace window ends,
	# the host's _client_ready handler has already replied with the
	# _remote_spawn RPCs that create our peer node on every client.
	sync_timer = 1.5
	if is_multiplayer_authority():
		if _is_bot:
			# Bot is server-controlled but not the local human; keep the body
			# visible to everyone, including the host that's running the AI.
			# Disable input handling — AI tick drives everything.
			set_process_input(false)
			set_process_unhandled_input(false)
			# Pre-seed a wander target so the AI has somewhere to go.
			_bot_wander_target = Vector3(
				randf_range(-BOT_WANDER_BOUND, BOT_WANDER_BOUND), 0,
				randf_range(-BOT_WANDER_BOUND, BOT_WANDER_BOUND))
		else:
			add_to_group("local_player")
			model_holder.visible = false
			name_label.visible = false
			camera.current = true
			_grab_mouse()
			_build_weapon_views()
			_update_weapon_view_visibility()
			# Push initial weapon state to whoever's listening (HUD).
			var w: Dictionary = WEAPONS[current_weapon]
			local_weapon_changed.emit(
				current_weapon, str(w["name"]),
				weapon_ammo[current_weapon], int(w["max_ammo"]))
	else:
		camera.current = false
		ray.enabled = false
		set_process_input(false)
		set_process_unhandled_input(false)
		set_physics_process(false)

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	if not is_inside_tree() or not is_multiplayer_authority():
		return
	if DisplayServer.is_touchscreen_available():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_grab_mouse()

func _grab_mouse() -> void:
	if DisplayServer.is_touchscreen_available():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func apply_identity(player_name: String, color: Color, skin_index: int) -> void:
	name_label.text = player_name
	name_label.modulate = color
	apply_skin(skin_index)

func apply_skin(skin_index: int) -> void:
	if skin_index == _current_skin and model_holder.get_child_count() > 0:
		return
	_current_skin = skin_index
	for c in model_holder.get_children():
		c.queue_free()
	var path := skin_path(skin_index)
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning("Skin not found: " + path)
		return
	var model: Node3D = scene.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	model_holder.add_child(model)
	# Wire up the AnimationPlayer baked into the GLB.
	_anim_player = _find_animation_player(model)
	if _anim_player:
		# Make movement anims loop; one-shots like 'die' stay one-shot.
		for n in _anim_player.get_animation_list():
			if n in LOOPED_ANIMS:
				var anim := _anim_player.get_animation(n)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
		_play_anim(ANIM_IDLE)

func _find_player_root(node: Node) -> CharacterBody3D:
	# Kenney GLB body parts come with their own StaticBody3D colliders,
	# so the ray hits a child node rather than the player root.
	var n: Node = node
	while n:
		if n is CharacterBody3D and n.is_in_group("player"):
			return n
		n = n.get_parent()
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_animation_player(c)
		if found:
			return found
	return null

func _play_anim(anim: String) -> void:
	if _anim_player == null or anim == _current_anim:
		return
	if not _anim_player.has_animation(anim):
		return
	_current_anim = anim
	# Cross-fade between movement anims so idle↔walk↔sprint doesn't pop.
	# 'die' wants no blend so the snap reads clearly.
	var blend := 0.0 if anim == ANIM_DIE else 0.12
	_anim_player.play(anim, blend)

func _select_anim() -> String:
	if health <= 0:
		return ANIM_DIE
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal > 7.5:
		return ANIM_SPRINT
	if horizontal > 0.4:
		return ANIM_WALK
	return ANIM_IDLE

func apply_touch_look(delta_vec: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	rotate_y(-delta_vec.x)
	camera.rotate_x(-delta_vec.y)
	camera.rotation.x = clamp(camera.rotation.x, -1.25, 1.25)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.25, 1.25)
	# Left-click anywhere in the game window re-captures the mouse after the
	# kid pressed ESC. Without this branch they could move + shoot but
	# couldn't turn (mouse motion is gated on MOUSE_MODE_CAPTURED above).
	# Suppress the shoot action for ~0.1 s so the click used to refocus
	# the canvas doesn't also fire a bullet. Touchscreen guard is here AND
	# inside _grab_mouse() — belt and suspenders so a tap never silently
	# locks the cursor on a phone.
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE \
			and not DisplayServer.is_touchscreen_available():
		_grab_mouse()
		_recapture_shot_suppress = 0.1
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: switch_weapon(0)
			KEY_2: switch_weapon(1)
			KEY_3: switch_weapon(2)
			KEY_ESCAPE:
				Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
					else Input.MOUSE_MODE_CAPTURED)

# ─── Weapon switching (called from keyboard or touch buttons) ─────────

func switch_weapon(idx: int) -> void:
	if not is_multiplayer_authority():
		return
	if idx == current_weapon or idx < 0 or idx >= WEAPONS.size():
		return
	is_reloading = false
	current_weapon = idx
	_update_weapon_view_visibility()
	var w: Dictionary = WEAPONS[idx]
	local_weapon_changed.emit(
		idx, str(w["name"]), weapon_ammo[idx], int(w["max_ammo"]))
	local_ammo_changed.emit(weapon_ammo[idx])

# ─── First-person weapon view ────────────────────────────────────────
# Three low-poly gun models parented under Camera3D. Built procedurally to
# keep player.tscn clean. Only the active weapon's model is visible at any
# given time; switch_weapon() swaps which one is shown.

func _build_weapon_views() -> void:
	if _weapon_views.size() > 0:
		return  # already built
	_weapon_views.resize(3)
	_weapon_views[0] = _build_pistol_view()
	_weapon_views[1] = _build_smg_view()
	_weapon_views[2] = _build_shotgun_view()
	for v in _weapon_views:
		camera.add_child(v)
		v.visible = false

func _update_weapon_view_visibility() -> void:
	for i in _weapon_views.size():
		if _weapon_views[i]:
			_weapon_views[i].visible = (i == current_weapon)

func _gun_material(accent: Color, accent_strength: float = 1.6) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.22)
	mat.metallic = 0.65
	mat.metallic_specular = 0.5
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = accent
	mat.emission_energy_multiplier = accent_strength * 0.18
	return mat

func _gun_part(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material_override = mat
	parent.add_child(b)

func _build_pistol_view() -> Node3D:
	# Compact handgun. Sits a bit closer than the longer guns.
	var root := Node3D.new()
	root.name = "PistolView"
	var mat := _gun_material(Color(1.0, 0.85, 0.30))
	var off := Vector3(0.22, -0.16, -0.50)
	_gun_part(root, Vector3(0.06, 0.16, 0.07), off + Vector3(0, -0.10, 0.05), mat)  # grip
	_gun_part(root, Vector3(0.06, 0.07, 0.18), off, mat)                            # slide/body
	_gun_part(root, Vector3(0.02, 0.02, 0.02), off + Vector3(0, 0.04, -0.08), mat)  # front sight
	return root

func _build_smg_view() -> Node3D:
	# Medium-length submachine gun.
	var root := Node3D.new()
	root.name = "SmgView"
	var mat := _gun_material(Color(0.45, 0.85, 1.0))
	var off := Vector3(0.22, -0.16, -0.50)
	_gun_part(root, Vector3(0.05, 0.16, 0.06), off + Vector3(0, -0.10, 0.07), mat)   # grip
	_gun_part(root, Vector3(0.07, 0.08, 0.32), off, mat)                              # body
	_gun_part(root, Vector3(0.05, 0.12, 0.04), off + Vector3(0, -0.10, -0.02), mat)   # magazine
	_gun_part(root, Vector3(0.04, 0.04, 0.10), off + Vector3(0, 0.02, -0.20), mat)    # barrel
	return root

func _build_shotgun_view() -> Node3D:
	# Bulky pump-action.
	var root := Node3D.new()
	root.name = "ShotgunView"
	var mat := _gun_material(Color(1.0, 0.60, 0.30))
	var off := Vector3(0.22, -0.16, -0.50)
	_gun_part(root, Vector3(0.06, 0.18, 0.08), off + Vector3(0, -0.10, 0.10), mat)   # grip
	_gun_part(root, Vector3(0.08, 0.10, 0.36), off, mat)                              # receiver
	_gun_part(root, Vector3(0.07, 0.07, 0.12), off + Vector3(0, -0.06, 0.00), mat)    # forend / pump
	_gun_part(root, Vector3(0.07, 0.05, 0.20), off + Vector3(0, 0.06, -0.20), mat)    # barrel
	return root

func pause_state_broadcast(seconds: float) -> void:
	# Called by game.gd when a new peer joins, so we don't fire _remote_state
	# RPCs at a path the new peer hasn't created yet.
	sync_timer = maxf(sync_timer, seconds)

func get_weapon_info() -> Dictionary:
	var w: Dictionary = WEAPONS[current_weapon]
	return {
		"index": current_weapon,
		"name": str(w["name"]),
		"ammo": weapon_ammo[current_weapon],
		"max_ammo": int(w["max_ammo"]),
	}

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _is_bot:
		_bot_tick(delta)
	else:
		_human_tick(delta)
	move_and_slide()
	_play_anim(_select_anim())
	sync_timer -= delta
	if sync_timer <= 0.0:
		sync_timer = SYNC_INTERVAL
		# Don't broadcast position from a node that's been queue_free'd this frame.
		if is_inside_tree() and not is_queued_for_deletion():
			_remote_state.rpc(global_position, rotation.y, camera.rotation.x, _current_anim)

func _human_tick(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	if direction.length() > 0.01:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	# Tick down the recapture-grace timer. While it's > 0 the shoot action
	# is ignored, so the click that just refocused the canvas doesn't also
	# fire a bullet.
	if _recapture_shot_suppress > 0.0:
		_recapture_shot_suppress = maxf(0.0, _recapture_shot_suppress - delta)
	elif Input.is_action_pressed("shoot"):
		_try_shoot()
	if Input.is_action_just_pressed("reload"):
		_reload()

# ─── Bot AI ──────────────────────────────────────────────────────────

func _bot_tick(delta: float) -> void:
	if health <= 0:
		# Dead bot — server will respawn it; freeze for now.
		velocity.x = 0
		velocity.z = 0
		return
	_bot_state_time += delta
	_bot_fire_cooldown = max(0.0, _bot_fire_cooldown - delta)
	# Auto-reload if dry.
	if weapon_ammo[current_weapon] <= 0 and not is_reloading:
		_reload()
	var nearest := _bot_find_nearest_human()
	if _bot_state == BotState.WANDER:
		if nearest != null and global_position.distance_to(nearest.global_position) < BOT_VIEW_RANGE:
			_bot_state = BotState.ENGAGE
			_bot_target = nearest
			_bot_state_time = 0.0
		else:
			_bot_wander(delta)
	else:  # ENGAGE
		# Drop target on: gone / dead / now-invincible (spawn-protected) /
		# out of leash range. Server-authoritative state takes priority over
		# the local node's stale health field.
		var t_pid: int = int(_bot_target.player_peer_id) if is_instance_valid(_bot_target) and "player_peer_id" in _bot_target else 0
		var t_info: Dictionary = NetworkManager.players.get(t_pid, {})
		var lost := (
			not is_instance_valid(_bot_target)
			or int(t_info.get("health", 100)) <= 0
			or bool(t_info.get("invincible", false))
			or global_position.distance_to(_bot_target.global_position) > BOT_LOSE_RANGE)
		if lost:
			_bot_state = BotState.WANDER
			_bot_target = null
			_bot_state_time = 0.0
			_bot_wander(delta)
		else:
			_bot_engage(delta)

func _bot_find_nearest_human() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for c in get_tree().get_nodes_in_group("player"):
		if c == self:
			continue
		if c._is_bot:
			continue
		# Use the server-authoritative dict, not node.health which goes
		# stale on the server for remote clients. Skip dead or invincible
		# (newly respawned) targets so the player gets a real spawn-protection
		# window instead of bots converging the instant invincibility starts.
		var pid: int = int(c.player_peer_id) if "player_peer_id" in c else 0
		var info: Dictionary = NetworkManager.players.get(pid, {})
		if int(info.get("health", 100)) <= 0:
			continue
		if bool(info.get("invincible", false)):
			continue
		var d: float = global_position.distance_to(c.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = c
	return nearest

func _bot_wander(_delta: float) -> void:
	if _bot_state_time > 4.0 or global_position.distance_to(_bot_wander_target) < 1.5:
		_bot_wander_target = Vector3(
			randf_range(-BOT_WANDER_BOUND, BOT_WANDER_BOUND), 0,
			randf_range(-BOT_WANDER_BOUND, BOT_WANDER_BOUND))
		_bot_state_time = 0.0
	var to_target: Vector3 = _bot_wander_target - global_position
	to_target.y = 0
	if to_target.length() > 0.5:
		var dir: Vector3 = to_target.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		rotation.y = atan2(-dir.x, -dir.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	camera.rotation.x = 0.0  # level head while wandering

func _bot_engage(_delta: float) -> void:
	if _bot_target == null:
		return
	var to_t: Vector3 = _bot_target.global_position - global_position
	var dist: float = to_t.length()
	var dir: Vector3 = to_t.normalized()
	# Face target.
	rotation.y = atan2(-dir.x, -dir.z)
	# Pitch camera toward target's head.
	var horiz: float = Vector2(to_t.x, to_t.z).length()
	var dy: float = (_bot_target.global_position.y + 1.5) - (global_position.y + 1.6)
	camera.rotation.x = clamp(atan2(dy, max(horiz, 0.01)), -1.25, 1.25)
	# Kite around BOT_ENGAGE_IDEAL distance.
	if dist > BOT_ENGAGE_IDEAL + 3.0:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
	elif dist < BOT_ENGAGE_IDEAL - 3.0:
		velocity.x = -dir.x * SPEED
		velocity.z = -dir.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	# Fire if line of sight + cooldown elapsed.
	if _bot_fire_cooldown <= 0.0 and not is_reloading and weapon_ammo[current_weapon] > 0:
		_bot_fire_cooldown = BOT_FIRE_INTERVAL
		ray.target_position = Vector3(0, 0, -100)
		ray.force_raycast_update()
		if ray.is_colliding():
			var found := _find_player_root(ray.get_collider() as Node)
			if found == _bot_target:
				_try_shoot()

@rpc("authority", "unreliable_ordered", "call_remote")
func _remote_state(pos: Vector3, rot_y: float, cam_x: float, anim_name: String) -> void:
	global_position = pos
	rotation.y = rot_y
	camera.rotation.x = cam_x
	_play_anim(anim_name)

# ─── Shooting ────────────────────────────────────────────────────────

func _try_shoot() -> void:
	if not can_shoot or is_reloading:
		return
	var w: Dictionary = WEAPONS[current_weapon]
	if weapon_ammo[current_weapon] <= 0:
		_reload()
		return
	can_shoot = false
	weapon_ammo[current_weapon] -= 1
	local_ammo_changed.emit(weapon_ammo[current_weapon])

	var pellets: int = int(w.get("pellets", 1))
	var spread: float = float(w.get("spread", 0.0))
	var fire_rate: float = float(w.get("fire_rate", 0.12))

	var start_pos: Vector3 = muzzle.global_position
	var ends: Array = []
	var hit_flags: Array = []
	var any_hit_player := false
	var orig_target: Vector3 = ray.target_position

	for i in pellets:
		# First pellet uses the natural aim; subsequent pellets get random
		# spread. Pistol's spread is 0 anyway so it always hits dead center.
		if spread > 0.0 and i > 0:
			var dx: float = randf_range(-spread, spread)
			var dy: float = randf_range(-spread, spread)
			ray.target_position = Vector3(dx, dy, -1).normalized() * 100.0
		else:
			ray.target_position = orig_target
		ray.force_raycast_update()
		var end_pos: Vector3
		var hit_normal := Vector3.UP
		var hit_player := false
		if ray.is_colliding():
			end_pos = ray.get_collision_point()
			hit_normal = ray.get_collision_normal()
			var victim := _find_player_root(ray.get_collider() as Node)
			if victim and victim != self:
				hit_player = true
				any_hit_player = true
				var victim_pid: int = victim.player_peer_id
				if victim_pid == 0:
					# Fallback for any pre-bot codepath that didn't seed player_peer_id.
					victim_pid = victim.get_multiplayer_authority()
				var is_headshot: bool = (end_pos.y - victim.global_position.y) > 1.4
				_report_hit(victim_pid, current_weapon, is_headshot, end_pos)
		else:
			end_pos = camera.global_position + (-camera.global_transform.basis.z) * 80.0
		ends.append(end_pos)
		hit_flags.append(hit_player)
		if ray.is_colliding() and not hit_player:
			_spawn_impact(end_pos, hit_normal)

	ray.target_position = orig_target
	_fire_fx.rpc(start_pos, ends, hit_flags)
	if any_hit_player and not _is_bot:
		local_hit_marker.emit()
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

func _report_hit(victim_pid: int, weapon_idx: int, is_headshot: bool, hit_pos: Vector3) -> void:
	# Bots are server-controlled, so they route hits through the server-side
	# function directly with their *bot* peer_id. Humans go through the RPC
	# (sender id resolves them on the server).
	if _is_bot:
		if _game and _game.has_method("_process_hit"):
			_game._process_hit(player_peer_id, victim_pid, weapon_idx, is_headshot, hit_pos)
	else:
		_game.server_report_hit.rpc_id(
			NetworkManager.HOST_PEER_ID,
			victim_pid, weapon_idx, is_headshot, hit_pos)

@rpc("any_peer", "unreliable", "call_local")
func _fire_fx(start: Vector3, ends: Array, hit_flags: Array) -> void:
	# Single sound + single muzzle flash regardless of pellet count, but one
	# tracer per pellet so a shotgun blast reads as a spread of beams.
	audio_3d.stream = SFX_SHOOT
	audio_3d.play()
	_flash_muzzle()
	for i in ends.size():
		var hit: bool = bool(hit_flags[i]) if i < hit_flags.size() else false
		_spawn_tracer(start, ends[i], hit)

func _flash_muzzle() -> void:
	if not is_instance_valid(muzzle):
		return
	var mat: StandardMaterial3D = muzzle.material_override as StandardMaterial3D
	if mat == null:
		return
	muzzle.visible = true
	mat.emission_energy_multiplier = 9.0
	mat.albedo_color.a = 0.9
	var tw := muzzle.create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.15)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tw.tween_callback(func():
		if is_instance_valid(muzzle):
			muzzle.visible = false)

func _spawn_tracer(start: Vector3, end: Vector3, hit_player: bool) -> void:
	# An actual flying bullet head + a fading streak behind it. Damage was
	# already resolved at fire time by raycast; this is purely cinematic.
	#
	# Flight time scales with distance so close shots feel snappy and long
	# shots have a sniper-rifle "see it travel" moment, but never so slow
	# that gameplay timing feels off.
	var dist := start.distance_to(end)
	if dist < 0.5:
		return
	var color := Color(1, 0.4, 0.4) if hit_player else Color(1, 0.95, 0.5)
	# Cap at ~250 ms even at max range (80 m).
	var flight_time: float = clamp(0.05 + dist * 0.0025, 0.05, 0.25)

	# Bullet head: glowing sphere that flies from muzzle to impact.
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.08
	head_mesh.height = 0.16
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	head.mesh = head_mesh
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = color
	head_mat.emission_enabled = true
	head_mat.emission = color
	head_mat.emission_energy_multiplier = 6.5
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.material_override = head_mat
	get_tree().current_scene.add_child(head)
	head.global_position = start
	var ht := head.create_tween()
	ht.tween_property(head, "global_position", end, flight_time)
	ht.tween_callback(head.queue_free)

	# Streak: thin box rendered as a momentary trail from start to end. Fades
	# faster than the head's flight so the trail is visible only briefly
	# behind the bullet, not all-at-once like the v6.x static tracer.
	var trail := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.04, dist)
	trail.mesh = bm
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var trail_mat := StandardMaterial3D.new()
	trail_mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	trail_mat.emission_enabled = true
	trail_mat.emission = color
	trail_mat.emission_energy_multiplier = 3.0
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.material_override = trail_mat
	get_tree().current_scene.add_child(trail)
	trail.global_position = (start + end) * 0.5
	trail.look_at(end, Vector3.UP, true)
	var tt := trail.create_tween()
	tt.tween_property(trail_mat, "albedo_color:a", 0.0, flight_time * 0.8)
	tt.parallel().tween_property(trail_mat, "emission_energy_multiplier", 0.0, flight_time * 0.8)
	tt.tween_callback(trail.queue_free)

func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var impact := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	impact.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	impact.material_override = mat
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos + normal * 0.04
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(impact):
		impact.queue_free()

func _reload() -> void:
	if is_reloading:
		return
	var w: Dictionary = WEAPONS[current_weapon]
	var max_a: int = int(w["max_ammo"])
	if weapon_ammo[current_weapon] >= max_a:
		return
	is_reloading = true
	await get_tree().create_timer(float(w["reload_time"])).timeout
	# Player may have switched weapons mid-reload; only refill what they
	# were actually reloading.
	weapon_ammo[current_weapon] = int(WEAPONS[current_weapon]["max_ammo"])
	is_reloading = false
	local_ammo_changed.emit(weapon_ammo[current_weapon])

# ─── Damage / Death / Respawn ────────────────────────────────────────

@rpc("any_peer", "reliable", "call_local")
func take_damage_remote(new_health: int, amount: int, _attacker_peer_id: int) -> void:
	# Display-only: server has already applied the damage and will trigger the
	# death sequence itself. We only accept this RPC when it originates from
	# the server (sender == HOST_PEER_ID for remote, sender == 0 for the host's
	# own call_local invocation).
	# Authority check FIRST — never mutate state on a non-authority node, even
	# if the sender claims to be the server.
	if not is_multiplayer_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		if not NetworkManager.is_server():
			return
	elif sender != NetworkManager.HOST_PEER_ID:
		return
	health = new_health
	local_health_changed.emit(health)
	local_damage_taken.emit(amount)
	_play_hit_sfx.rpc()
	if health <= 0:
		_show_death.rpc()
		local_died.emit()

@rpc("any_peer", "reliable", "call_local")
func notify_health_restored(new_health: int) -> void:
	# Server pushes a heal (e.g. health pickup). Same sender-check pattern as
	# take_damage_remote — only the host may legitimately move our HP up.
	if not is_multiplayer_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		if not NetworkManager.is_server():
			return
	elif sender != NetworkManager.HOST_PEER_ID:
		return
	health = new_health
	local_health_changed.emit(health)
	audio_2d.stream = SFX_RESPAWN
	audio_2d.play()

@rpc("any_peer", "reliable", "call_local")
func notify_ammo_restored() -> void:
	if not is_multiplayer_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		if not NetworkManager.is_server():
			return
	elif sender != NetworkManager.HOST_PEER_ID:
		return
	# Refill ALL weapons — a single ammo crate is generous since the player
	# might be empty on multiple guns.
	for i in WEAPONS.size():
		weapon_ammo[i] = int(WEAPONS[i]["max_ammo"])
	local_ammo_changed.emit(weapon_ammo[current_weapon])
	audio_2d.stream = SFX_RESPAWN
	audio_2d.play()

@rpc("any_peer", "unreliable", "call_local")
func _play_hit_sfx() -> void:
	audio_3d.stream = SFX_HIT
	audio_3d.play()

@rpc("any_peer", "reliable", "call_local")
func _show_death() -> void:
	# Hide body for everyone (1st-person already hides for self).
	if is_instance_valid(model_holder):
		model_holder.visible = false
	if is_instance_valid(name_label):
		name_label.visible = false
	# Play death sound to everyone via 3D audio at this spot.
	audio_3d.stream = SFX_DEATH
	audio_3d.play()

func respawn_at(pos: Vector3) -> void:
	if not is_multiplayer_authority():
		return
	health = MAX_HEALTH
	for i in WEAPONS.size():
		weapon_ammo[i] = int(WEAPONS[i]["max_ammo"])
	velocity = Vector3.ZERO
	global_position = pos
	local_health_changed.emit(health)
	local_ammo_changed.emit(weapon_ammo[current_weapon])
	local_respawned.emit()
	# Local-only respawn chime.
	audio_2d.stream = SFX_RESPAWN
	audio_2d.play()
	_show_respawn.rpc()
	_run_invincibility()

@rpc("authority", "reliable", "call_local")
func _show_respawn() -> void:
	# Only the LOCAL HUMAN player keeps their own model hidden (first-person
	# view). Bots are server-controlled but rendered third-person to every
	# viewer — including the host that owns them — so the previous
	# `if not is_multiplayer_authority()` guard accidentally kept the bot's
	# model hidden on the host's screen after respawn.
	if is_multiplayer_authority() and not _is_bot:
		return
	model_holder.visible = true
	name_label.visible = true

func _run_invincibility() -> void:
	is_invincible = true
	var elapsed := 0.0
	while elapsed < RESPAWN_INVINCIBILITY:
		_blink_visibility.rpc(int(elapsed * 8) % 2 == 0)
		await get_tree().create_timer(0.12).timeout
		elapsed += 0.12
		if not is_instance_valid(self):
			return
	_blink_visibility.rpc(true)
	is_invincible = false

@rpc("authority", "unreliable", "call_local")
func _blink_visibility(visible_on: bool) -> void:
	# Same first-person-keep-hidden rule as _show_respawn. Bots on the host
	# still need their model toggled or they stay invisible the whole
	# invincibility window.
	if is_multiplayer_authority() and not _is_bot:
		return
	model_holder.visible = visible_on
