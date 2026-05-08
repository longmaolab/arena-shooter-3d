extends CanvasLayer

@onready var hp_label: Label = $Margin/VBox/HealthLabel
@onready var ammo_label: Label = $Margin/VBox/AmmoLabel
@onready var scoreboard: VBoxContainer = $Right/Scoreboard
@onready var center_label: Label = $CenterLabel
@onready var damage_vignette: TextureRect = $DamageVignette
@onready var death_overlay: ColorRect = $DeathOverlay

const VIGNETTE_FADE := 0.6
const DEATH_FADE_IN := 0.15
const DEATH_FADE_OUT := 0.4

var local_player: Node = null
var _row_cache: Dictionary = {}
var _vignette_alpha: float = 0.0
var _countdown_left: float = 0.0
var _show_countdown_text: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	center_label.visible = false
	damage_vignette.modulate.a = 0.0
	death_overlay.modulate.a = 0.0

func _process(delta: float) -> void:
	if _vignette_alpha > 0.0:
		_vignette_alpha = max(0.0, _vignette_alpha - delta / VIGNETTE_FADE)
		damage_vignette.modulate.a = _vignette_alpha
	if _show_countdown_text:
		_countdown_left = max(0.0, _countdown_left - delta)
		_render_countdown()

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
	_on_health(p.health)
	_on_ammo(p.ammo)

func _on_health(h: int) -> void:
	hp_label.text = "HP: %d" % max(0, h)
	hp_label.modulate = Color(1, 0.4, 0.4) if h < 40 else Color(1, 1, 1)

func _on_ammo(a: int) -> void:
	ammo_label.text = "AMMO: %d" % a

func _on_damage_taken(amount: int) -> void:
	_vignette_alpha = min(0.7, _vignette_alpha + amount * 0.012)

func _on_local_died() -> void:
	var tw := create_tween()
	tw.tween_property(death_overlay, "modulate:a", 0.85, DEATH_FADE_IN)

func _on_local_respawned() -> void:
	var tw := create_tween()
	tw.tween_property(death_overlay, "modulate:a", 0.0, DEATH_FADE_OUT)
	_vignette_alpha = 0.0
	damage_vignette.modulate.a = 0.0

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
		scoreboard.move_child(row, i + 1)

func _make_styled_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l

func show_winner(peer_id: int) -> void:
	center_label.visible = true
	if peer_id == multiplayer.get_unique_id():
		center_label.text = "VICTORY!"
		center_label.modulate = Color(0.4, 1, 0.4)
	else:
		var winner_name := "P?"
		if NetworkManager.players.has(peer_id):
			winner_name = NetworkManager.players[peer_id]["name"]
		center_label.text = "%s WINS" % winner_name
		center_label.modulate = Color(1, 0.6, 0.6)

func hide_winner() -> void:
	center_label.visible = false
	_show_countdown_text = false
	_countdown_left = 0.0

func show_countdown(seconds: float) -> void:
	_countdown_left = seconds
	_show_countdown_text = true
	_render_countdown()

func _render_countdown() -> void:
	if not center_label.visible:
		center_label.visible = true
	var existing := center_label.text
	# Preserve any leading "VICTORY!" / "PX WINS" line, append countdown.
	var lines := existing.split("\n")
	var head := lines[0] if lines.size() > 0 else ""
	if head == "" or head.contains("Next"):
		head = "Next match"
	center_label.text = "%s\nNext match in %d..." % [head, ceil(_countdown_left)]
