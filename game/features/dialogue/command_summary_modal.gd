class_name CommandSummaryModal
extends Control

## หน้าต่างคัมภีร์บันทึกมนตรา: สรุปคาถาประจำด่าน (Grimoire Spell Summary Modal)
## แสดงผลหลังจบบทสนทนาก่อนเข้าสู่เทอร์มินัลพิมพ์คำสั่งใน Sandbox
## ออกแบบในธีมหนังสือคัมภีร์เวทมนตร์ (Open Grimoire Book) แสดงผลเฉพาะเนื้อหาที่เกี่ยวข้องกับคำสั่งจริง

const CommandDemonstrationCanvas = preload("res://features/dialogue/command_demonstration_canvas.gd")

signal proceed_to_terminal(step: int)
signal modal_closed

@export var level_number: int = 1
@export var current_step: int = 1

# โหนด UI
@onready var dim_overlay: ColorRect = $DimOverlay
@onready var modal_panel: PanelContainer = $CenterContainer/ModalPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var close_btn: Button = %CloseButton

# ฝั่งซ้าย (หน้าซ้ายของคัมภีร์): คำอธิบายและสูตรการร่ายคาถา
@onready var step_badge: Label = %StepBadge
@onready var guide_rich_label: RichTextLabel = %GuideRichLabel
@onready var cast_command_btn: Button = %CastCommandButton
@onready var alt_command_btn: Button = %AltCommandButton
@onready var reset_anim_btn: Button = %ResetAnimationButton
@onready var outcome_panel: PanelContainer = %OutcomePanel
@onready var outcome_label: RichTextLabel = %OutcomeLabel

# ปุ่มนำทางด้านล่าง
@onready var nav_prev_btn: Button = %NavPrevButton
@onready var nav_next_btn: Button = %NavNextButton
@onready var page_indicator: Label = %PageIndicator
@onready var start_terminal_btn: Button = %StartTerminalButton

# ฝั่งขวา (หน้าขวาของคัมภีร์): ผ้าใบแสดงผลภาพเวทมนตร์
@onready var demo_canvas: CommandDemonstrationCanvas = %DemoCanvas

var slides: Array[Dictionary] = []
var current_slide_index: int = 0
var has_executed_current_slide: bool = false
var _is_closing: bool = false

# เสียงประกอบ
const SFX_CLICK_PATH := "res://assets/audio/sfx_click.wav"
const SFX_COMMAND_PATH := "res://assets/audio/sfx_command.wav"
const SFX_SUCCESS_PATH := "res://assets/audio/sfx_success.wav"


func _ready() -> void:
	_setup_slides()
	_wire_signals()
	_show_slide(0)
	_play_open_animation()


func _setup_slides() -> void:
	slides.clear()
	
	# โหลดสไลด์จากข้อมูลด่านถ้ามีนิยามไว้
	var custom_slides: Array = LevelDataLoader.get_demonstration_slides(level_number, current_step)
	if custom_slides.size() > 0:
		for s in custom_slides:
			if s is Dictionary:
				slides.append(s)
		return

	# ข้อมูลสำรอง
	if level_number == 1 and current_step == 1:
		slides.append({
			"title": "📖 คัมภีร์บันทึกมนตรา: ตรวจสอบระดับพลังเวท",
			"subtitle": "ด่านที่ 1 ขั้นที่ 1: git version / git --version",
			"badge": "✦ คาถาบทที่ 1: ตรวจสอบระดับพลังเวท",
			"guide_text": "ก่อนจะเริ่มร่ายเวทมนตร์ใดๆ นักเวทจำเป็นต้องตรวจสอบเสียก่อนว่า [b]พลังแห่ง Git[/b] ถูกติดตั้งและพร้อมตอบสนองต่อเจ้าหรือไม่\n\nในระบบ Git เจ้าสามารถเลือกพิมพ์คำสั่งนี้ได้ [b][color=#52e0ac]2 รูปแบบ[/color][/b] ซึ่งให้ผลลัพธ์เหมือนกันทุกประการ:\n\n1. [b][color=#73BFF2]git version[/color][/b] — แบบไม่มีขีดเลย พิมพ์ง่ายและสะดวกที่สุด\n2. [b][color=#73BFF2]git --version[/color][/b] — แบบมาตรฐานสากล (ต้องใช้ขีดคู่ [b]--[/b])\n\n[b]⚠️ ข้อควรระวัง:[/b]\n• หากเลือกใช้แบบมีขีด ต้องเป็น [b]ขีดคู่ --version[/b] เท่านั้น ห้ามใช้ขีดเดียว [color=#FF6666]-version[/color]\n• ต้องเว้นวรรคระหว่าง [b]git[/b] กับ [b]version[/b] เสมอ",
			"command": "git version",
			"alt_command": "git --version",
			"button_icon": "✨",
			"outcome_text": "[color=#52e0ac]✓ สัมผัสพลังเวทสำเร็จ:[/color] Git Version 2.40.1 พร้อมใช้งานในหอคอย",
			"mode": CommandDemonstrationCanvas.DisplayMode.VERSION_CHECK
		})
	elif level_number == 1 and current_step == 2:
		slides.append({
			"title": "📖 คัมภีร์บันทึกมนตรา: ประกาศนามและผูกตราประทับ",
			"subtitle": "ด่านที่ 1 ขั้นที่ 2: git config",
			"badge": "✦ คาถาบทที่ 2: ลงทะเบียนตัวตนของนักเวท (git config)",
			"guide_text": "ทุกครั้งที่นายจารึกการเปลี่ยนแปลงลงในคัมภีร์เวท สำนักเวทต้องรู้ก่อนว่าใครเป็นผู้จารึก เจ้าต้องประกาศตัวตนด้วยคาถา 2 บทนี้:\n\n1. [b]ประกาศนามนักเวท:[/b]\n   [color=#73BFF2]`git config --global user.name \"Vel\"`[/color]\n\n2. [b]ผูกตราประทับวิญญาณ:[/b]\n   [color=#73BFF2]`git config --global user.email \"vel@magic-tower.local\"`[/color]\n\n3. [b]ตรวจสอบนามที่ลงทะเบียนไว้:[/b]\n   [color=#73BFF2]`git config --global user.name`[/color]\n\n[b]⚠️ ข้อสังเกต:[/b] ตอนตั้งค่า Git จะไม่ตอบกลับข้อความใดๆ แต่เมื่อร่ายตรวจสอบโดยไม่ใส่ชื่อ Git จะตอบชื่อออกมา",
			"command": "git config --global user.name \"Vel\"",
			"alt_command": "git config --global user.name",
			"button_icon": "🔮",
			"outcome_text": "[color=#FFE680]ตราประทับวิญญาณพร้อมแล้ว![/color] หอคอยพร้อมจดจำตัวตนของเจ้า\nเข้าสู่เทอร์มินัลเพื่อร่ายคาถาประกาศนามและผูกตราประทับจริง",
			"mode": CommandDemonstrationCanvas.DisplayMode.CONFIG_REGISTRY
		})
	else:
		slides.append({
			"title": "📖 คัมภีร์บันทึกมนตรา: สรุปภารกิจ",
			"subtitle": "ด่านที่ %d ขั้นที่ %d" % [level_number, current_step],
			"badge": "✦ สรุปคาถาประจำขั้น",
			"guide_text": "ตรวจสอบคำสั่งที่จำเป็นต้องใช้ก่อนเริ่มร่ายคาถาจริงในเทอร์มินัล",
			"command": "git version",
			"button_icon": "✨",
			"outcome_text": "พร้อมสำหรับการฝึกฝนจริง",
			"mode": CommandDemonstrationCanvas.DisplayMode.VERSION_CHECK
		})


func _wire_signals() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	cast_command_btn.pressed.connect(_on_cast_command_pressed)
	if alt_command_btn != null:
		alt_command_btn.pressed.connect(_on_alt_command_pressed)
	reset_anim_btn.pressed.connect(_on_reset_animation_pressed)
	nav_prev_btn.pressed.connect(_on_prev_slide_pressed)
	nav_next_btn.pressed.connect(_on_next_slide_pressed)
	start_terminal_btn.pressed.connect(_on_start_terminal_pressed)
	
	if demo_canvas != null:
		demo_canvas.animation_finished.connect(_on_canvas_animation_finished)


func _show_slide(index: int) -> void:
	if index < 0 or index >= slides.size():
		return
	
	current_slide_index = index
	has_executed_current_slide = false
	var slide: Dictionary = slides[index]
	
	title_label.text = slide.get("title", "📖 คัมภีร์บันทึกมนตรา: สรุปคาถาประจำด่าน")
	if subtitle_label != null:
		var sub: String = slide.get("subtitle", "")
		if sub == "":
			sub = "ด่านที่ %d ขั้นที่ %d" % [level_number, current_step]
		subtitle_label.text = sub
		
	step_badge.text = slide.get("badge", "")
	guide_rich_label.text = slide.get("guide_text", "")
	
	var cmd: String = slide.get("command", "git version")
	var icon: String = slide.get("button_icon", "✨")
	cast_command_btn.text = "%s ทดสอบ %s" % [icon, cmd]
	cast_command_btn.disabled = false
	
	var alt_cmd: String = slide.get("alt_command", "")
	if alt_command_btn != null:
		if alt_cmd != "":
			alt_command_btn.visible = true
			alt_command_btn.text = "%s ทดสอบ %s" % [icon, alt_cmd]
			alt_command_btn.disabled = false
		else:
			alt_command_btn.visible = false
	
	outcome_label.text = slide.get("outcome_text", "")
	outcome_panel.visible = false
	outcome_panel.modulate.a = 0.0
	
	# อัปเดตปุ่มนำทาง
	page_indicator.text = "%d / %d" % [current_slide_index + 1, slides.size()]
	nav_prev_btn.disabled = (current_slide_index == 0)
	
	var is_last_slide: bool = (current_slide_index == slides.size() - 1)
	nav_next_btn.visible = not is_last_slide
	nav_next_btn.disabled = is_last_slide
	
	if slides.size() <= 1:
		nav_prev_btn.visible = false
		nav_next_btn.visible = false
		page_indicator.visible = false
	else:
		nav_prev_btn.visible = true
		nav_next_btn.visible = true
		page_indicator.visible = true
	
	start_terminal_btn.visible = true
	
	var mode_val = slide.get("mode", CommandDemonstrationCanvas.DisplayMode.VERSION_CHECK)
	var mode: CommandDemonstrationCanvas.DisplayMode = mode_val if mode_val is CommandDemonstrationCanvas.DisplayMode else CommandDemonstrationCanvas.DisplayMode.VERSION_CHECK
	demo_canvas.set_mode(mode)


func _on_cast_command_pressed() -> void:
	_play_sfx(SFX_COMMAND_PATH)
	has_executed_current_slide = true
	var slide: Dictionary = slides[current_slide_index]
	var cmd: String = slide.get("command", "git version")
	demo_canvas.simulate_command(cmd)


func _on_alt_command_pressed() -> void:
	_play_sfx(SFX_COMMAND_PATH)
	has_executed_current_slide = true
	var slide: Dictionary = slides[current_slide_index]
	var cmd: String = slide.get("alt_command", "git --version")
	demo_canvas.simulate_command(cmd)


func _on_canvas_animation_finished(_cmd_name: String) -> void:
	_play_sfx(SFX_SUCCESS_PATH)
	outcome_panel.visible = true
	var tw := create_tween()
	tw.tween_property(outcome_panel, "modulate:a", 1.0, 0.35)


func _on_reset_animation_pressed() -> void:
	_play_sfx(SFX_CLICK_PATH)
	has_executed_current_slide = false
	outcome_panel.visible = false
	outcome_panel.modulate.a = 0.0
	demo_canvas.reset_animation()


func _on_prev_slide_pressed() -> void:
	if current_slide_index > 0:
		_play_sfx(SFX_CLICK_PATH)
		_show_slide(current_slide_index - 1)


func _on_next_slide_pressed() -> void:
	if current_slide_index < slides.size() - 1:
		_play_sfx(SFX_CLICK_PATH)
		_show_slide(current_slide_index + 1)


func _on_start_terminal_pressed() -> void:
	_play_sfx(SFX_CLICK_PATH)
	_close_and_proceed()


func _on_close_pressed() -> void:
	_play_sfx(SFX_CLICK_PATH)
	_close_and_proceed()


func _close_and_proceed() -> void:
	if _is_closing:
		return
	_is_closing = true
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property(modal_panel, "scale", Vector2(0.9, 0.9), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(modal_panel, "modulate:a", 0.0, 0.2)
	tw.tween_property(dim_overlay, "modulate:a", 0.0, 0.25)
	
	tw.chain().tween_callback(func() -> void:
		proceed_to_terminal.emit(current_step)
		modal_closed.emit()
		queue_free()
	)


func _play_open_animation() -> void:
	dim_overlay.modulate.a = 0.0
	modal_panel.modulate.a = 0.0
	modal_panel.scale = Vector2(0.88, 0.88)
	modal_panel.pivot_offset = modal_panel.size * 0.5
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim_overlay, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
