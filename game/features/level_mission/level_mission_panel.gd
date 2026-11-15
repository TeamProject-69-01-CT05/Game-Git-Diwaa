class_name LevelMissionPanel
extends PanelContainer

## แผงภารกิจของด่านที่แสดงทับพื้นที่กลางของ Sandbox: ขั้นที่ ชื่อภารกิจ เรื่องย่อ
## เช็กลิสต์ภารกิจ ข้อความตอบกลับเมื่อพิมพ์ผิด ปุ่มคำใบ้ และปุ่มไปต่อเมื่อทำครบ
## ไม่ตรวจคำสั่งเอง: รับ LevelMission มาแสดงและเรียก refresh() เมื่อสถานะเปลี่ยน

signal continue_pressed

const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/ChakraPetch-Bold.ttf"
const DONE_COLOR := SandboxThemeTokens.PROMPT_GREEN
const MAX_FEEDBACK_SECONDS := 6.0

var _mission: LevelMission
var _font_regular: Font
var _font_bold: Font

var _badge_label: Label
var _title_label: Label
var _story_label: Label
var _rows_box: VBoxContainer
var _hint_button: Button
var _hint_label: Label
var _feedback_label: Label
var _complete_box: VBoxContainer
var _complete_label: Label
var _continue_button: Button
var _feedback_tween: Tween
var _hint_visible := false


func _init() -> void:
	name = "LevelMissionPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var card := SandboxThemeTokens.create_card_style()
	card.bg_color = Color(0.035, 0.042, 0.08, 0.96)
	card.border_color = Color(0.92, 0.74, 0.35, 1.0)
	card.set_border_width_all(2)
	card.set_corner_radius_all(10)
	card.content_margin_left = 14
	card.content_margin_right = 14
	card.content_margin_top = 10
	card.content_margin_bottom = 10
	add_theme_stylebox_override("panel", card)
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		_font_regular = load(FONT_REGULAR_PATH) as Font
	if ResourceLoader.exists(FONT_BOLD_PATH):
		_font_bold = load(FONT_BOLD_PATH) as Font
	_build()


func setup(mission: LevelMission) -> void:
	_mission = mission
	_badge_label.text = "ด่านที่ %d · %d/%d" % [mission.level_number, mission.step, mission.total_steps]
	_title_label.text = mission.title
	_story_label.text = mission.story
	_hint_visible = false
	_complete_box.visible = false
	_feedback_label.text = ""
	_feedback_label.visible = false
	refresh()


## วาดรายการภารกิจและแถบความคืบหน้าใหม่ตามสถานะใน LevelMission
func refresh() -> void:
	if _mission == null:
		return
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()

	# ภารกิจเดียว: ข้อความภารกิจไปอยู่ที่ช่องพิมพ์ของเทอร์มินัลแทน จึงไม่ต้องแสดงเช็กลิสต์ซ้ำ
	# หลายภารกิจ: แสดงเช็กลิสต์ชื่อสั้น และตัดคำอธิบายเรื่องย่อออกเพื่อประหยัดที่ (แผงอยู่บนแผง Files)
	var show_checklist := _mission.objectives.size() > 1
	_rows_box.visible = show_checklist
	_story_label.visible = not show_checklist

	var current := _mission.current_objective()
	if show_checklist:
		for objective in _mission.objectives:
			var done := _mission.is_done(str(objective["id"]))
			var is_current: bool = not current.is_empty() and str(current["id"]) == str(objective["id"])
			_rows_box.add_child(_build_row(str(objective.get("short", objective["text"])), done, is_current))

	var finished := _mission.is_complete()
	_hint_button.visible = not finished
	_hint_label.visible = _hint_visible and not finished
	_hint_label.text = str(current.get("hint", ""))
	reset_size()


## แสดงข้อความตอบกลับสั้น ๆ (เช่น เตือนพิมพ์ผิด / ยืนยันว่าทำสำเร็จ) แล้วจางหายเอง
func show_feedback(text: String, is_error: bool = false) -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_label.text = text
	_feedback_label.visible = not text.is_empty()
	_feedback_label.add_theme_color_override("font_color",
			SandboxThemeTokens.ERROR_TEXT if is_error else DONE_COLOR)
	_feedback_label.modulate.a = 1.0
	if text.is_empty():
		return
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(MAX_FEEDBACK_SECONDS)
	_feedback_tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.6)


func show_complete(message: String, button_text: String) -> void:
	_hint_visible = false
	_complete_label.text = message
	_continue_button.text = button_text
	_complete_box.visible = true
	_rows_box.visible = false # ติ๊กครบแล้ว ใช้ข้อความสำเร็จแทน เพื่อไม่ให้แผงสูงจนดันแผง Files ลงไปใต้เทอร์มินัล
	_hint_button.visible = false
	_hint_label.visible = false
	show_feedback("")
	_complete_box.modulate.a = 0.0
	create_tween().tween_property(_complete_box, "modulate:a", 1.0, 0.35)
	_continue_button.grab_focus.call_deferred()


func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_theme_constant_override("separation", 10)
	_badge_label = _make_label(18, SandboxThemeTokens.GOLD_TITLE, true)
	header.add_child(_badge_label)
	_title_label = _make_label(26, SandboxThemeTokens.BRAND_TEXT, true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.clip_text = true
	header.add_child(_title_label)
	_hint_button = Button.new()
	_hint_button.custom_minimum_size = Vector2(96, 32)
	_hint_button.focus_mode = Control.FOCUS_NONE
	_hint_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var hint_btn_style := SandboxThemeTokens.create_button_style()
	hint_btn_style.content_margin_left = 10
	hint_btn_style.content_margin_right = 12
	hint_btn_style.content_margin_top = 4
	hint_btn_style.content_margin_bottom = 4
	_hint_button.add_theme_stylebox_override("normal", hint_btn_style)
	_hint_button.add_theme_stylebox_override("hover", hint_btn_style)
	_hint_button.add_theme_stylebox_override("pressed", hint_btn_style)

	var hint_center := CenterContainer.new()
	hint_center.layout_mode = 1
	hint_center.anchors_preset = Control.PRESET_FULL_RECT
	hint_center.anchor_right = 1.0
	hint_center.anchor_bottom = 1.0
	hint_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_button.add_child(hint_center)

	var hint_row := HBoxContainer.new()
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_theme_constant_override("separation", 6)
	hint_center.add_child(hint_row)

	var hint_icon := TextureRect.new()
	hint_icon.name = "HintIcon"
	hint_icon.custom_minimum_size = Vector2(18, 18)
	hint_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex := load("res://assets/icons/ui_lightbulb.svg") as Texture2D
	if icon_tex == null:
		icon_tex = load("res://assets/icons/ui_sparkles.svg") as Texture2D
	hint_icon.texture = icon_tex
	hint_icon.modulate = SandboxThemeTokens.GOLD_TITLE
	hint_row.add_child(hint_icon)

	var hint_text := Label.new()
	hint_text.name = "HintText"
	hint_text.text = "คำใบ้"
	hint_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_text.add_theme_color_override("font_color", SandboxThemeTokens.GOLD_TITLE)
	if _font_bold != null:
		hint_text.add_theme_font_override("font", _font_bold)
	hint_text.add_theme_font_size_override("font_size", 16)
	hint_row.add_child(hint_text)

	_hint_button.mouse_entered.connect(func():
		hint_icon.modulate = Color(1.0, 0.9, 0.5, 1.0)
		hint_text.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	)
	_hint_button.mouse_exited.connect(func():
		hint_icon.modulate = SandboxThemeTokens.GOLD_TITLE
		hint_text.add_theme_color_override("font_color", SandboxThemeTokens.GOLD_TITLE)
	)

	_hint_button.pressed.connect(_on_hint_pressed)
	header.add_child(_hint_button)

	_story_label = _make_label(20, SandboxThemeTokens.PRIMARY_TEXT, false)
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_story_label)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 5)
	root.add_child(_rows_box)

	_hint_label = _make_label(20, SandboxThemeTokens.GOLD_TITLE, false)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.visible = false
	root.add_child(_hint_label)

	_feedback_label = _make_label(20, DONE_COLOR, false)
	_feedback_label.visible = false
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_feedback_label)

	_complete_box = VBoxContainer.new()
	_complete_box.visible = false
	_complete_box.add_theme_constant_override("separation", 8)
	root.add_child(_complete_box)
	_complete_label = _make_label(22, DONE_COLOR, true)
	_complete_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_complete_box.add_child(_complete_label)
	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(0, 44)
	_continue_button.add_theme_font_size_override("font_size", 20)
	_continue_button.add_theme_stylebox_override("normal", _flat(Color(0.12, 0.42, 0.3, 0.96), 8))
	_continue_button.add_theme_stylebox_override("hover", _flat(Color(0.16, 0.54, 0.38, 1.0), 8))
	_continue_button.add_theme_stylebox_override("pressed", _flat(Color(0.1, 0.34, 0.24, 1.0), 8))
	if _font_bold != null:
		_continue_button.add_theme_font_override("font", _font_bold)
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	_complete_box.add_child(_continue_button)


func _build_row(text: String, done: bool, is_current: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var check := _CheckBox.new()
	check.done = done
	check.custom_minimum_size = Vector2(24, 24)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(check)
	var color := SandboxThemeTokens.TEXT_SECONDARY if done \
			else (SandboxThemeTokens.PRIMARY_TEXT if is_current else SandboxThemeTokens.TEXT_SECONDARY)
	var label := _make_label(20, color, is_current)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _on_hint_pressed() -> void:
	_hint_visible = not _hint_visible
	refresh()
	reset_size()


func _make_label(font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	var font := _font_bold if bold else _font_regular
	if font != null:
		label.add_theme_font_override("font", font)
	return label


static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8)
	return style


## ช่องติ๊กวาดเอง (วงกลม + ขีดถูก) ไม่พึ่งว่าฟอนต์มีอักขระ ✓
class _CheckBox extends Control:
	var done := false

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 1.0
		if done:
			draw_circle(center, radius, SandboxThemeTokens.PROMPT_GREEN)
			var tick := PackedVector2Array([
				center + Vector2(-radius * 0.45, 0.0),
				center + Vector2(-radius * 0.1, radius * 0.38),
				center + Vector2(radius * 0.5, -radius * 0.38)])
			draw_polyline(tick, Color(0.02, 0.06, 0.04), 2.5, true)
		else:
			draw_arc(center, radius, 0.0, TAU, 32, SandboxThemeTokens.CARD_BORDER, 2.0, true)
