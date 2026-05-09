extends Area3D
# Jump pad: walking onto it sets the entering player's velocity.y to a fixed
# upward boost. No server round-trip — each client mutates only the player it
# has authority over, position then syncs via the existing _remote_state RPC.

const JUMP_BOOST := 16.0  # ~5.3m max apex (vs. 1.5m normal jump)

@export var visual_color: Color = Color(0.20, 0.85, 1.0)

func _ready() -> void:
	if get_node_or_null("Visual") == null:
		_build_default_visual()
	if get_node_or_null("CollisionShape3D") == null:
		_build_default_collision()
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	# Subtle pulse so it reads as interactable, not static geometry.
	var v := get_node_or_null("Visual") as MeshInstance3D
	if v:
		var mat := v.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 2.0 + sin(Time.get_ticks_msec() * 0.005) * 0.6

func _build_default_visual() -> void:
	var vis := CSGCylinder3D.new()
	vis.name = "Visual"
	vis.height = 0.25
	vis.radius = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = visual_color
	mat.emission_enabled = true
	mat.emission = visual_color
	mat.emission_energy_multiplier = 2.0
	vis.material_override = mat
	add_child(vis)

func _build_default_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var s := CylinderShape3D.new()
	s.height = 0.5
	s.radius = 0.9
	col.shape = s
	add_child(col)

func _on_body_entered(body: Node) -> void:
	# Only the machine that owns the player applies the boost — other
	# clients receive the new velocity via _remote_state syncing.
	if not (body is CharacterBody3D):
		return
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return
	body.velocity.y = JUMP_BOOST
