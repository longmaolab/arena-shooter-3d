extends Area3D
# Server-authoritative pickup. Walking over it triggers a heal or ammo
# refill on the picker's client, and the pickup hides for `respawn_time`
# seconds before becoming available again.

@export_enum("health", "ammo") var pickup_type: String = "health"
@export var heal_amount: int = 50
@export var respawn_time: float = 30.0

const COLOR_HEALTH := Color(0.30, 0.95, 0.50)
const COLOR_AMMO   := Color(1.00, 0.72, 0.20)

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

func _build_default_visual() -> void:
	var color: Color = COLOR_HEALTH if pickup_type == "health" else COLOR_AMMO
	var holder := Node3D.new()
	holder.name = "Visual"
	add_child(holder)
	var vis := CSGBox3D.new()
	vis.size = Vector3(0.7, 0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	vis.material_override = mat
	holder.add_child(vis)
	# Cross / plus glyph on top so it reads as health vs. ammo.
	var glyph := Label3D.new()
	glyph.text = "+" if pickup_type == "health" else "•"
	glyph.font_size = 80
	glyph.outline_size = 6
	glyph.modulate = Color.WHITE
	glyph.outline_modulate = Color.BLACK
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.no_depth_test = true
	glyph.fixed_size = true
	glyph.pixel_size = 0.005
	glyph.position = Vector3(0, 0.55, 0)
	holder.add_child(glyph)

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
	visible = v
	monitoring = v
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = not v
