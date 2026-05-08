extends Control
# Mobile/touch input overlay. Auto-shows on touch devices.
# - Left 40% of screen: virtual joystick that appears under the finger
# - Right 60% (above buttons): drag to look
# - Bottom-right buttons: shoot, jump, reload

const ACTIONS := {
	"left":   "move_left",
	"right":  "move_right",
	"forward": "move_forward",
	"back":    "move_back",
	"jump":    "jump",
	"shoot":   "shoot",
	"reload":  "reload",
}
const LOOK_SENSITIVITY := 0.0045
const JOY_RADIUS := 110.0
const BTN_SIZE := 100.0
const BTN_MARGIN := 18.0

var _move_touch_id := -1
var _move_origin := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _move_active := false

var _look_touch_id := -1
var _look_last := Vector2.ZERO

var _shoot_touch_id := -1
var _jump_touch_id := -1
var _reload_touch_id := -1

var _shoot_rect := Rect2()
var _jump_rect := Rect2()
var _reload_rect := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = _is_touch_device()
	if not visible:
		set_process_input(false)
		return
	get_viewport().size_changed.connect(_recalc_buttons)
	_recalc_buttons()

func _is_touch_device() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return false

func _recalc_buttons() -> void:
	var s := get_viewport().get_visible_rect().size
	var bottom := s.y - BTN_MARGIN - BTN_SIZE
	_shoot_rect = Rect2(s.x - BTN_MARGIN - BTN_SIZE, bottom, BTN_SIZE, BTN_SIZE)
	_jump_rect = Rect2(s.x - BTN_MARGIN - BTN_SIZE * 2 - 14, bottom, BTN_SIZE, BTN_SIZE)
	_reload_rect = Rect2(s.x - BTN_MARGIN - BTN_SIZE, bottom - BTN_SIZE - 14, BTN_SIZE, BTN_SIZE)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _shoot_rect.has_point(event.position):
			_shoot_touch_id = event.index
			Input.action_press(ACTIONS["shoot"])
		elif _jump_rect.has_point(event.position):
			_jump_touch_id = event.index
			Input.action_press(ACTIONS["jump"])
		elif _reload_rect.has_point(event.position):
			_reload_touch_id = event.index
			Input.action_press(ACTIONS["reload"])
		elif event.position.x < get_viewport().get_visible_rect().size.x * 0.4:
			_move_touch_id = event.index
			_move_origin = event.position
			_move_knob = event.position
			_move_active = true
			queue_redraw()
		else:
			_look_touch_id = event.index
			_look_last = event.position
	else:
		if event.index == _shoot_touch_id:
			_shoot_touch_id = -1
			Input.action_release(ACTIONS["shoot"])
		elif event.index == _jump_touch_id:
			_jump_touch_id = -1
			Input.action_release(ACTIONS["jump"])
		elif event.index == _reload_touch_id:
			_reload_touch_id = -1
			Input.action_release(ACTIONS["reload"])
		elif event.index == _move_touch_id:
			_move_touch_id = -1
			_move_active = false
			_set_move_vector(Vector2.ZERO)
			queue_redraw()
		elif event.index == _look_touch_id:
			_look_touch_id = -1

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_touch_id:
		var offset := event.position - _move_origin
		if offset.length() > JOY_RADIUS:
			offset = offset.normalized() * JOY_RADIUS
		_move_knob = _move_origin + offset
		_set_move_vector(offset / JOY_RADIUS)
		queue_redraw()
	elif event.index == _look_touch_id:
		var delta := event.position - _look_last
		_look_last = event.position
		var p := get_tree().get_first_node_in_group("local_player")
		if p and p.has_method("apply_touch_look"):
			p.apply_touch_look(delta * LOOK_SENSITIVITY)

func _set_move_vector(v: Vector2) -> void:
	_set_action(ACTIONS["right"],   max(0.0, v.x))
	_set_action(ACTIONS["left"],    max(0.0, -v.x))
	_set_action(ACTIONS["back"],    max(0.0, v.y))
	_set_action(ACTIONS["forward"], max(0.0, -v.y))

func _set_action(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _draw() -> void:
	if not visible:
		return
	if _move_active:
		draw_circle(_move_origin, JOY_RADIUS, Color(1, 1, 1, 0.15))
		draw_arc(_move_origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
		draw_circle(_move_knob, 36, Color(1, 1, 1, 0.55))
	_draw_button(_shoot_rect, "FIRE", Color(1, 0.35, 0.35, 0.55), _shoot_touch_id != -1)
	_draw_button(_jump_rect, "JUMP", Color(0.4, 0.7, 1, 0.55), _jump_touch_id != -1)
	_draw_button(_reload_rect, "RELOAD", Color(1, 0.85, 0.4, 0.55), _reload_touch_id != -1)

func _draw_button(rect: Rect2, label: String, color: Color, pressed: bool) -> void:
	var c: Color = color
	if pressed:
		c.a = min(1.0, c.a + 0.3)
	draw_circle(rect.position + rect.size / 2, rect.size.x / 2, c)
	var font: Font = ThemeDB.fallback_font
	var font_size := 26
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var center := rect.position + rect.size / 2
	draw_string(font, center - Vector2(text_size.x / 2.0, -font_size / 3.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
