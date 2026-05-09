extends CharacterBody3D

signal local_health_changed(new_health: int)
signal local_ammo_changed(new_ammo: int)
signal local_damage_taken(amount: int)
signal local_died()
signal local_respawned()
signal local_hit_marker()

const SPEED            := 6.0
const SPRINT_SPEED     := 10.0
const JUMP_VELOCITY    := 8.5
const GRAVITY          := 24.0
const MOUSE_SENSITIVITY := 0.0022
const TOUCH_LOOK_SENSITIVITY := 0.005
const MAX_HEALTH       := 100
const MAX_AMMO         := 30
const RELOAD_TIME      := 1.4
const FIRE_RATE        := 0.12
# Bullet damage lives on the server (game.gd::SERVER_BULLET_DAMAGE) — clients
# don't get to choose how hard they hit.
const SYNC_INTERVAL    := 0.05
const RESPAWN_INVINCIBILITY := 1.5

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
var ammo: int = MAX_AMMO
var can_shoot: bool = true
var is_reloading: bool = false
var is_invincible: bool = false
var sync_timer: float = 0.0
var _game: Node = null
var _current_skin: int = -1
var _anim_player: AnimationPlayer = null
var _current_anim: String = ""

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
	if is_multiplayer_authority():
		add_to_group("local_player")
		model_holder.visible = false
		name_label.visible = false
		camera.current = true
		_grab_mouse()
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

func _play_anim(name: String) -> void:
	if _anim_player == null or name == _current_anim:
		return
	if not _anim_player.has_animation(name):
		return
	_current_anim = name
	# Cross-fade between movement anims so idle↔walk↔sprint doesn't pop.
	# 'die' wants no blend so the snap reads clearly.
	var blend := 0.0 if name == ANIM_DIE else 0.12
	_anim_player.play(name, blend)

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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
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

	move_and_slide()

	_play_anim(_select_anim())

	if Input.is_action_pressed("shoot"):
		_try_shoot()
	if Input.is_action_just_pressed("reload"):
		_reload()

	sync_timer -= delta
	if sync_timer <= 0.0:
		sync_timer = SYNC_INTERVAL
		# Don't broadcast position from a node that's been queue_free'd this frame.
		if is_inside_tree() and not is_queued_for_deletion():
			_remote_state.rpc(global_position, rotation.y, camera.rotation.x, _current_anim)

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
	if ammo <= 0:
		_reload()
		return
	can_shoot = false
	ammo -= 1
	local_ammo_changed.emit(ammo)
	ray.force_raycast_update()
	var start_pos: Vector3 = muzzle.global_position
	var end_pos: Vector3
	var hit_normal := Vector3.UP
	var hit_player := false
	if ray.is_colliding():
		end_pos = ray.get_collision_point()
		hit_normal = ray.get_collision_normal()
		var victim := _find_player_root(ray.get_collider() as Node)
		if victim and victim != self:
			hit_player = true
			var victim_peer_id: int = victim.get_multiplayer_authority()
			# Headshot if the impact landed in the upper third of the capsule
			# (capsule center y = 0.85, total height 1.7, so y > origin + 1.4 ≈ head).
			# Server still validates this claim before granting the bonus damage.
			var is_headshot: bool = (end_pos.y - victim.global_position.y) > 1.4
			_game.server_report_hit.rpc_id(
				NetworkManager.HOST_PEER_ID, victim_peer_id, is_headshot, end_pos)
	else:
		end_pos = camera.global_position + (-camera.global_transform.basis.z) * 80.0
	_fire_fx.rpc(start_pos, end_pos, hit_player)
	if ray.is_colliding() and not hit_player:
		_spawn_impact(end_pos, hit_normal)
	if hit_player:
		local_hit_marker.emit()
	await get_tree().create_timer(FIRE_RATE).timeout
	can_shoot = true

@rpc("any_peer", "unreliable", "call_local")
func _fire_fx(start: Vector3, end: Vector3, hit_player: bool) -> void:
	audio_3d.stream = SFX_SHOOT
	audio_3d.play()
	_spawn_tracer(start, end, hit_player)
	_flash_muzzle()

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
	var dist := start.distance_to(end)
	if dist < 0.5:
		return
	var tracer := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, dist)
	tracer.mesh = bm
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	var color := Color(1, 0.4, 0.4) if hit_player else Color(1, 0.95, 0.5)
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.material_override = mat
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (start + end) * 0.5
	tracer.look_at(end, Vector3.UP, true)
	var tw := tracer.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)
	tw.tween_callback(tracer.queue_free)

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
	if is_reloading or ammo == MAX_AMMO:
		return
	is_reloading = true
	await get_tree().create_timer(RELOAD_TIME).timeout
	ammo = MAX_AMMO
	is_reloading = false
	local_ammo_changed.emit(ammo)

# ─── Damage / Death / Respawn ────────────────────────────────────────

@rpc("any_peer", "reliable", "call_local")
func take_damage_remote(new_health: int, amount: int, attacker_peer_id: int) -> void:
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
	ammo = MAX_AMMO
	local_ammo_changed.emit(ammo)
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
	ammo = MAX_AMMO
	velocity = Vector3.ZERO
	global_position = pos
	local_health_changed.emit(health)
	local_ammo_changed.emit(ammo)
	local_respawned.emit()
	# Local-only respawn chime.
	audio_2d.stream = SFX_RESPAWN
	audio_2d.play()
	_show_respawn.rpc()
	_run_invincibility()

@rpc("authority", "reliable", "call_local")
func _show_respawn() -> void:
	if not is_multiplayer_authority():
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
	if is_multiplayer_authority():
		return
	model_holder.visible = visible_on
