extends Control

const SKIN_COUNT := 18

@onready var ip_input: LineEdit = $Scroll/Center/Cols/Panel/VBox/IPInput
@onready var status: Label = $Scroll/Center/Cols/Panel/VBox/Status
@onready var host_btn: Button = $Scroll/Center/Cols/Panel/VBox/HostBtn
@onready var join_btn: Button = $Scroll/Center/Cols/Panel/VBox/JoinBtn
@onready var name_input: LineEdit = $Scroll/Center/Cols/Panel/VBox/NameInput
@onready var skin_prev: Button = $Scroll/Center/Cols/Panel/VBox/SkinPicker/PrevBtn
@onready var skin_next: Button = $Scroll/Center/Cols/Panel/VBox/SkinPicker/NextBtn
@onready var skin_preview: TextureRect = $Scroll/Center/Cols/Panel/VBox/SkinPicker/PreviewBg/Preview
@onready var skin_name: Label = $Scroll/Center/Cols/Panel/VBox/SkinName
@onready var lb_rows: VBoxContainer = $Scroll/Center/Cols/LeaderboardPanel/LBox/LBRows
@onready var lb_empty: Label = $Scroll/Center/Cols/LeaderboardPanel/LBox/LBEmpty
@onready var bot_btn_1: Button = $Scroll/Center/Cols/Panel/VBox/BotRow/Bot1
@onready var bot_btn_2: Button = $Scroll/Center/Cols/Panel/VBox/BotRow/Bot2
@onready var bot_btn_3: Button = $Scroll/Center/Cols/Panel/VBox/BotRow/Bot3

var _selected_bot_count: int = 2

func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args():
		print("[main_menu] --server flag detected, starting dedicated server")
		NetworkManager.start_dedicated_server()
		return

	NetworkManager.load_settings()

	_apply_mobile_ui_scale()
	get_viewport().size_changed.connect(_apply_mobile_ui_scale)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	skin_prev.pressed.connect(func(): _change_skin(-1))
	skin_next.pressed.connect(func(): _change_skin(1))
	name_input.text_changed.connect(_on_name_changed)
	# ButtonGroup enforces single-select + no-unpress, so each handler
	# only needs to record the new value.
	bot_btn_1.pressed.connect(func(): _selected_bot_count = 1)
	bot_btn_2.pressed.connect(func(): _selected_bot_count = 2)
	bot_btn_3.pressed.connect(func(): _selected_bot_count = 3)
	NetworkManager.connection_failed.connect(_on_failed)
	NetworkManager.disconnected.connect(_on_disconnected)
	StatsStore.leaderboard_updated.connect(_render_leaderboard)

	name_input.text = NetworkManager.local_player_name
	ip_input.text = NetworkManager.default_server_url
	_refresh_skin()
	_render_leaderboard(StatsStore.cached_leaderboard)

	if OS.has_feature("web"):
		# Web: PLAY = join the public server, PLAY vs BOTS = offline single
		# player (browsers can't bind a real server socket, so host_game
		# falls back to OfflineMultiplayerPeer in that case).
		ip_input.text = NetworkManager.default_server_url
		status.text = "PLAY = online    PLAY vs BOTS = single-player"
		_load_default_server_url()
	else:
		status.text = "PLAY = join LAN    PLAY vs BOTS = single-player"

func _apply_mobile_ui_scale() -> void:
	# On phones / small browser canvases the 1280x720 design resolution
	# renders ~0.6x scale, which makes labels unreadable. Bump the window's
	# content_scale_factor so the menu reads like a phone-native UI without
	# us having to re-author every font size for two form factors.
	var win := get_window()
	if win == null:
		return
	var size := get_viewport().get_visible_rect().size
	# Pick a scale that targets roughly 720 logical px tall, regardless of
	# physical viewport. Capped so desktop doesn't get gigantic chrome.
	var s: float = clamp(720.0 / max(size.y, 1.0), 1.0, 1.8)
	# Touch devices need a small extra bump — fingers need bigger hit
	# targets than a mouse cursor.
	var is_touch := DisplayServer.is_touchscreen_available() \
		or OS.has_feature("mobile") \
		or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")
	if is_touch:
		s = clamp(s * 1.15, 1.0, 1.85)
	win.content_scale_factor = s

func _on_name_changed(new_text: String) -> void:
	NetworkManager.local_player_name = new_text.strip_edges()
	NetworkManager.save_settings()

func _change_skin(delta: int) -> void:
	NetworkManager.local_skin_index = (NetworkManager.local_skin_index + delta + SKIN_COUNT) % SKIN_COUNT
	_refresh_skin()
	NetworkManager.save_settings()

func _refresh_skin() -> void:
	var idx := NetworkManager.local_skin_index
	var letter := String.chr("a".unicode_at(0) + idx)
	var path := "res://models/characters/previews/character-%s.png" % letter
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		skin_preview.texture = tex
	skin_name.text = "Skin %s  (%d/%d)" % [letter.to_upper(), idx + 1, SKIN_COUNT]

func _render_leaderboard(rows: Array) -> void:
	for c in lb_rows.get_children():
		c.queue_free()
	if rows.is_empty():
		lb_empty.visible = true
		return
	lb_empty.visible = false
	var rank := 1
	for row in rows:
		var l := Label.new()
		l.text = "%d.  %-12s  %3d  %3d  %3d" % [
			rank,
			String(row.get("name", "?")).left(12),
			int(row.get("wins", 0)),
			int(row.get("kills", 0)),
			int(row.get("deaths", 0)),
		]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(1, 1, 1) if rank > 3 else Color(1, 0.85, 0.3))
		lb_rows.add_child(l)
		rank += 1

func _load_default_server_url() -> void:
	# Web: HTTPRequest's request_completed signal proved unreliable in
	# Godot 4.6 web export (single-threaded build). Bypass it with the
	# browser's native fetch via JavaScriptBridge and poll a JS global.
	# Native: keep the HTTPRequest path so this stays a pure-Godot path.
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		await _load_via_js_fetch()
	else:
		_load_via_http_request()

func _load_via_js_fetch() -> void:
	# Soft override: try to fetch server.json via the browser's native
	# fetch (HTTPRequest's request_completed proved unreliable in 4.6 web
	# single-threaded builds). If anything fails, we keep the baked-in
	# default URL. No UI gate — Join works regardless.
	print("[main_menu] fetching server.json (via JS, soft override)")
	JavaScriptBridge.eval("""
		window.__sj_status = 'pending';
		window.__sj_url = '';
		var u = location.origin + location.pathname.replace(/[^/]*$/, '') + 'server.json';
		fetch(u, {cache: 'no-cache'})
			.then(function(r){ if (!r.ok) throw new Error('http ' + r.status); return r.json(); })
			.then(function(j){
				window.__sj_url = (j && j.url) ? String(j.url) : '';
				window.__sj_status = 'done';
			})
			.catch(function(_){ window.__sj_status = 'error'; });
	""", true)
	var elapsed := 0.0
	var tick := 0.2
	var deadline := 4.0
	while elapsed < deadline:
		await get_tree().create_timer(tick).timeout
		elapsed += tick
		var status_v: Variant = JavaScriptBridge.eval("String(window.__sj_status||'')", true)
		var status_s := String(status_v) if status_v != null else ""
		if status_s == "pending" or status_s == "":
			continue
		var url_v: Variant = JavaScriptBridge.eval("String(window.__sj_url||'')", true)
		var url_s := String(url_v) if url_v != null else ""
		_apply_server_url(url_s)
		return
	_apply_server_url("")

func _load_via_http_request() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_server_json_loaded.bind(http))
	var url := "server.json"
	print("[main_menu] fetching ", url)
	var err := http.request(url)
	if err != OK:
		print("[main_menu] http.request failed: ", err)
		http.queue_free()
		_apply_server_url("")

func _on_server_json_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	print("[main_menu] server.json HTTP ", response_code)
	var url: String = ""
	if response_code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY:
			url = parsed.get("url", "")
	_apply_server_url(url)

func _apply_server_url(url: String) -> void:
	# Soft override: replace the baked-in default if server.json provided
	# a URL. If fetch failed or returned empty, the baked default stays.
	if url == "":
		print("[main_menu] server.json unavailable, keeping baked default")
		return
	print("[main_menu] server.json override: ", url)
	NetworkManager.default_server_url = url
	if is_instance_valid(ip_input):
		ip_input.text = url

# Kept for completeness (unused after server.json became soft).
func _on_manual_ip_changed(_new_text: String) -> void:
	pass

func _on_host() -> void:
	NetworkManager.save_settings()
	status.text = "Starting bot match..."
	NetworkManager.desired_bot_count = _selected_bot_count
	var err := NetworkManager.host_game()
	if err != OK:
		status.text = "Host failed: %s" % err

func _on_join() -> void:
	NetworkManager.save_settings()
	var addr := ip_input.text.strip_edges()
	if addr == "":
		addr = NetworkManager.default_server_url
	status.text = "Connecting to %s..." % addr
	var err := NetworkManager.join_game(addr)
	if err != OK:
		status.text = "Join failed: %s" % err

func _on_failed() -> void:
	status.text = "Connection failed — is the server up?"

func _on_disconnected() -> void:
	status.text = "Server disconnected"
