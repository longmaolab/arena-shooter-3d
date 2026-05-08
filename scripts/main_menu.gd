extends Control

const SKIN_COUNT := 18

@onready var ip_input: LineEdit = $Center/Panel/VBox/IPInput
@onready var status: Label = $Center/Panel/VBox/Status
@onready var host_btn: Button = $Center/Panel/VBox/HostBtn
@onready var join_btn: Button = $Center/Panel/VBox/JoinBtn
@onready var skin_prev: Button = $Center/Panel/VBox/SkinPicker/PrevBtn
@onready var skin_next: Button = $Center/Panel/VBox/SkinPicker/NextBtn
@onready var skin_preview: TextureRect = $Center/Panel/VBox/SkinPicker/PreviewBg/Preview
@onready var skin_name: Label = $Center/Panel/VBox/SkinName

func _ready() -> void:
	# If launched as dedicated server, skip the menu entirely.
	if "--server" in OS.get_cmdline_user_args():
		print("[main_menu] --server flag detected, starting dedicated server")
		NetworkManager.start_dedicated_server()
		return

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	skin_prev.pressed.connect(func(): _change_skin(-1))
	skin_next.pressed.connect(func(): _change_skin(1))
	NetworkManager.connection_failed.connect(_on_failed)
	NetworkManager.disconnected.connect(_on_disconnected)

	ip_input.text = NetworkManager.default_server_url
	_refresh_skin()

	if OS.has_feature("web"):
		host_btn.disabled = true
		host_btn.text = "Host (desktop only)"
		status.text = "Press Join to connect"
		_load_default_server_url()
	else:
		status.text = "Pick Host or Join"

func _change_skin(delta: int) -> void:
	NetworkManager.local_skin_index = (NetworkManager.local_skin_index + delta + SKIN_COUNT) % SKIN_COUNT
	_refresh_skin()

func _refresh_skin() -> void:
	var idx := NetworkManager.local_skin_index
	var letter := String.chr("a".unicode_at(0) + idx)
	var path := "res://models/characters/previews/character-%s.png" % letter
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		skin_preview.texture = tex
	skin_name.text = "Skin %s  (%d/%d)" % [letter.to_upper(), idx + 1, SKIN_COUNT]

func _load_default_server_url() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_server_json_loaded.bind(http))
	# HTTPRequest needs an absolute URL — relative paths resolve to the site
	# root (e.g. github.io/server.json), not to our subpath.
	var url := "server.json"
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var resolved: Variant = JavaScriptBridge.eval(
			"location.origin + location.pathname.replace(/[^/]*$/, '') + 'server.json'", true)
		if typeof(resolved) == TYPE_STRING and resolved != "":
			url = resolved
	print("[main_menu] fetching ", url)
	var err := http.request(url)
	if err != OK:
		print("[main_menu] http.request failed: ", err)
		http.queue_free()

func _on_server_json_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	print("[main_menu] server.json HTTP ", response_code)
	if response_code != 200:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[main_menu] server.json not a dict")
		return
	var url: String = parsed.get("url", "")
	if url == "":
		print("[main_menu] server.json has no 'url'")
		return
	print("[main_menu] loaded server URL: ", url)
	NetworkManager.default_server_url = url
	if is_instance_valid(ip_input):
		ip_input.text = url

func _on_host() -> void:
	status.text = "Starting server..."
	var err := NetworkManager.host_game()
	if err != OK:
		status.text = "Host failed: %s" % err

func _on_join() -> void:
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
