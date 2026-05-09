extends Area3D
# Jump pad: walking onto it sets the entering player's velocity.y to a fixed
# upward boost. No server round-trip — each client mutates only the player it
# has authority over, position then syncs via the existing _remote_state RPC.

const JUMP_BOOST := 16.0  # ~5.3m max apex (vs. 1.5m normal jump)

@export var visual_color: Color = Color(0.20, 0.85, 1.0)

var _accent_mat: StandardMaterial3D
var _arrow: CSGCylinder3D

func _ready() -> void:
	if get_node_or_null("Visual") == null:
		_build_default_visual()
	if get_node_or_null("CollisionShape3D") == null:
		_build_default_collision()
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	# Pulse the inner glow + bob the upward chevron so it reads as an
	# interactable launchpad, not static geometry.
	var t := Time.get_ticks_msec() * 0.001
	if _accent_mat:
		_accent_mat.emission_energy_multiplier = 2.4 + sin(t * 5.0) * 0.8
	if _arrow:
		_arrow.position.y = 0.42 + 0.08 * sin(t * 3.5)

func _build_default_visual() -> void:
	var holder := Node3D.new()
	holder.name = "Visual"
	add_child(holder)

	# Dark base ring — the "machine" the pad sits on. Low-emission, matte.
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.10, 0.13, 0.22)
	base_mat.metallic = 0.55
	base_mat.roughness = 0.45
	base_mat.emission_enabled = true
	base_mat.emission = visual_color
	base_mat.emission_energy_multiplier = 0.20
	var base := CSGCylinder3D.new()
	base.height = 0.16
	base.radius = 1.0
	base.material_override = base_mat
	holder.add_child(base)

	# Bright inner disc — this is what pulses, sells the "active" feel.
	_accent_mat = StandardMaterial3D.new()
	_accent_mat.albedo_color = visual_color
	_accent_mat.emission_enabled = true
	_accent_mat.emission = visual_color
	_accent_mat.emission_energy_multiplier = 2.4
	_accent_mat.metallic = 0.0
	_accent_mat.roughness = 0.30
	var inner := CSGCylinder3D.new()
	inner.height = 0.06
	inner.radius = 0.72
	inner.position = Vector3(0, 0.10, 0)
	inner.material_override = _accent_mat
	holder.add_child(inner)

	# Upward cone chevron — visually says "jump up" without using a label.
	_arrow = CSGCylinder3D.new()
	_arrow.cone = true
	_arrow.height = 0.50
	_arrow.radius = 0.22
	_arrow.position = Vector3(0, 0.42, 0)
	_arrow.material_override = _accent_mat
	holder.add_child(_arrow)

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
