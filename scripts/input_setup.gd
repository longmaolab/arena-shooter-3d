extends Node
# Autoload — registers input actions at startup so we don't depend on
# fragile InputMap entries inside project.godot.

func _ready() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back",    KEY_S)
	_add_key("move_left",    KEY_A)
	_add_key("move_right",   KEY_D)
	_add_key("jump",         KEY_SPACE)
	_add_key("sprint",       KEY_SHIFT)
	_add_key("reload",       KEY_R)
	_add_key("restart",      KEY_ENTER)
	_add_mouse("shoot",      MOUSE_BUTTON_LEFT)

func _add_key(action: String, keycode: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, ev)

func _add_mouse(action: String, button: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button as MouseButton
	InputMap.action_add_event(action, ev)
