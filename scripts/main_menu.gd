extends Control

const SKIN_COUNT := 18

@onready var ip_input: LineEdit = $Center/Cols/Panel/VBox/IPInput
@onready var status: Label = $Center/Cols/Panel/VBox/Status
@onready var host_btn: Button = $Center/Cols/Panel/VBox/HostBtn
@onready var join_btn: Button = $Center/Cols/Panel/VBox/JoinBtn
@onready var name_input: LineEdit = $Center/Cols/Panel/VBox/NameInput
@onready var skin_prev: Button = $Center/Cols/Panel/VBox/SkinPicker/PrevBtn
@onready var skin_next: Button = $Center/Cols/Panel/VBox/SkinPicker/NextBtn
@onready var skin_preview: TextureRect = $Center/Cols/Panel/VBox/SkinPicker/PreviewBg/Preview
@onready var skin_name: Label = $Center/Cols/Panel/VBox/SkinName
@onready var lb_rows: VBoxContainer = $Center/Cols/LeaderboardPanel/LBox/LBRows
@onready var lb_empty: Label = $Center/Cols/LeaderboardPanel/LBox/LBEmpty

func _ready() -> void:
	print("[probe] main_menu build=v641c-cachefix")  # autonomous-rebuild verification
	if "--server" in OS.get_cmdline_user_args():
		print("[main_menu] --server flag detected, starting dedicated server")
		NetworkManager.start_dedicated_server()
		return

	NetworkManager.load_settings()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	skin_prev.pressed.connect(func(): _change_skin(-1))
	skin_next.pressed.connect(func(): _change_skin(1))
	name_input.text_changed.connect(_on_name_changed)
	NetworkManager.connection_failed.connect(_on_failed)
	NetworkManager.disconnected.connect(_on_disconnected)
	StatsStore.leaderboard_updated.connect(_render_leaderboard)

	name_input.text = NetworkManager.local_player_name
	ip_input.text = NetworkManager.default_server_url
	_refresh_skin()
	_render_leaderboard(StatsStore.cached_leaderboard)

	if OS.has_feature("web"):
		host_btn.disabled = true
		host_btn.text = "Host (desktop only)"
		# Block Join until server.json finishes loading; otherwise a fast tap
		# would dial the localhost default that's only valid in dev.
		join_btn.disabled = true
		ip_input.text = ""
		ip_input.placeholder_text = "Loading server URL..."
		status.text = "Loading server URL..."
		_load_default_server_url()
	else:
		status.text = "Pick Host or Join"

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
	print("[main_menu] fetching server.json (via JS)")
	# Diagnostic 1: can eval write a string? (round-trip)
	JavaScriptBridge.eval("window.__diag = 'hello-from-eval'", true)
	var d1: Variant = JavaScriptBridge.eval("window.__diag", true)
	print("[diag] eval write/read result: type=%s val='%s'" % [typeof(d1), String(d1) if d1 != null else "<null>"])
	# Diagnostic 2: trigger a console.log so we know the JS code runs
	JavaScriptBridge.eval("console.log('[js eval] diag console.log fired')", true)
	# Now the actual fetch
	JavaScriptBridge.eval("""
		window.__sj_status = 'pending';
		window.__sj_url = '';
		(function() {
			var u = location.origin + location.pathname.replace(/[^/]*$/, '') + 'server.json';
			console.log('[js fetch] starting', u);
			fetch(u, {cache: 'no-cache'})
				.then(function(r){ console.log('[js fetch] got response', r.status); if (!r.ok) throw new Error('http ' + r.status); return r.json(); })
				.then(function(j){
					window.__sj_url = (j && j.url) ? String(j.url) : '';
					window.__sj_status = 'done';
					console.log('[js fetch] resolved:', window.__sj_url);
				})
				.catch(function(e){
					window.__sj_status = 'error';
					console.log('[js fetch] rejected:', String(e));
				});
		})();
	""", true)
	var elapsed := 0.0
	var tick := 0.15
	var deadline := 6.0
	while elapsed < deadline:
		await get_tree().create_timer(tick).timeout
		elapsed += tick
		var status_v: Variant = JavaScriptBridge.eval("String(window.__sj_status||'')", true)
		var status_s := String(status_v) if status_v != null else ""
		if status_s == "pending" or status_s == "":
			continue
		var url_v: Variant = JavaScriptBridge.eval("String(window.__sj_url||'')", true)
		var url_s := String(url_v) if url_v != null else ""
		print("[main_menu] server.json status=%s url='%s'" % [status_s, url_s])
		_apply_server_url(url_s)
		return
	# Pre-timeout poke so we can see what status got stuck at
	var final_status: Variant = JavaScriptBridge.eval("String(window.__sj_status||'<undef>')", true)
	print("[main_menu] server.json timed out, final status='%s'" % String(final_status))
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
	if url == "":
		ip_input.placeholder_text = "Enter server URL (e.g. wss://...)"
		status.text = "Server URL unavailable — paste manually"
		if not ip_input.text_changed.is_connected(_on_manual_ip_changed):
			ip_input.text_changed.connect(_on_manual_ip_changed)
		return
	print("[main_menu] loaded server URL: ", url)
	NetworkManager.default_server_url = url
	if is_instance_valid(ip_input):
		ip_input.text = url
	join_btn.disabled = false
	status.text = "Press Join to connect"

func _on_manual_ip_changed(new_text: String) -> void:
	join_btn.disabled = new_text.strip_edges() == ""

func _on_host() -> void:
	NetworkManager.save_settings()
	status.text = "Starting server..."
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
