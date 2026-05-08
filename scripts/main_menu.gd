extends Control

@onready var ip_input: LineEdit = $Center/Panel/VBox/IPInput
@onready var status: Label = $Center/Panel/VBox/Status
@onready var host_btn: Button = $Center/Panel/VBox/HostBtn
@onready var join_btn: Button = $Center/Panel/VBox/JoinBtn

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	ip_input.text = "127.0.0.1"
	NetworkManager.connection_failed.connect(_on_failed)
	NetworkManager.disconnected.connect(_on_disconnected)
	# Browsers cannot host (can't open a server socket).
	if OS.has_feature("web"):
		host_btn.disabled = true
		host_btn.text = "Host (desktop only)"
		status.text = "Browser: enter host's wss:// URL and Join"
	else:
		status.text = "Pick Host or Join"

func _on_host() -> void:
	status.text = "Starting server..."
	var err := NetworkManager.host_game()
	if err != OK:
		status.text = "Host failed: %s" % err

func _on_join() -> void:
	var ip := ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	status.text = "Connecting to %s..." % ip
	var err := NetworkManager.join_game(ip)
	if err != OK:
		status.text = "Join failed: %s" % err

func _on_failed() -> void:
	status.text = "Connection failed — is the host running?"

func _on_disconnected() -> void:
	status.text = "Server disconnected"
