extends Control

@onready var ip_input: LineEdit = $Center/Panel/VBox/IPInput
@onready var status: Label = $Center/Panel/VBox/Status
@onready var host_btn: Button = $Center/Panel/VBox/HostBtn
@onready var join_btn: Button = $Center/Panel/VBox/JoinBtn

func _ready() -> void:
	# If launched as dedicated server, skip the menu entirely.
	if "--server" in OS.get_cmdline_user_args():
		print("[main_menu] --server flag detected, starting dedicated server")
		NetworkManager.start_dedicated_server()
		return

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	NetworkManager.connection_failed.connect(_on_failed)
	NetworkManager.disconnected.connect(_on_disconnected)

	# Pre-fill the input with the default server URL.
	ip_input.text = NetworkManager.default_server_url

	# Hosts can't run in browsers (no listening sockets allowed).
	if OS.has_feature("web"):
		host_btn.disabled = true
		host_btn.text = "Host (desktop only)"
		status.text = "Press Join to connect"
		_load_default_server_url()
	else:
		status.text = "Pick Host or Join"

# Web build only: load `server.json` from the same origin so users don't
# have to type the server URL on mobile.
func _load_default_server_url() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_server_json_loaded.bind(http))
	# HTTPRequest needs an absolute URL — relative paths resolve to the site
	# root (e.g. github.io/server.json), not to our subpath. Build it from
	# window.location so it works whether the build lives at /, /arena/, etc.
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
