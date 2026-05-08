extends CharacterBody3D

signal local_health_changed(new_health: int)
signal local_ammo_changed(new_ammo: int)
signal local_damage_taken(amount: int)
signal local_died()
signal local_respawned()

const SPEED            := 6.0
const SPRINT_SPEED     := 10.0
const JUMP_VELOCITY    := 7.0
const GRAVITY          := 22.0
const MOUSE_SENSITIVITY := 0.0022
const TOUCH_LOOK_SENSITIVITY := 0.005
const MAX_HEALTH       := 100
const MAX_AMMO         := 30
const RELOAD_TIME      := 1.4
const FIRE_RATE        := 0.12
const BULLET_DAMAGE    := 25
const SYNC_INTERVAL    := 0.05
const RESPAWN_INVINCIBILITY := 1.5
const DEATH_HIDE_TIME  := 0.4

var health: int = MAX_HEALTH
var ammo: int = MAX_AMMO
var can_shoot: bool = true
var is_reloading: bool = false
var is_invincible: bool = false
var sync_timer: float = 0.0
var _game: Node = null

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var muzzle: MeshInstance3D = $Camera3D/MuzzleFlash
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var head_mesh: MeshInstance3D = $HeadMesh
@onready var name_label: Label3D = $NameLabel

func _ready() -> void:
	add_to_group("player")
	muzzle.visible = false
	ray.add_exception(self)
	call_deferred("_setup_authority_visuals")

func _setup_authority_visuals() -> void:
	_game = get_tree().get_first_node_in_group("game")
	if is_multiplayer_authority():
		add_to_group("local_player")
		body_mesh.visible = false
		head_mesh.visible = false
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
	# Don't fight the touch UI for mouse mode on mobile.
	if DisplayServer.is_touchscreen_available():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_grab_mouse()

func _grab_mouse() -> void:
	if DisplayServer.is_touchscreen_available():
		return  # Touch devices don't capture mouse.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func apply_identity(player_name: String, color: Color) -> void:
	name_label.text = player_name
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.2
	mat.roughness = 0.5
	body_mesh.material_override = mat
	head_mesh.material_override = mat

# Used by touch_controls.gd on mobile/web.
func apply_touch_look(delta_vec: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	rotate_y(-delta_vec.x)
	camera.rotate_x(-delta_vec.y)
	camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)
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

	if Input.is_action_pressed("shoot"):
		_try_shoot()
	if Input.is_action_just_pressed("reload"):
		_reload()

	sync_timer -= delta
	if sync_timer <= 0.0:
		sync_timer = SYNC_INTERVAL
		_remote_state.rpc(global_position, rotation.y, camera.rotation.x)

@rpc("authority", "unreliable_ordered", "call_remote")
func _remote_state(pos: Vector3, rot_y: float, cam_x: float) -> void:
	global_position = pos
	rotation.y = rot_y
	camera.rotation.x = cam_x

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
	_flash_muzzle.rpc()
	ray.force_raycast_update()
	if ray.is_colliding():
		var target: Object = ray.get_collider()
		if target and target is CharacterBody3D and target != self and target.is_in_group("player"):
			var victim_peer_id: int = target.get_multiplayer_authority()
			_game.server_report_hit.rpc_id(NetworkManager.HOST_PEER_ID, victim_peer_id, BULLET_DAMAGE)
		_spawn_impact(ray.get_collision_point(), ray.get_collision_normal())
	await get_tree().create_timer(FIRE_RATE).timeout
	can_shoot = true

@rpc("any_peer", "unreliable", "call_local")
func _flash_muzzle() -> void:
	muzzle.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle):
		muzzle.visible = false

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
func take_damage_remote(amount: int, attacker_peer_id: int) -> void:
	if not is_multiplayer_authority() or health <= 0 or is_invincible:
		return
	health -= amount
	local_health_changed.emit(health)
	local_damage_taken.emit(amount)
	_flash_hit.rpc()
	if health <= 0:
		_show_death.rpc()
		local_died.emit()
		_game.server_report_death.rpc_id(NetworkManager.HOST_PEER_ID, attacker_peer_id)

# Visible to ALL peers — body briefly flashes white when hit.
@rpc("any_peer", "unreliable", "call_local")
func _flash_hit() -> void:
	var mat := body_mesh.material_override
	if not (mat is StandardMaterial3D):
		return
	var smat: StandardMaterial3D = mat
	var orig: Color = smat.albedo_color
	smat.albedo_color = Color(1.5, 1.5, 1.5)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self) and is_instance_valid(body_mesh) and body_mesh.material_override == smat:
		smat.albedo_color = orig

@rpc("any_peer", "reliable", "call_local")
func _show_death() -> void:
	body_mesh.visible = false
	head_mesh.visible = false
	name_label.visible = false

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
	_show_respawn.rpc()
	_run_invincibility()

@rpc("authority", "reliable", "call_local")
func _show_respawn() -> void:
	# Local player keeps body hidden (1st person); others get to see it again.
	if not is_multiplayer_authority():
		body_mesh.visible = true
		head_mesh.visible = true
	name_label.visible = not is_multiplayer_authority()

func _run_invincibility() -> void:
	is_invincible = true
	var elapsed := 0.0
	# Blink cycle for non-local viewers — local player can't see their own body.
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
		return  # Local player's body always hidden anyway.
	body_mesh.visible = visible_on
	head_mesh.visible = visible_on
