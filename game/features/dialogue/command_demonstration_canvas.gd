class_name CommandDemonstrationCanvas
extends Control

## ผ้าใบแสดงผลจำลองคาถา Git (Clean & Minimal Spell Preview)
## ออกแบบให้เรียบง่าย สบายตา เด่นน้อยกว่า Terminal ในด่าน
## รองรับการต่อยอดทุกคำสั่งในรูปแบบเดียวกัน: คาถาที่ร่าย -> ผลลัพธ์ที่ได้ -> สถานะ

signal animation_started
signal animation_finished(command_name: String)

enum DisplayMode {
	VERSION_CHECK,
	CONFIG_REGISTRY,
	GIT_GRAPH,
}

var current_mode: DisplayMode = DisplayMode.VERSION_CHECK

# สถานะการจำลอง
var active_command: String = "git version"
var is_animating: bool = false
var anim_phase: int = 0 # 0 = Idle, 1 = Casting, 2 = Completed

var anim_time: float = 0.0

# สีโทนสงบ สบายตา (ไม่ฉูดฉาดเกิน Terminal)
const COLOR_PAGE_BG      := Color(0.06, 0.05, 0.11, 0.95)
const COLOR_HEADER_BG    := Color(0.11, 0.09, 0.18, 0.9)
const COLOR_BORDER       := Color(0.70, 0.58, 0.32, 0.6)
const COLOR_CARD_BG      := Color(0.04, 0.04, 0.08, 0.9)
const COLOR_CARD_BORDER  := Color(0.30, 0.35, 0.50, 0.5)
const COLOR_GOLD         := Color(0.92, 0.78, 0.42, 1.0)
const COLOR_CYAN         := Color(0.45, 0.80, 0.95, 1.0)
const COLOR_GREEN        := Color(0.35, 0.88, 0.60, 1.0)
const COLOR_WHITE        := Color(0.88, 0.90, 0.94, 1.0)
const COLOR_MUTED        := Color(0.55, 0.60, 0.70, 1.0)

# UI Nodes
var _root_vbox: VBoxContainer
var _header_panel: Panel
var _header_title: Label

var _center_container: CenterContainer
var _preview_card: PanelContainer
var _card_vbox: VBoxContainer
var _book_rect: TextureRect
var _status_header: Label
var _content_box: VBoxContainer

var _font_bold: Font
var _font_reg: Font
var _active_tween: Tween


func _ready() -> void:
	if ResourceLoader.exists("res://assets/fonts/ChakraPetch-Bold.ttf"):
		var base_bold: Font = load("res://assets/fonts/ChakraPetch-Bold.ttf")
		var fv_bold := FontVariation.new()
		fv_bold.base_font = base_bold
		fv_bold.spacing_top = 4
		fv_bold.spacing_bottom = 2
		_font_bold = fv_bold
	if ResourceLoader.exists("res://assets/fonts/ChakraPetch-Regular.ttf"):
		var base_reg: Font = load("res://assets/fonts/ChakraPetch-Regular.ttf")
		var fv_reg := FontVariation.new()
		fv_reg.base_font = base_reg
		fv_reg.spacing_top = 4
		fv_reg.spacing_bottom = 2
		_font_reg = fv_reg

	_build_ui()
	reset_animation()


func _process(delta: float) -> void:
	anim_time += delta
	# อนิเมชั่นคัมภีร์ลอยเบาๆ สบายตา
	if _book_rect != null:
		var float_y := sin(anim_time * 2.0) * 4.0
		_book_rect.position.y = float_y
		if is_animating:
			var pulse := 0.85 + 0.15 * sin(anim_time * 6.0)
			_book_rect.modulate = Color(pulse, pulse * 1.05, 1.0, 1.0)
		else:
			_book_rect.modulate = Color.WHITE


func _build_ui() -> void:
	_root_vbox = VBoxContainer.new()
	_root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_vbox.add_theme_constant_override("separation", 0)
	add_child(_root_vbox)

	# แถบหัวเรื่องเรียบง่าย
	_header_panel = Panel.new()
	_header_panel.custom_minimum_size = Vector2(0, 48)
	var hdr_style := StyleBoxFlat.new()
	hdr_style.bg_color = COLOR_HEADER_BG
	hdr_style.border_color = COLOR_BORDER * 0.5
	hdr_style.border_width_bottom = 1
	_header_panel.add_theme_stylebox_override("panel", hdr_style)
	_root_vbox.add_child(_header_panel)

	_header_title = Label.new()
	_header_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_title.text = "📖 ตัวอย่างการทำงานของคาถา (Spell Preview)"
	_header_title.add_theme_color_override("font_color", COLOR_GOLD)
	_header_title.add_theme_font_size_override("font_size", 20)
	if _font_bold:
		_header_title.add_theme_font_override("font", _font_bold)
	_header_panel.add_child(_header_title)

	# พื้นที่การ์ดสรุปผลมนตรา ขยายเต็มพื้นที่หน้าขวาอย่างสมดุล
	var card_margin := MarginContainer.new()
	card_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_margin.add_theme_constant_override("margin_left", 20)
	card_margin.add_theme_constant_override("margin_top", 16)
	card_margin.add_theme_constant_override("margin_right", 20)
	card_margin.add_theme_constant_override("margin_bottom", 16)
	_root_vbox.add_child(card_margin)

	# การ์ดสรุปผลมนตรา (Parchment Card)
	_preview_card = PanelContainer.new()
	_preview_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD_BG
	card_style.border_color = COLOR_CARD_BORDER
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.set_corner_radius_all(10)
	_preview_card.add_theme_stylebox_override("panel", card_style)
	card_margin.add_child(_preview_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	_preview_card.add_child(margin)

	_card_vbox = VBoxContainer.new()
	_card_vbox.add_theme_constant_override("separation", 18)
	margin.add_child(_card_vbox)

	# ส่วนบน: ไอคอนคัมภีร์เวทขนาดพอดี สวยงามและโดดเด่น
	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(0, 175)
	_card_vbox.add_child(icon_box)

	var icon_rel_holder := Control.new()
	icon_rel_holder.custom_minimum_size = Vector2(150, 150)
	icon_box.add_child(icon_rel_holder)

	_book_rect = TextureRect.new()
	if ResourceLoader.exists("res://assets/cutscene/props/khampri/Khampri.png"):
		_book_rect.texture = load("res://assets/cutscene/props/khampri/Khampri.png")
	_book_rect.custom_minimum_size = Vector2(150, 150)
	_book_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rel_holder.add_child(_book_rect)

	# หัวข้อสถานะ
	_status_header = _make_label("✦ รอการร่ายคาถาตัวอย่าง ✦", COLOR_GOLD, true, 26)
	_status_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_vbox.add_child(_status_header)

	var divider := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = COLOR_CARD_BORDER * 0.6
	divider.add_theme_stylebox_override("separator", sep_style)
	divider.add_theme_constant_override("separation", 10)
	_card_vbox.add_child(divider)

	# กล่องแสดงผล คาถา -> ผลลัพธ์ -> สถานะ
	_content_box = VBoxContainer.new()
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 16)
	_card_vbox.add_child(_content_box)


# ---- Public API ----

func set_mode(mode: DisplayMode) -> void:
	current_mode = mode
	reset_animation()


func reset_animation() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	is_animating = false
	anim_phase = 0

	match current_mode:
		DisplayMode.VERSION_CHECK:
			active_command = "git version"
			_header_title.text = "📖 ตัวอย่างการทำงาน: git version"
		DisplayMode.CONFIG_REGISTRY:
			active_command = "git config --global user.name \"Vel\""
			_header_title.text = "📖 ตัวอย่างการทำงาน: git config"
		DisplayMode.GIT_GRAPH:
			active_command = "git commit"
			_header_title.text = "📖 ตัวอย่างการทำงาน: git commit"

	_refresh_content_ui()


func simulate_command(cmd: String) -> void:
	if is_animating:
		return

	active_command = cmd
	is_animating = true
	anim_phase = 1
	animation_started.emit()

	_refresh_content_ui()

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.tween_interval(0.65) # ร่ายสั้นๆ กระชับ ไม่ยืดเยื้อ
	_active_tween.tween_callback(func() -> void:
		anim_phase = 2
		is_animating = false
		_refresh_content_ui()
		animation_finished.emit(cmd)
	)


# ---- Content UI ----

func _refresh_content_ui() -> void:
	if _content_box == null or _status_header == null:
		return

	for child in _content_box.get_children():
		child.queue_free()

	if anim_phase == 0:
		# สถานะ Idle: แนะนำสั้นๆ
		_status_header.text = "✦ รอการทดสอบคาถา ✦"
		_status_header.add_theme_color_override("font_color", COLOR_MUTED)

		var empty_lbl := _make_label("กดปุ่ม 'ทดสอบ' ทางด้านซ้าย\nเพื่อดูตัวอย่างผลลัพธ์ที่คำสั่งนี้จะแสดงออกมา", COLOR_MUTED, false, 22)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_box.add_child(empty_lbl)

	elif anim_phase == 1:
		# สถานะร่าย (Casting)
		_status_header.text = "⚡ กำลังทดสอบคำสั่ง..."
		_status_header.add_theme_color_override("font_color", COLOR_CYAN)

		var casting_lbl := _make_label("ร่ายคาถา: %s" % active_command, COLOR_CYAN, true, 24)
		casting_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_box.add_child(casting_lbl)

	elif anim_phase == 2:
		# สถานะผลลัพธ์ (Completed)
		_status_header.text = "✓ ผลลัพธ์ตัวอย่าง (Simulation Output)"
		_status_header.add_theme_color_override("font_color", COLOR_GREEN)

		if current_mode == DisplayMode.VERSION_CHECK:
			_add_preview_row("คาถาที่ร่าย :", active_command, COLOR_CYAN)
			_add_preview_row("ผลลัพธ์ที่ได้ :", "git version 2.40.1", COLOR_WHITE, true)
			_add_preview_row("ความหมาย :", "ตรวจพบ Git พร้อมใช้งานในระบบ", COLOR_GREEN)

		elif current_mode == DisplayMode.CONFIG_REGISTRY:
			_add_preview_row("คาถาที่ร่าย :", active_command, COLOR_CYAN)
			if active_command.contains("\"Vel\""):
				_add_preview_row("ผลลัพธ์ที่ได้ :", "(บันทึกสำเร็จ ไม่มี output ตามปกติของ Git)", COLOR_WHITE)
				_add_preview_row("ความหมาย :", "บันทึกนาม 'Vel' ลงในคัมภีร์เรียบร้อย", COLOR_GREEN)
			else:
				_add_preview_row("ผลลัพธ์ที่ได้ :", "Vel", COLOR_WHITE, true)
				_add_preview_row("ความหมาย :", "ตรวจสอบพบชื่อผู้ถือครอง: 'Vel'", COLOR_GREEN)

		# ข้อความส่งต่อเข้า Terminal แบบเรียบง่าย
		var cta_box := PanelContainer.new()
		var cta_style := StyleBoxFlat.new()
		cta_style.bg_color = Color(0.08, 0.12, 0.18, 0.8)
		cta_style.set_corner_radius_all(6)
		cta_style.content_margin_top = 12
		cta_style.content_margin_bottom = 12
		cta_style.content_margin_left = 16
		cta_style.content_margin_right = 16
		cta_box.add_theme_stylebox_override("panel", cta_style)
		_content_box.add_child(cta_box)

		var cta_lbl := _make_label("👉 พร้อมแล้ว เข้าสู่เทอร์มินัลเพื่อลองพิมพ์จริง", COLOR_WHITE, false, 20)
		cta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cta_box.add_child(cta_lbl)


func _add_preview_row(label_text: String, value_text: String, val_color: Color, bold_val: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var lbl := _make_label(label_text, COLOR_MUTED, false, 22)
	lbl.custom_minimum_size = Vector2(150, 0)
	row.add_child(lbl)

	var val := _make_label(value_text, val_color, bold_val, 24)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(val)

	_content_box.add_child(row)


func _make_label(text: String, color: Color, bold: bool, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	if bold and _font_bold:
		lbl.add_theme_font_override("font", _font_bold)
	elif _font_reg:
		lbl.add_theme_font_override("font", _font_reg)
	return lbl
