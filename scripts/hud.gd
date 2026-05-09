extends CanvasLayer

@onready var hp_label: Label = $BottomLeft/VBox/HealthCard/HealthInner/HealthRow/HealthLabel
@onready var hp_bar: ProgressBar = $BottomLeft/VBox/HealthCard/HealthInner/HealthBar
@onready var ammo_label: Label = $BottomLeft/VBox/AmmoCard/AmmoRow/AmmoLabel
@onready var scoreboard: VBoxContainer = $Right/ScoreboardPanel/Scoreboard
@onready var center_label: Label = $CenterLabel
@onready var damage_vignette: TextureRect = $DamageVignette
@onready var death_overlay: ColorRect = $DeathOverlay
@onready var kill_feed: VBoxContainer = $KillFeed/Items
@onready var kill_banner_panel: PanelContainer = $KillBannerPanel
@onready var kill_banner: Label = $KillBannerPanel/KillBanner
@onready var lb_panel: PanelContainer = $LeaderboardPanel
@onready var lb_rows: VBoxContainer = $LeaderboardPanel/LBox/LBRows
@onready var hit_marker: Label = $HitMarker

const VIGNETTE_FADE := 0.6
const DEATH_FADE_IN := 0.35
const DEATH_FADE_OUT := 0.4
const KILL_FEED_LIFETIME := 4.0
const KILL_BANNER_LIFETIME := 2.5

var local_player: Node = null
var _row_cache: Dictionary = {}
var _vignette_alpha: float = 0.0
var _countdown_left: float = 0.0
var _show_countdown_text: bool = false
var _kill_banner_timer: float = 0.0
var _hit_marker_tween: Tween = null
var _current_weapon_name: String = "AMMO"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	center_label.visible = false
	damage_vignette.modulate.a = 0.0
	death_overlay.modulate.a = 0.0
	kill_banner_panel.visible = false
	lb_panel.visible = false

func _process(delta: float) -> void:
	if _vignette_alpha > 0.0:
		_vignette_alpha = max(0.0, _vignette_alpha - delta / VIGNETTE_FADE)
		damage_vignette.modulate.a = _vignette_alpha
	if _show_countdown_text:
		_countdown_left = max(0.0, _countdown_left - delta)
		_render_countdown()
	if _kill_banner_timer > 0.0:
		_kill_banner_timer = max(0.0, _kill_banner_timer - delta)
		if _kill_banner_timer == 0.0:
			kill_banner_panel.visible = false

func bind_to_game(g: Node) -> void:
	if not NetworkManager.player_list_changed.is_connected(_refresh_scoreboard):
		NetworkManager.player_list_changed.connect(_refresh_scoreboard)
	if not g.local_player_spawned.is_connected(_on_local_player_spawned):
		g.local_player_spawned.connect(_on_local_player_spawned)
	_refresh_scoreboard()

func _on_local_player_spawned(p: Node) -> void:
	local_player = p
	if not p.local_health_changed.is_connected(_on_health):
		p.local_health_changed.connect(_on_health)
	if not p.local_ammo_changed.is_connected(_on_ammo):
		p.local_ammo_changed.connect(_on_ammo)
	if not p.local_damage_taken.is_connected(_on_damage_taken):
		p.local_damage_taken.connect(_on_damage_taken)
	if not p.local_died.is_connected(_on_local_died):
		p.local_died.connect(_on_local_died)
	if not p.local_respawned.is_connected(_on_local_respawned):
		p.local_respawned.connect(_on_local_respawned)
	if not p.local_hit_marker.is_connected(_on_hit_marker):
		p.local_hit_marker.connect(_on_hit_marker)
	if not p.local_weapon_changed.is_connected(_on_weapon_changed):
		p.local_weapon_changed.connect(_on_weapon_changed)
	_on_health(p.health)
	# Seed weapon + ammo display from whatever the player currently holds.
	if p.has_method("get_weapon_info"):
		var info: Dictionary = p.get_weapon_info()
		_on_weapon_changed(int(info["index"]), str(info["name"]),
			int(info["ammo"]), int(info["max_ammo"]))

func _on_hit_marker() -> void:
	# Burst hits within <140ms used to spawn overlapping tweens fighting over
	# the same scale/alpha — kill the prior tween so each new hit restarts
	# clean.
	if _hit_marker_tween and _hit_marker_tween.is_valid():
		_hit_marker_tween.kill()
	hit_marker.modulate.a = 1.0
	hit_marker.scale = Vector2(1.5, 1.5)
	hit_marker.pivot_offset = hit_marker.size * 0.5
	_hit_marker_tween = create_tween()
	_hit_marker_tween.tween_property(hit_marker, "scale", Vector2.ONE, 0.06)
	_hit_marker_tween.parallel().tween_property(hit_marker, "modulate:a", 0.0, 0.14)

func _on_health(h: int) -> void:
	var hp_clamped: int = maxi(0, h)
	hp_label.text = "HP  %d" % hp_clamped
	hp_label.modulate = Color(1, 0.4, 0.4) if hp_clamped < 40 else Color(1, 1, 1)
	hp_bar.value = hp_clamped
	# Bar tints from green → amber → red as HP drops.
	var bar_color: Color
	if hp_clamped < 30:
		bar_color = Color(1, 0.30, 0.30)
	elif hp_clamped < 60:
		bar_color = Color(1, 0.75, 0.30)
	else:
		bar_color = Color(0.30, 0.92, 0.50)
	var fill := hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = bar_color

func _on_ammo(a: int) -> void:
	ammo_label.text = "%s  %d" % [_current_weapon_name, a]

func _on_weapon_changed(_weapon_index: int, weapon_name: String, ammo_count: int, _max_ammo: int) -> void:
	_current_weapon_name = weapon_name
	_on_ammo(ammo_count)

func _on_damage_taken(amount: int) -> void:
	# Cap at 0.45 so a burst of damage doesn't black out the screen.
	_vignette_alpha = min(0.45, _vignette_alpha + amount * 0.007)

func _on_local_died() -> void:
	var tw := create_tween()
	tw.tween_property(death_overlay, "modulate:a", 0.85, DEATH_FADE_IN)

func _on_local_respawned() -> void:
	var tw := create_tween()
	tw.tween_property(death_overlay, "modulate:a", 0.0, DEATH_FADE_OUT)
	_vignette_alpha = 0.0
	damage_vignette.modulate.a = 0.0

# ─── Scoreboard ──────────────────────────────────────────────────────

func _refresh_scoreboard() -> void:
	if scoreboard.get_child_count() == 0:
		scoreboard.add_child(_make_styled_label("SCORE", 20, Color(1, 1, 0.4)))

	for pid in _row_cache.keys():
		if not NetworkManager.players.has(pid):
			_row_cache[pid].queue_free()
			_row_cache.erase(pid)

	var keys := NetworkManager.players.keys()
	keys.sort_custom(func(a, b):
		return NetworkManager.players[a]["kills"] > NetworkManager.players[b]["kills"])

	for i in keys.size():
		var pid: int = keys[i]
		var info: Dictionary = NetworkManager.players[pid]
		var label_text := "%s   K %d  /  D %d" % [info["name"], info["kills"], info["deaths"]]
		var row: Label = _row_cache.get(pid)
		if row == null:
			row = _make_styled_label(label_text, 18, info["color"])
			_row_cache[pid] = row
			scoreboard.add_child(row)
		else:
			row.text = label_text
			row.modulate = info.get("color", Color.WHITE)
		scoreboard.move_child(row, i + 1)

func _make_styled_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l

# ─── Kill feed + banner ──────────────────────────────────────────────

func show_kill(attacker_pid: int, victim_pid: int) -> void:
	var attacker_name := _player_name(attacker_pid)
	var victim_name := _player_name(victim_pid)
	var attacker_color := _player_color(attacker_pid)
	var victim_color := _player_color(victim_pid)
	# Top-right scrolling feed.
	var line := Label.new()
	line.text = "%s  ▶  %s" % [attacker_name, victim_name]
	line.add_theme_font_size_override("font_size", 16)
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 5)
	line.add_theme_color_override("font_color", attacker_color.lerp(victim_color, 0.5))
	kill_feed.add_child(line)
	_fade_and_free(line, KILL_FEED_LIFETIME)

	# Centered banner if local player is involved.
	var local_id := multiplayer.get_unique_id()
	if attacker_pid == local_id and victim_pid != local_id:
		_show_kill_banner("YOU KILLED %s" % victim_name, Color(0.3, 1, 0.4))
	elif victim_pid == local_id:
		_show_kill_banner("%s KILLED YOU" % attacker_name, Color(1, 0.3, 0.3))

func _show_kill_banner(text: String, color: Color) -> void:
	kill_banner_panel.visible = true
	kill_banner_panel.modulate = Color(1, 1, 1, 1)
	kill_banner.text = text
	kill_banner.add_theme_color_override("font_color", color)
	_kill_banner_timer = KILL_BANNER_LIFETIME

func _fade_and_free(node: CanvasItem, lifetime: float) -> void:
	await get_tree().create_timer(lifetime - 0.5).timeout
	if not is_instance_valid(node):
		return
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, 0.5)
	await tw.finished
	if is_instance_valid(node):
		node.queue_free()

func _player_name(pid: int) -> String:
	if NetworkManager.players.has(pid):
		return NetworkManager.players[pid].get("name", "?")
	return "?"

func _player_color(pid: int) -> Color:
	if NetworkManager.players.has(pid):
		return NetworkManager.players[pid].get("color", Color.WHITE)
	return Color.WHITE

# ─── Winner banner + countdown ───────────────────────────────────────

func show_winner(peer_id: int) -> void:
	center_label.visible = true
	if peer_id == multiplayer.get_unique_id():
		center_label.text = "VICTORY!"
		center_label.modulate = Color(0.4, 1, 0.4)
	else:
		center_label.text = "%s WINS" % _player_name(peer_id)
		center_label.modulate = Color(1, 0.6, 0.6)

func hide_winner() -> void:
	center_label.visible = false
	_show_countdown_text = false
	_countdown_left = 0.0
	lb_panel.visible = false

func show_countdown(seconds: float) -> void:
	_countdown_left = seconds
	_show_countdown_text = true
	_render_countdown()

func _render_countdown() -> void:
	if not center_label.visible:
		center_label.visible = true
	var lines := center_label.text.split("\n")
	var head: String = String(lines[0]) if lines.size() > 0 else ""
	if head == "" or head.contains("Next"):
		head = "Next match"
	center_label.text = "%s\nNext match in %d..." % [head, ceil(_countdown_left)]

# ─── Post-game leaderboard ───────────────────────────────────────────

func show_leaderboard(rows: Array) -> void:
	for c in lb_rows.get_children():
		c.queue_free()
	if rows.is_empty():
		lb_panel.visible = false
		return
	var rank := 1
	for row in rows:
		var l := Label.new()
		l.text = "%d.  %-10s  W %d  K %d  D %d" % [
			rank,
			String(row.get("name", "?")).left(10),
			int(row.get("wins", 0)),
			int(row.get("kills", 0)),
			int(row.get("deaths", 0)),
		]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if rank <= 3 else Color(1, 1, 1))
		lb_rows.add_child(l)
		rank += 1
	# Only auto-show during winner banner; otherwise keep tucked away.
	lb_panel.visible = center_label.visible
