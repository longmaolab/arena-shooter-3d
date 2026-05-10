extends Area3D
# Server-authoritative pickup. Walking over it triggers a heal or ammo
# refill on the picker's client, and the pickup hides for `respawn_time`
# seconds before becoming available again.

@export_enum("health", "ammo") var pickup_type: String = "health"
@export var heal_amount: int = 50
@export var respawn_time: float = 30.0

const HEALTH_CORE := Color(0.96, 0.96, 0.96)
const HEALTH_CROSS := Color(0.96, 0.22, 0.32)
const AMMO_CRATE := Color(0.45, 0.32, 0.18)
const AMMO_LID := Color(1.00, 0.78, 0.26)

var _shared_emissive_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	if get_node_or_null("Visual") == null:
		_build_default_visual()
	if get_node_or_null("CollisionShape3D") == null:
		_build_default_collision()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Slow rotation + bob so the pickup reads as a usable item.
	rotate_y(delta * 1.4)
	var v := get_node_or_null("Visual") as Node3D
	if v:
		v.position.y = 0.15 * sin(Time.get_ticks_msec() * 0.004)
	# Subtle emission pulse on accent materials so it draws the eye.
	var pulse := 1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.003)
	for mat in _shared_emissive_mats:
		mat.emission_energy_multiplier = pulse * 1.6

func _build_default_visual() -> void:
	var holder := Node3D.new()
	holder.name = "Visual"
	add_child(holder)
	if pickup_type == "health":
		_build_health_visual(holder)
	else:
		_build_ammo_visual(holder)

func _build_health_visual(holder: Node3D) -> void:
	# White core box with a 3D red cross sticking through it on three axes —
	# reads as a medkit from any angle (no billboard text).
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = HEALTH_CORE
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.85, 0.95, 0.90)
	core_mat.emission_energy_multiplier = 0.5
	core_mat.metallic = 0.1
	core_mat.roughness = 0.4

	var core := CSGBox3D.new()
	core.size = Vector3(0.55, 0.55, 0.55)
	core.material_override = core_mat
	holder.add_child(core)

	var cross_mat := StandardMaterial3D.new()
	cross_mat.albedo_color = HEALTH_CROSS
	cross_mat.emission_enabled = true
	cross_mat.emission = Color(1, 0.30, 0.40)
	cross_mat.emission_energy_multiplier = 1.6
	cross_mat.metallic = 0.0
	cross_mat.roughness = 0.35
	_shared_emissive_mats.append(cross_mat)

	var bar_x := CSGBox3D.new()
	bar_x.size = Vector3(0.78, 0.20, 0.20)
	bar_x.material_override = cross_mat
	holder.add_child(bar_x)

	var bar_y := CSGBox3D.new()
	bar_y.size = Vector3(0.20, 0.78, 0.20)
	bar_y.material_override = cross_mat
	holder.add_child(bar_y)

	var bar_z := CSGBox3D.new()
	bar_z.size = Vector3(0.20, 0.20, 0.78)
	bar_z.material_override = cross_mat
	holder.add_child(bar_z)

func _build_ammo_visual(holder: Node3D) -> void:
	# Amber ammo crate with a glowing lid band — reads as ammo without any
	# billboard glyph, scales gracefully when the pickup rotates.
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = AMMO_CRATE
	crate_mat.emission_enabled = true
	crate_mat.emission = Color(1, 0.72, 0.20)
	crate_mat.emission_energy_multiplier = 0.35
	crate_mat.metallic = 0.35
	crate_mat.roughness = 0.55

	var crate := CSGBox3D.new()
	crate.size = Vector3(0.72, 0.40, 0.52)
	crate.material_override = crate_mat
	holder.add_child(crate)

	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = AMMO_LID
	lid_mat.emission_enabled = true
	lid_mat.emission = AMMO_LID
	lid_mat.emission_energy_multiplier = 1.4
	lid_mat.metallic = 0.55
	lid_mat.roughness = 0.30
	_shared_emissive_mats.append(lid_mat)

	var lid := CSGBox3D.new()
	lid.size = Vector3(0.78, 0.06, 0.56)
	lid.position = Vector3(0, 0.21, 0)
	lid.material_override = lid_mat
	holder.add_child(lid)

	# Center spine on the top — splits the lid into two clean panels so it
	# reads as a real crate instead of a flat box.
	var spine := CSGBox3D.new()
	spine.size = Vector3(0.06, 0.08, 0.56)
	spine.position = Vector3(0, 0.22, 0)
	spine.material_override = crate_mat
	holder.add_child(spine)

func _build_default_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var s := BoxShape3D.new()
	s.size = Vector3(1.4, 1.4, 1.4)
	col.shape = s
	add_child(col)

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if not (body is CharacterBody3D):
		return
	if not body.is_in_group("player"):
		return
	# Stat lookup uses player_peer_id (the attribution tag), but RPC routing
	# uses multiplayer authority — for bots these differ (bot.authority = 1
	# = host, bot.player_peer_id = -1/-2/-3).
	var stat_pid: int = body.player_peer_id if body.player_peer_id != 0 else body.get_multiplayer_authority()
	var rpc_pid: int = body.get_multiplayer_authority()
	if not NetworkManager.players.has(stat_pid):
		return
	var info: Dictionary = NetworkManager.players[stat_pid]
	var consumed := false
	if pickup_type == "health":
		var cur: int = int(info.get("health", 100))
		if cur >= 100:
			return
		var new_h: int = mini(100, cur + heal_amount)
		info["health"] = new_h
		body.notify_health_restored.rpc_id(rpc_pid, new_h)
		consumed = true
	elif pickup_type == "ammo":
		body.notify_ammo_restored.rpc_id(rpc_pid)
		consumed = true
	if consumed:
		_disable_for_respawn()

func _disable_for_respawn() -> void:
	set_pickup_visible.rpc(false)
	await get_tree().create_timer(respawn_time).timeout
	if is_inside_tree():
		set_pickup_visible.rpc(true)

@rpc("authority", "reliable", "call_local")
func set_pickup_visible(v: bool) -> void:
	# `monitoring` and CollisionShape3D.disabled can't be mutated synchronously
	# while the physics server is flushing area queries (which is exactly when
	# our body_entered signal fires). Defer the change to the end of the frame.
	visible = v
	set_deferred("monitoring", v)
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", not v)
