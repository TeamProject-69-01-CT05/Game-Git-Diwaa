extends Node2D

## ตัวควบคุมและแสดงผลบทสนทนาประจำด่าน (Level Dialogue View)
## รองรับบทสนทนา ด่าน 1 ถึง ด่าน 15 แบบแยกไฟล์ข้อมูล (Data-driven)
##
## วิธีใช้งาน:
## - กำหนด @export var level_number: int เพื่อเลือกด่านที่ต้องการเล่น (ค่าเริ่มต้น: 1)
## - สคริปต์จะโหลดข้อมูลจาก res://features/dialogue/levels/level_%02d.gd มาแสดงผลอัตโนมัติ
## - รองรับ Typewriter Effect, BBCode ไฮไลต์โค้ดสไตล์ Markdown, ช้อยส์ในกล่องข้อความเดิม,
##   เล่นบทสนทนาต่อเนื่องจนจบ (ยังไม่มีหน้าเล่นจริงของด่าน) แล้วบันทึกผ่านด่านและกลับหน้าเลือกด่าน

@export var level_number: int = 1
@export var next_scene_path: String = "res://features/start/start_view.tscn"
@export var play_entrance_cutscene: bool = false
@export var fade_in_from_black: bool = false
@export_enum("Intro & Part 1", "Part 2", "Outro") var debug_phase: int = 0

const LEVEL_SELECT_PATH := "res://features/level_select/level_select_view.tscn"
## ฉากเวลเดินขึ้นบันไดแล้วเปิดหน้าต่างดาว เล่นหลังผ่านด่าน (ปุ่มในหน้าต่างดาวพากลับหน้าเลือกด่านเอง)
## หน้า Sandbox ที่ใช้เป็นขั้นเล่นจริงของด่าน (แสดงแผงภารกิจตามขั้นที่ตั้งไว้ใน GameProgressManager)
const SANDBOX_SCENE_PATH := "res://features/sandbox/sandbox_game_view.tscn"
const LEVEL_CLEAR_SCENE_PATH := "res://features/cutscene/level_clear_scene.tscn"
const COMMAND_SUMMARY_MODAL_PATH := "res://features/dialogue/command_summary_modal.tscn"

# Animation & Visuals
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D
@onready var background: Sprite2D = $Background
@onready var atmosphere: ColorRect = $Atmosphere
@onready var fade_overlay: ColorRect = $MagicStoryUI/FadeOverlay

# Characters
@onready var stage: Node2D = $Stage
@onready var vel: AnimatedSprite2D = $Stage/Vel
@onready var exclamation_mark: Node2D = $Stage/Vel/ExclamationMark
@onready var question_mark: Node2D = $Stage/Vel/QuestionMark
@onready var mewla: AnimatedSprite2D = $Stage/Mewla

# UI Elements
@onready var magic_ui: CanvasLayer = $MagicStoryUI
@onready var dialogue_box: PanelContainer = $MagicStoryUI/DialogueBox
@onready var speaker_label: Label = $MagicStoryUI/DialogueBox/Margin/VBox/SpeakerLabel
@onready var dialogue_label: RichTextLabel = $MagicStoryUI/DialogueBox/Margin/VBox/DialogueLabel
@onready var continue_arrow: TextureRect = $MagicStoryUI/DialogueBox/ArrowOverlay/ArrowWrapper/ContinueArrow
@onready var arrow_wrapper: Control = $MagicStoryUI/DialogueBox/ArrowOverlay/ArrowWrapper

# Choice System Elements (Floating Slots with Active Glow)
const DBOX_NORMAL_WIDTH: float = 1160.0
const DBOX_NORMAL_OFFSET_RIGHT: float = 580.0
const DBOX_SHRUNK_WIDTH: float = 960.0
const DBOX_SHRUNK_OFFSET_RIGHT: float = 380.0

const CHOICE_CONTAINER_X: float = 1352.0
const CHOICE_CONTAINER_WIDTH: float = 528.0
const CHOICE_SLOT_HEIGHT: float = 56.0
const CHOICE_SLOT_SEPARATION: int = 8
const CHOICE_BOTTOM_Y: float = 1044.0

var dbox_shrink_tween: Tween = null
var is_dbox_shrunk: bool = false

var choice_slots_container: VBoxContainer = null
var choice_buttons: Array[Button] = []
var active_choices: Array = []
var is_showing_choices: bool = false
var active_choice_id: String = ""
var current_menu_id: String = ""
var is_choice_sliding_out: bool = false
var asked_choice_ids: Dictionary = {}
var active_glow_tween: Tween = null
var slot_pop_tween: Tween = null
var choice_slide_tween: Tween = null
var bad_ending_panel: Control = null
var is_bad_ending_typing: bool = false
var is_bad_ending_waiting: bool = false
var bad_ending_tween: Tween = null
var bad_ending_pulse_tween: Tween = null
var bad_ending_line1: Label = null
var bad_ending_line2: Label = null
var bad_ending_btn: Button = null

const BAD_END_LINE1: String = "เศษเสี้ยวที่กระจัดกระจายและใครบางคน... ยังคงรอคอยอยู่ในความมืดมิด"
const BAD_END_LINE2: String = "ขณะที่เวลเดินพ้นประตูหอคอยไป ทิ้งทุกคำตอบไว้เบื้องหลังตลอดกาล"

# Navigation Arrows (ซ้าย-ขวา) & History
var nav_arrows_container: HBoxContainer = null
var btn_arrow_back: TextureButton = null
var btn_arrow_next: TextureButton = null
var btn_back: TextureButton = null
var sequence_history: Array[Dictionary] = []
var press_tween_back: Tween = null
var press_tween_next: Tween = null

static var _cached_arrow_left_tex: ImageTexture = null
static var _cached_arrow_right_tex: ImageTexture = null
static var _cached_silver_cursor_tex: ImageTexture = null
static var _cached_empty_cursor_tex: ImageTexture = null

# Data & Queue
var level_data: Dictionary = {}
var current_queue: Array = []
var queue_index: int = 0

var is_dialogue_active: bool = false
var is_typing: bool = false
var is_transitioning: bool = false
var is_fast_forwarding: bool = false
var skip_ctrl = null
var font_ta8bit: Font = null
var font_chakra_bold: Font = null
var font_chakra_regular: Font = null
var font_choice_regular: FontVariation = null

# Speaker Focus & Inactive Character Dimming (สีเทาเมื่อไม่ได้พูด)
const CHAR_ACTIVE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const CHAR_INACTIVE_COLOR := Color(0.5, 0.5, 0.5, 1.0)
var char_dim_tween_vel: Tween = null
var char_dim_tween_mewla: Tween = null

# Animation Sequence
const VEL_IDLE_SEQ: Array[String] = ["breathe", "breathe_blink", "breathe", "breathe", "breathe_blink"]
var vel_seq_step: int = 0

# Cutscene Tweens & States
var entrance_tween: Tween = null
var stand_tween: Tween = null
var warp_tween: Tween = null
var reaction_tween: Tween = null
var hop_tween: Tween = null
var open_box_tween: Tween = null
var intro_box_tween: Tween = null
var is_in_entrance_cutscene: bool = false

var typewriter_tween: Tween = null
var question_tween: Tween = null
var exclamation_tween: Tween = null
var arrow_tween: Tween = null

# บทสนทนาสำหรับช่วงคัตซีนเปิดตัวพบมิวราครั้งแรก (5 ประโยค)
const INTRO_DIALOGUES: Array[Dictionary] = [
	{
		"speaker": "มิวรา",
		"text": "ยินดีต้อนรับสู่กิลด์แห่งหอคอยเวท",
		"mewla_anim": "talk"
	},
	{
		"speaker": "เวล",
		"text": "เธอคือ...",
		"emote": "question",
		"mewla_anim": "idle"
	},
	{
		"speaker": "มิวรา",
		"text": "“แมวไง เห็นก็รู้ปะ” ฉันมิวรา ผู้ดูแลกิลด์\nและเป็นคนที่จะสอนนายตั้งแต่พื้นฐาน",
		"mewla_anim": "talk"
	},
	{
		"speaker": "มิวรา",
		"text": "ก่อนเข้าสู่บททดสอบของหอคอย\nนายต้องตรวจสอบว่าพลังเวทของตัวเองพร้อมใช้งานหรือยัง",
		"mewla_anim": "talk"
	},
	{
		"speaker": "มิวรา",
		"text": "มาเริ่มคาถาแรกกัน",
		"mewla_anim": "success"
	}
]

func _ready() -> void:
	if ResourceLoader.exists("res://assets/fonts/TA-8-bit.ttf"):
		font_ta8bit = load("res://assets/fonts/TA-8-bit.ttf")
	if ResourceLoader.exists("res://assets/fonts/ChakraPetch-Bold.ttf"):
		font_chakra_bold = load("res://assets/fonts/ChakraPetch-Bold.ttf")
	if ResourceLoader.exists("res://assets/fonts/ChakraPetch-Regular.ttf"):
		font_chakra_regular = load("res://assets/fonts/ChakraPetch-Regular.ttf")
		var choice_font_var = FontVariation.new()
		choice_font_var.base_font = font_chakra_regular
		choice_font_var.spacing_top = 4
		choice_font_var.spacing_bottom = 2
		font_choice_regular = choice_font_var
		
	# สร้าง Choice Slots Container บน MagicStoryUI อยู่ทางขวาข้างกรอบ DialogueBox
	choice_slots_container = VBoxContainer.new()
	choice_slots_container.name = "ChoiceSlotsContainer"
	choice_slots_container.visible = false
	choice_slots_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	choice_slots_container.add_theme_constant_override("separation", CHOICE_SLOT_SEPARATION)
	choice_slots_container.z_index = 5
	magic_ui.add_child(choice_slots_container)
		
	camera.position = Vector2(960, 540)
	continue_arrow.visible = false
	if arrow_wrapper:
		arrow_wrapper.visible = false
	_create_nav_arrows()
	exclamation_mark.visible = false
	question_mark.visible = false
	exclamation_mark.scale = Vector2.ONE
	exclamation_mark.position = Vector2(0, -42)
	question_mark.scale = Vector2.ONE
	question_mark.position = Vector2(0, -36)
	
	if anim_player.has_animation("background_loop"):
		anim_player.play("background_loop")
		
	# ปุ่มเร่งความเร็ว และปุ่มข้าม
	skip_ctrl = preload("res://features/cutscene/skip_cutscene_button.gd").new()
	skip_ctrl.next_scene_path = next_scene_path
	skip_ctrl.custom_skip_action = _on_skip_step
	add_child(skip_ctrl)
	
	# โหลดหน้าเลือกด่านรอไว้ล่วงหน้าใน Background Thread เพื่อกลับไปได้ทันทีเมื่อจบบทสนทนา
	SceneLoader.request_preload(LEVEL_SELECT_PATH)
	SceneLoader.request_preload(LEVEL_CLEAR_SCENE_PATH)
	SceneLoader.request_preload(SANDBOX_SCENE_PATH)
	SceneLoader.request_preload(COMMAND_SUMMARY_MODAL_PATH)
	
	# ตรวจสอบด่านที่เลือกจาก Level Select
	var selected_lvl := GameProgressManager.get_selected_level_number()
	if selected_lvl > 0:
		level_number = selected_lvl
		
	# โหลดข้อมูลด่าน
	_load_level_data(level_number)

	# กลับมาจากขั้นเล่นจริงใน Sandbox -> เล่นบทสนทนาช่วงถัดไปต่อทันที (ไม่ซ้ำคัตซีนเดินเข้า)
	var resume_phase := GameProgressManager.consume_resume_dialogue_phase()
	if resume_phase >= 0:
		debug_phase = resume_phase
		play_entrance_cutscene = false
		fade_in_from_black = true
	else:
		GameProgressManager.clear_level_timer(level_number)
	
	if play_entrance_cutscene:
		# เริ่มต้นในโหมดคัตซีนเดินเข้าห้องโถง
		is_in_entrance_cutscene = true
		fade_overlay.visible = true
		fade_overlay.color = Color(0, 0, 0, 1)
		dialogue_box.visible = false
		
		vel.position = Vector2(-120, 680)
		vel.scale = Vector2(4, 4)
		vel.play("walk")
		if not vel.animation_looped.is_connected(_on_vel_animation_looped):
			vel.animation_looped.connect(_on_vel_animation_looped)
		
		mewla.visible = false
		mewla.position = Vector2(1220, 680)
		mewla.scale = Vector2.ZERO
		mewla.modulate = Color(1, 1, 1, 0)
		
		_start_entrance_cutscene()
	else:
		# เริ่มต้นในโหมดบทสนทนาด่านทันที (ไม่เล่นคัตซีนเดินเข้า)
		is_in_entrance_cutscene = false
		fade_overlay.visible = fade_in_from_black
		fade_overlay.color = Color(0, 0, 0, 1) if fade_in_from_black else Color(0, 0, 0, 0)
		dialogue_box.visible = true
		dialogue_box.modulate.a = 1.0
		
		vel.position = Vector2(700, 680)
		vel.scale = Vector2(4, 4)
		vel.play("breathe")
		if not vel.animation_looped.is_connected(_on_vel_animation_looped):
			vel.animation_looped.connect(_on_vel_animation_looped)
		
		mewla.visible = true
		mewla.position = Vector2(1220, 680)
		mewla.scale = Vector2(4, 4)
		mewla.modulate = Color.WHITE
		mewla.play("idle")
		
		_start_dialogue_scene()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	SceneLoader.flush_preloads()
	is_bad_ending_typing = false
	is_bad_ending_waiting = false
	_stop_active_slot_glow()
	if slot_pop_tween and slot_pop_tween.is_valid():
		slot_pop_tween.kill()
		slot_pop_tween = null
	if bad_ending_tween and bad_ending_tween.is_valid():
		bad_ending_tween.kill()
		bad_ending_tween = null
	if bad_ending_pulse_tween and bad_ending_pulse_tween.is_valid():
		bad_ending_pulse_tween.kill()
		bad_ending_pulse_tween = null
	if choice_slide_tween and choice_slide_tween.is_valid():
		choice_slide_tween.kill()
		choice_slide_tween = null
	if dbox_shrink_tween and dbox_shrink_tween.is_valid():
		dbox_shrink_tween.kill()
		dbox_shrink_tween = null
	if entrance_tween and entrance_tween.is_valid():
		entrance_tween.kill()
		entrance_tween = null
	if stand_tween and stand_tween.is_valid():
		stand_tween.kill()
		stand_tween = null
	if warp_tween and warp_tween.is_valid():
		warp_tween.kill()
		warp_tween = null
	if reaction_tween and reaction_tween.is_valid():
		reaction_tween.kill()
		reaction_tween = null
	if hop_tween and hop_tween.is_valid():
		hop_tween.kill()
		hop_tween = null
	if open_box_tween and open_box_tween.is_valid():
		open_box_tween.kill()
		open_box_tween = null
	if intro_box_tween and intro_box_tween.is_valid():
		intro_box_tween.kill()
		intro_box_tween = null
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
		typewriter_tween = null
	if question_tween and question_tween.is_valid():
		question_tween.kill()
		question_tween = null
	if exclamation_tween and exclamation_tween.is_valid():
		exclamation_tween.kill()
		exclamation_tween = null
	if arrow_tween and arrow_tween.is_valid():
		arrow_tween.kill()
		arrow_tween = null
	if press_tween_back and press_tween_back.is_valid():
		press_tween_back.kill()
		press_tween_back = null
	if press_tween_next and press_tween_next.is_valid():
		press_tween_next.kill()
		press_tween_next = null
	if char_dim_tween_vel and char_dim_tween_vel.is_valid():
		char_dim_tween_vel.kill()
		char_dim_tween_vel = null
	if char_dim_tween_mewla and char_dim_tween_mewla.is_valid():
		char_dim_tween_mewla.kill()
		char_dim_tween_mewla = null
	_clear_cached_textures()
	SceneLoader.flush_preloads()

static func _clear_cached_textures() -> void:
	_cached_arrow_left_tex = null
	_cached_arrow_right_tex = null
	_cached_silver_cursor_tex = null
	_cached_empty_cursor_tex = null
	_cached_question_frame_tex = null
	_cached_question_frame_active_tex = null

func _process(_delta: float) -> void:
	if is_transitioning:
		if is_fast_forwarding:
			is_fast_forwarding = false
			Engine.time_scale = 1.0
		return
	
	var is_btn_active: bool = (skip_ctrl != null and skip_ctrl.is_fast_forward)
	var wants_hold: bool = Input.is_key_pressed(KEY_SHIFT)
	
	var active: bool = is_btn_active or wants_hold
	if active != is_fast_forwarding:
		is_fast_forwarding = active
		Engine.time_scale = 2.5 if active else 1.0
		if skip_ctrl and not is_btn_active:
			skip_ctrl._apply_ff_style(active)

func _input(event: InputEvent) -> void:
	if is_bad_ending_typing:
		if event.is_action_pressed("ui_accept") or \
		   (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)) or \
		   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			_skip_bad_ending_typewriter()
			return
	elif is_bad_ending_waiting:
		if event.is_action_pressed("ui_accept") or \
		   (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)) or \
		   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			_on_bad_ending_exit()
			return
		
	if is_transitioning:
		return
		
	# กดปุ่ม Left Arrow หรือ Backspace เพื่อย้อนกลับข้อความ (พร้อมเอฟเฟกต์ปุ่มยุบและสว่างขาว)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_BACKSPACE:
			if (is_dialogue_active or is_showing_choices) and _can_go_back():
				get_viewport().set_input_as_handled()
				_animate_button_press(btn_arrow_back)
				_on_player_back()
				return
		
	# การเลือกช้อยส์ด้วยแป้นตัวเลข 1, 2, 3, 4
	if is_showing_choices:
		if event is InputEventKey and event.pressed and not event.echo:
			var idx := -1
			if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
				idx = 0
			elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
				idx = 1
			elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
				idx = 2
			elif event.keycode == KEY_4 or event.keycode == KEY_KP_4:
				idx = 3
				
			if idx >= 0 and idx < active_choices.size():
				get_viewport().set_input_as_handled()
				_on_choice_selected(idx)
				return
		return
		
	# คลิกหรือกด Space/Enter/Right Arrow เพื่อไปต่อ (พร้อมเอฟเฟกต์ปุ่มยุบและสว่างขาว)
	if is_dialogue_active:
		var wants_advance: bool = false
		if event.is_action_pressed("ui_accept"):
			wants_advance = true
		elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_RIGHT):
			wants_advance = true
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var hovered := get_viewport().gui_get_hovered_control()
			if not (hovered is BaseButton):
				wants_advance = true
				
		if wants_advance:
			get_viewport().set_input_as_handled()
			_animate_button_press(btn_arrow_next)
			_on_player_advance()

# ==============================================================================
# DATA LOADER & BBCODE FORMATTER
# ==============================================================================

func _load_level_data(num: int) -> void:
	level_data = LevelDataLoader.load_data(num)
	if not level_data.is_empty():
		return
		
	push_warning("[LevelDialogueView] Data file not found for level %d at %s. Using fallback." % [num, LevelDataLoader.get_level_path(num)])
	level_data = {
		"title": "ด่านที่ %d" % num,
		"is_fallback": true,
		"intro_sequence": [
			{"speaker": "มิวรา", "text": "ยินดีต้อนรับสู่ด่านที่ %d (ยังไม่มีข้อมูลบทเรียน)" % num, "mewla_anim": "talk"},
			{"speaker": "เวล", "text": "ดูเหมือนด่านนี้กำลังอยู่ระหว่างการพัฒนา", "mewla_anim": "idle"}
		]
	}

func _highlight_code_syntax(code: String) -> String:
	var parts := code.split(" ")
	var styled_parts: Array[String] = []
	for p in parts:
		if p in ["git", "config"]:
			styled_parts.append("[color=#70d6ff]%s[/color]" % p) # Sky Cyan คีย์เวิร์ด
		elif p.begins_with("-"):
			styled_parts.append("[color=#5fffe0]%s[/color]" % p) # Neon Pastel Mint อักขระ/แฟล็ก
		elif p.begins_with("\"") or p.ends_with("\""):
			styled_parts.append("[color=#ffd166]%s[/color]" % p) # Soft Gold ข้อความสตริง
		else:
			styled_parts.append("[color=#f8fafc]%s[/color]" % p) # Bright White ตัวระบุชื่อ
	return " ".join(styled_parts)

func _format_bbcode(raw: String) -> String:
	var result := raw
	# แปลง Markdown `code` เป็นโค้ดสไตล์บล็อกโปรแกรมมิ่ง (High-Contrast Neon Mint / Sky Cyan Badge)
	var regex := RegEx.new()
	if regex.compile("`([^`]+)`") == OK:
		var matches := regex.search_all(result)
		for i in range(matches.size() - 1, -1, -1):
			var m = matches[i]
			var inner = m.get_string(1)
			var highlighted = _highlight_code_syntax(inner)
			var replacement = "[bgcolor=#14192b] %s [/bgcolor]" % highlighted
			result = result.left(m.get_start()) + replacement + result.substr(m.get_end())
	return result

func _start_dialogue_scene() -> void:
	_begin_dialogue_phase()
	if fade_in_from_black:
		var fade_in = create_tween()
		fade_in.tween_property(fade_overlay, "color:a", 0.0, 0.4)

func _begin_dialogue_phase(phase: int = -1) -> void:
	if phase >= 0:
		debug_phase = phase
	_stop_active_slot_glow()
	if slot_pop_tween and slot_pop_tween.is_valid():
		slot_pop_tween.kill()
	active_choice_id = ""
	is_showing_choices = false
	is_choice_sliding_out = false
	if is_instance_valid(choice_slots_container):
		choice_slots_container.visible = false
	dialogue_box.visible = true
	dialogue_box.modulate.a = 1.0
	if debug_phase == 1:
		_load_sequence(level_data.get("part2_intro_sequence", []))
	elif debug_phase == 2:
		_load_sequence(level_data.get("outro_sequence", []))
	else:
		_load_sequence(level_data.get("intro_sequence", []))

# ==============================================================================
# ENTRANCE CUTSCENE (เดินเข้าห้องโถง & พบมิวราก่อนเริ่มบทเรียน)
# ==============================================================================

func _start_entrance_cutscene() -> void:
	# 1. เฟดสว่างเข้ามา
	var fade_in = create_tween()
	fade_in.tween_property(fade_overlay, "color:a", 0.0, 0.8)
	
	# 2. เวลเดินเข้ามาจากทางซ้าย (-120 -> 700) ใน 3.6 วินาที
	entrance_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	entrance_tween.tween_property(vel, "position:x", 700.0, 3.6)
	entrance_tween.tween_callback(func():
		vel_seq_step = 0
		vel.play("breathe")
		vel.set_frame_and_progress(0, 0.0)
		
		if stand_tween and stand_tween.is_valid():
			stand_tween.kill()
		stand_tween = create_tween()
		stand_tween.tween_interval(1.0)
		stand_tween.tween_callback(func():
			if not is_transitioning:
				_warp_in_mewla_and_shock_vel()
		)
	)

func _warp_in_mewla_and_shock_vel() -> void:
	if is_transitioning:
		return
		
	mewla.visible = true
	mewla.scale = Vector2(4.0, 4.0)
	mewla.position = Vector2(1220.0, 655.0)
	mewla.modulate = Color(1.0, 1.0, 1.0, 0.0)
	mewla.play("idle")
	
	if warp_tween and warp_tween.is_valid():
		warp_tween.kill()
	warp_tween = create_tween().set_parallel(true)
	warp_tween.tween_property(mewla, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	warp_tween.tween_property(mewla, "position:y", 680.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if reaction_tween and reaction_tween.is_valid():
		reaction_tween.kill()
	reaction_tween = create_tween()
	reaction_tween.tween_interval(0.35)
	reaction_tween.tween_callback(func():
		if is_transitioning:
			return
		_trigger_vel_shock_jump()
	)

func _trigger_vel_shock_jump() -> void:
	if is_transitioning:
		return
		
	vel.play("shock")
	_start_exclamation_jump()
	
	if hop_tween and hop_tween.is_valid():
		hop_tween.kill()
		
	var vel_shadow = vel.get_node_or_null("DropShadow")
	hop_tween = create_tween()
	hop_tween.tween_property(vel, "position:y", 610.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if vel_shadow:
		hop_tween.parallel().tween_property(vel_shadow, "scale", Vector2(0.45, 0.30), 0.42)
		hop_tween.parallel().tween_property(vel_shadow, "position:y", 38.5 + (680.0 - 610.0), 0.42)
		hop_tween.parallel().tween_property(vel_shadow, "modulate:a", 0.4, 0.42)
		
	hop_tween.chain().tween_property(vel, "position:y", 680.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if vel_shadow:
		hop_tween.parallel().tween_property(vel_shadow, "scale", Vector2(0.65, 0.45), 0.36)
		hop_tween.parallel().tween_property(vel_shadow, "position:y", 38.5, 0.36)
		hop_tween.parallel().tween_property(vel_shadow, "modulate:a", 1.0, 0.36)
		
	hop_tween.chain().tween_callback(func():
		_hide_exclamation_landing()
		vel_seq_step = 0
		vel.play("breathe")
		vel.set_frame_and_progress(0, 0.0)
	)
	
	if open_box_tween and open_box_tween.is_valid():
		open_box_tween.kill()
	open_box_tween = create_tween()
	open_box_tween.tween_interval(0.42 + 0.36 + 0.65)
	open_box_tween.tween_callback(func():
		if not is_transitioning:
			_open_dialogue_box_for_intro()
	)

func _open_dialogue_box_for_intro() -> void:
	if is_transitioning:
		return
	if is_instance_valid(dialogue_box):
		dialogue_box.offset_right = DBOX_NORMAL_OFFSET_RIGHT
		dialogue_box.custom_minimum_size.x = DBOX_NORMAL_WIDTH
		is_dbox_shrunk = false
	dialogue_box.visible = true
	dialogue_box.modulate.a = 0.0
	
	if intro_box_tween and intro_box_tween.is_valid():
		intro_box_tween.kill()
	intro_box_tween = create_tween()
	intro_box_tween.tween_property(dialogue_box, "modulate:a", 1.0, 0.25)
	intro_box_tween.tween_callback(func():
		# ถ้าผู้เล่นกดข้ามระหว่างกล่องข้อความกำลังเฟดเข้า จะไม่โหลดบทนำทับบทเรียน
		if is_transitioning or not is_in_entrance_cutscene:
			return
		_load_sequence(INTRO_DIALOGUES)
	)

func _start_exclamation_jump() -> void:
	if exclamation_tween and exclamation_tween.is_valid():
		exclamation_tween.kill()
		
	exclamation_mark.visible = true
	exclamation_mark.scale = Vector2.ZERO
	exclamation_mark.position = Vector2(0, -42)
	exclamation_mark.modulate.a = 1.0
	
	exclamation_tween = create_tween()
	exclamation_tween.tween_property(exclamation_mark, "scale", Vector2(1.15, 1.15), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	exclamation_tween.parallel().tween_property(exclamation_mark, "position:y", -52.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exclamation_tween.chain().tween_property(exclamation_mark, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	exclamation_tween.parallel().tween_property(exclamation_mark, "position:y", -42.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _hide_exclamation_landing() -> void:
	if exclamation_tween and exclamation_tween.is_valid():
		exclamation_tween.kill()
	if not is_instance_valid(exclamation_mark):
		return
	exclamation_tween = create_tween().set_parallel(true)
	exclamation_tween.tween_property(exclamation_mark, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exclamation_tween.tween_property(exclamation_mark, "modulate:a", 0.0, 0.15)
	exclamation_tween.chain().tween_callback(func():
		if is_instance_valid(exclamation_mark):
			exclamation_mark.visible = false
			exclamation_mark.position = Vector2(0, -42)
	)

func _hide_exclamation() -> void:
	if exclamation_tween and exclamation_tween.is_valid():
		exclamation_tween.kill()
	if is_instance_valid(exclamation_mark):
		exclamation_mark.visible = false
		exclamation_mark.scale = Vector2.ZERO
		exclamation_mark.position = Vector2(0, -42)

func _on_skip_step() -> void:
	if is_transitioning:
		return
		
	# หยุด Tween และการเคลื่อนไหวทั้งหมดที่กำลังเล่นอยู่
	if entrance_tween and entrance_tween.is_valid(): entrance_tween.kill()
	if stand_tween and stand_tween.is_valid(): stand_tween.kill()
	if warp_tween and warp_tween.is_valid(): warp_tween.kill()
	if reaction_tween and reaction_tween.is_valid(): reaction_tween.kill()
	if hop_tween and hop_tween.is_valid(): hop_tween.kill()
	if open_box_tween and open_box_tween.is_valid(): open_box_tween.kill()
	if intro_box_tween and intro_box_tween.is_valid(): intro_box_tween.kill()
	if typewriter_tween and typewriter_tween.is_valid(): typewriter_tween.kill()
	if char_dim_tween_vel and char_dim_tween_vel.is_valid(): char_dim_tween_vel.kill()
	if char_dim_tween_mewla and char_dim_tween_mewla.is_valid(): char_dim_tween_mewla.kill()
	vel.self_modulate = CHAR_ACTIVE_COLOR
	mewla.self_modulate = CHAR_ACTIVE_COLOR
	
	_hide_exclamation()
	_hide_question_mark()
	_hide_continue_arrow()
	_stop_active_slot_glow()
	if slot_pop_tween and slot_pop_tween.is_valid():
		slot_pop_tween.kill()
	active_choice_id = ""
	is_showing_choices = false
	is_choice_sliding_out = false
	if is_instance_valid(choice_slots_container):
		choice_slots_container.visible = false
	
	if is_in_entrance_cutscene:
		is_in_entrance_cutscene = false
		fade_overlay.color.a = 0.0
		fade_overlay.visible = false
		vel.position = Vector2(700, 680)
		vel.scale = Vector2(4, 4)
		vel.play("breathe")
		mewla.visible = true
		mewla.position = Vector2(1220, 680)
		mewla.scale = Vector2(4, 4)
		mewla.modulate = Color.WHITE
		mewla.play("idle")
		_begin_dialogue_phase(0)
		return
	
	# ด่านที่ยังไม่มีข้อมูลบทเรียน (fallback) ไม่มีขั้นเล่นจริง -> กลับหน้าเลือกด่านโดยไม่บันทึกผ่านด่าน
	if level_data.get("is_fallback", false):
		_finish_dialogue_stage(false)
		return
	
	# กดข้าม -> ข้ามไปบทสนทนาช่วงถัดไป เหมือนกดคุยไปต่อเรื่อยๆ จนจบช่วงนั้น
	if debug_phase == 0:
		_open_gameplay_step(1)
		return
	elif debug_phase == 1:
		_open_gameplay_step(2)
		return
	elif debug_phase == 2:
		var is_fallback: bool = level_data.get("is_fallback", false)
		_finish_dialogue_stage(not is_fallback)
		return
		
	_finish_dialogue_stage(false)

func _open_dialogue_box() -> void:
	if is_transitioning:
		return
	if is_instance_valid(dialogue_box):
		dialogue_box.offset_right = DBOX_NORMAL_OFFSET_RIGHT
		dialogue_box.custom_minimum_size.x = DBOX_NORMAL_WIDTH
		is_dbox_shrunk = false
	dialogue_box.visible = true
	dialogue_box.modulate.a = 0.0
	var box_tween = create_tween()
	box_tween.tween_property(dialogue_box, "modulate:a", 1.0, 0.25)

func _load_sequence(seq: Array, record_history: bool = true) -> void:
	if record_history and current_queue.size() > 0:
		var last_idx = mini(queue_index, current_queue.size() - 1)
		sequence_history.append({
			"queue": current_queue,
			"index": last_idx,
			"is_showing_choices": is_showing_choices,
			"is_in_entrance_cutscene": is_in_entrance_cutscene
		})
	current_queue = seq
	queue_index = 0
	_show_current_queue_item()

func _show_current_queue_item(skip_typewriter: bool = false) -> void:
	if queue_index >= current_queue.size():
		if is_in_entrance_cutscene:
			# จบบทนำ 5 ประโยคของคัตซีน -> ไหลเข้าสู่บทสอนด่าน 1 ในซีนเดิมทันที ไร้รอยต่อ 100%
			# บันทึก history ขณะยังอยู่ในโหมดคัตซีน เพื่อให้กดย้อนกลับมาแล้วไปต่อได้ถูกต้อง
			sequence_history.append({
				"queue": current_queue,
				"index": current_queue.size() - 1,
				"is_showing_choices": false,
				"is_in_entrance_cutscene": true
			})
			is_in_entrance_cutscene = false
			_load_sequence(level_data.get("intro_sequence", []), false)
			return
		# บันทึกผ่านด่านเฉพาะเมื่อเล่น outro_sequence จบสมบูรณ์ (หรือ debug_phase == 2) และไม่ใช่ข้อมูล fallback
		var is_fallback: bool = level_data.get("is_fallback", false)
		var is_outro: bool = not is_fallback and ((current_queue == level_data.get("outro_sequence", [])) or (debug_phase == 2))
		_finish_dialogue_stage(is_outro)
		return
		
	var item = current_queue[queue_index]
	if item.has("type"):
		var type = item["type"]
		if type == "choice_menu":
			var target_menu = item.get("menu", "")
			var intro_q = level_data.get("intro_sequence", [])
			var part2_q = level_data.get("part2_intro_sequence", [])
			var is_returning_from_sub = (current_queue != intro_q and current_queue != part2_q)
			
			var is_main_target: bool = (target_menu == "part1_main" or target_menu == "part2_main" or target_menu.ends_with("_main"))
			if is_returning_from_sub and sequence_history.size() > 0 and is_main_target:
				while sequence_history.size() > 0 and current_queue != intro_q and current_queue != part2_q:
					var parent_state = sequence_history.pop_back()
					current_queue = parent_state.get("queue", current_queue)
					queue_index = parent_state.get("index", queue_index)
					if parent_state.has("is_in_entrance_cutscene"):
						is_in_entrance_cutscene = parent_state["is_in_entrance_cutscene"]
			var is_returning_to_main = is_returning_from_sub and is_main_target
			_display_choice_menu(target_menu, not is_returning_to_main)
			return
		elif type == "goto":
			var target_seq = item.get("target", "")
			if target_seq != "" and level_data.has(target_seq):
				_load_sequence(level_data[target_seq])
			return
		elif type == "open_gameplay":
			var step = item.get("step", 1)
			_open_gameplay_step(step)
			return
		elif type == "bad_ending":
			_trigger_bad_ending()
			return
			
	_show_single_dialogue(item, skip_typewriter)

func _update_choice_slots_layout(choice_count: int) -> void:
	if not is_instance_valid(choice_slots_container):
		return
	var count = maxi(1, choice_count)
	var total_h: float = float(count) * CHOICE_SLOT_HEIGHT + float(count - 1) * float(CHOICE_SLOT_SEPARATION)
	var bottom_y: float = CHOICE_BOTTOM_Y
	if is_instance_valid(dialogue_box) and dialogue_box.visible:
		var dbox_bottom: float = dialogue_box.position.y + dialogue_box.size.y
		if dbox_bottom > 500.0:
			bottom_y = dbox_bottom
	var target_y: float = bottom_y - total_h
	
	choice_slots_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	choice_slots_container.custom_minimum_size = Vector2(CHOICE_CONTAINER_WIDTH, total_h)
	choice_slots_container.size = Vector2(CHOICE_CONTAINER_WIDTH, total_h)
	choice_slots_container.position = Vector2(CHOICE_CONTAINER_X, target_y)

func _show_single_dialogue(data: Dictionary, skip_typewriter: bool = false) -> void:
	is_showing_choices = false
	if active_choice_id.is_empty():
		if is_instance_valid(choice_slots_container) and not is_choice_sliding_out:
			choice_slots_container.visible = false
		if is_dbox_shrunk:
			_expand_dialogue_box()
	else:
		if is_instance_valid(choice_slots_container):
			choice_slots_container.visible = true
			_update_choice_slots_layout(choice_buttons.size())
	dialogue_label.visible = true
	speaker_label.visible = true
	is_dialogue_active = true
	_hide_continue_arrow()
	
	speaker_label.text = data["speaker"]
	dialogue_label.text = _format_bbcode(data["text"])
	
	# ปรับสีตัวละคร: ผู้พูดสีปกติ ตัวละครไม่พูดใส่สีเทา
	_update_speaker_dim(data["speaker"], skip_typewriter)
	
	# สีชื่อผู้พูด
	var target_mewla_anim = data.get("mewla_anim", "talk")
	if data["speaker"] == "มิวรา":
		speaker_label.add_theme_color_override("font_color", Color(0.92, 0.80, 0.44, 1.0))
		if mewla.animation != target_mewla_anim:
			mewla.play(target_mewla_anim)
			mewla.set_frame_and_progress(vel.frame, vel.frame_progress)
	else:
		speaker_label.add_theme_color_override("font_color", Color(0.45, 0.75, 0.95, 1.0))
		if mewla.animation != "idle":
			mewla.play("idle")
			mewla.set_frame_and_progress(vel.frame, vel.frame_progress)
		
	if vel.animation not in VEL_IDLE_SEQ:
		vel.play(VEL_IDLE_SEQ[vel_seq_step])
		vel.set_frame_and_progress(mewla.frame, mewla.frame_progress)
		
	var emote = data.get("emote", "")
	if emote == "question":
		_pop_question_mark()
	else:
		_hide_question_mark()
		
	var sfx_path = data.get("sfx", "")
	if sfx_path != "" and ResourceLoader.exists(sfx_path):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load(sfx_path)
		sfx.finished.connect(sfx.queue_free)
		add_child(sfx)
		sfx.play()
		
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
		
	if skip_typewriter:
		is_typing = false
		dialogue_label.visible_ratio = 1.0
		_show_continue_arrow()
	else:
		is_typing = true
		dialogue_label.visible_ratio = 0.0
		var duration: float = clampf(float(data["text"].length()) * 0.035, 0.4, 1.6)
		typewriter_tween = create_tween()
		typewriter_tween.tween_property(dialogue_label, "visible_ratio", 1.0, duration)
		typewriter_tween.tween_callback(func():
			is_typing = false
			_show_continue_arrow()
		)
		
	_update_back_button_state()

func _update_speaker_dim(speaker: String, immediate: bool = false) -> void:
	if not is_instance_valid(vel) or not is_instance_valid(mewla):
		return
	if not mewla.visible:
		vel.self_modulate = CHAR_ACTIVE_COLOR
		return
		
	var is_mewla_speaking: bool = (speaker == "มิวรา")
	var is_vel_speaking: bool = (speaker == "เวล" or (!is_mewla_speaking and speaker != ""))
	
	var target_vel_color: Color = CHAR_ACTIVE_COLOR if is_vel_speaking else (CHAR_INACTIVE_COLOR if is_mewla_speaking else CHAR_ACTIVE_COLOR)
	var target_mewla_color: Color = CHAR_ACTIVE_COLOR if is_mewla_speaking else (CHAR_INACTIVE_COLOR if is_vel_speaking else CHAR_ACTIVE_COLOR)
	
	if immediate:
		if char_dim_tween_vel and char_dim_tween_vel.is_valid():
			char_dim_tween_vel.kill()
		if char_dim_tween_mewla and char_dim_tween_mewla.is_valid():
			char_dim_tween_mewla.kill()
		vel.self_modulate = target_vel_color
		mewla.self_modulate = target_mewla_color
	else:
		if vel.self_modulate != target_vel_color:
			if char_dim_tween_vel and char_dim_tween_vel.is_valid():
				char_dim_tween_vel.kill()
			char_dim_tween_vel = create_tween()
			char_dim_tween_vel.tween_property(vel, "self_modulate", target_vel_color, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
		if mewla.self_modulate != target_mewla_color:
			if char_dim_tween_mewla and char_dim_tween_mewla.is_valid():
				char_dim_tween_mewla.kill()
			char_dim_tween_mewla = create_tween()
			char_dim_tween_mewla.tween_property(mewla, "self_modulate", target_mewla_color, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_player_advance() -> void:
	if is_choice_sliding_out:
		return
	if is_typing:
		if typewriter_tween and typewriter_tween.is_valid():
			typewriter_tween.kill()
		dialogue_label.visible_ratio = 1.0
		is_typing = false
		_show_continue_arrow()
		return
		
	if is_dialogue_active and not is_showing_choices:
		queue_index += 1
		_show_current_queue_item()

# ==============================================================================
# CHOICE SYSTEM (GOTHIC DARK FANTASY RPG PIXEL ART UI)
# ==============================================================================

static func _get_silver_arrow_texture() -> ImageTexture:
	if _cached_silver_cursor_tex != null:
		return _cached_silver_cursor_tex
	var w := 14
	var h := 14
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var c_border := Color(0.08, 0.05, 0.12, 1.0) # deep plum-black border
	var c_highlight := Color(0.96, 0.95, 1.0, 1.0) # crisp white-silver
	var c_silver := Color(0.80, 0.76, 0.88, 1.0) # pale silver
	var c_shadow := Color(0.55, 0.50, 0.65, 1.0) # muted slate-silver
	
	var arrow_rows: Array = [
		[1, 2, 4],
		[2, 2, 6],
		[3, 2, 7],
		[4, 2, 9],
		[5, 2, 10],
		[6, 2, 11],
		[7, 2, 12],
		[8, 2, 11],
		[9, 2, 10],
		[10, 2, 9],
		[11, 2, 7],
		[12, 2, 6],
		[13, 2, 4]
	]
	
	for row in arrow_rows:
		var y: int = row[0]
		var x_start: int = row[1]
		var x_end: int = row[2]
		for x in range(x_start, x_end + 1):
			if x == x_start or x == x_end or y == 1 or y == 13:
				img.set_pixel(x, y, c_border)
			elif y <= 6:
				img.set_pixel(x, y, c_highlight if x == x_end - 1 else c_silver)
			else:
				img.set_pixel(x, y, c_shadow if x == x_start + 1 else c_silver)
				
	_cached_silver_cursor_tex = ImageTexture.create_from_image(img)
	return _cached_silver_cursor_tex

static func _get_empty_arrow_texture() -> ImageTexture:
	if _cached_empty_cursor_tex != null:
		return _cached_empty_cursor_tex
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_cached_empty_cursor_tex = ImageTexture.create_from_image(img)
	return _cached_empty_cursor_tex

static var _cached_question_frame_tex: Texture2D = null

static func _get_question_frame_texture() -> Texture2D:
	if _cached_question_frame_tex != null:
		return _cached_question_frame_tex
	const PATH = "res://assets/cutscene/frame dialog text/dialog-question1.png"
	if ResourceLoader.exists(PATH):
		_cached_question_frame_tex = load(PATH)
	if not _cached_question_frame_tex:
		var global_path = ProjectSettings.globalize_path(PATH)
		if FileAccess.file_exists(global_path):
			var img = Image.new()
			if img.load(global_path) == OK:
				_cached_question_frame_tex = ImageTexture.create_from_image(img)
	return _cached_question_frame_tex

static var _cached_question_frame_active_tex: Texture2D = null

static func _get_question_frame_active_texture() -> Texture2D:
	if _cached_question_frame_active_tex != null:
		return _cached_question_frame_active_tex
	const PATH = "res://assets/cutscene/frame dialog text/dialog-question1-active.png"
	if ResourceLoader.exists(PATH):
		_cached_question_frame_active_tex = load(PATH)
	if not _cached_question_frame_active_tex:
		var global_path = ProjectSettings.globalize_path(PATH)
		if FileAccess.file_exists(global_path):
			var img = Image.new()
			if img.load(global_path) == OK:
				_cached_question_frame_active_tex = ImageTexture.create_from_image(img)
	if not _cached_question_frame_active_tex:
		var base_tex = _get_question_frame_texture()
		if base_tex:
			var img = base_tex.get_image().duplicate()
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					var c = img.get_pixel(x, y)
					if c.a > 0.2:
						if abs(c.r - 0.54) < 0.15 and abs(c.g - 0.49) < 0.15 and abs(c.b - 0.58) < 0.15:
							img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
			_cached_question_frame_active_tex = ImageTexture.create_from_image(img)
	return _cached_question_frame_active_tex

func _create_slot_texture_stylebox(mod_color: Color = Color.WHITE) -> StyleBox:
	var tex = _get_question_frame_texture()
	if tex:
		var sb = StyleBoxTexture.new()
		sb.texture = tex
		sb.region_rect = Rect2(5, 17, 468, 81)
		sb.texture_margin_left = 32.0
		sb.texture_margin_right = 32.0
		sb.texture_margin_top = 18.0
		sb.texture_margin_bottom = 18.0
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.content_margin_left = 32.0
		sb.content_margin_right = 24.0
		sb.content_margin_top = 8.0
		sb.content_margin_bottom = 8.0
		sb.modulate_color = mod_color
		return sb
		
	var fallback_sb = StyleBoxFlat.new()
	fallback_sb.bg_color = Color(0.12, 0.08, 0.18, 0.92)
	fallback_sb.border_width_left = 2
	fallback_sb.border_width_right = 2
	fallback_sb.border_width_top = 2
	fallback_sb.border_width_bottom = 2
	fallback_sb.border_color = Color(0.45, 0.35, 0.58, 0.95)
	fallback_sb.set_corner_radius_all(3)
	fallback_sb.content_margin_left = 28.0
	fallback_sb.content_margin_right = 24.0
	fallback_sb.content_margin_top = 8.0
	fallback_sb.content_margin_bottom = 8.0
	return fallback_sb

func _create_slot_active_stylebox(mod_color: Color = Color.WHITE) -> StyleBox:
	var tex = _get_question_frame_active_texture()
	if tex:
		var sb = StyleBoxTexture.new()
		sb.texture = tex
		sb.region_rect = Rect2(5, 17, 468, 81)
		sb.texture_margin_left = 32.0
		sb.texture_margin_right = 32.0
		sb.texture_margin_top = 18.0
		sb.texture_margin_bottom = 18.0
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.content_margin_left = 32.0
		sb.content_margin_right = 24.0
		sb.content_margin_top = 8.0
		sb.content_margin_bottom = 8.0
		sb.modulate_color = mod_color
		return sb
	return _create_slot_texture_stylebox(Color(1.3, 1.3, 1.35, 1.0))

func _on_choice_hover(btn: Button, is_hover: bool) -> void:
	if not is_instance_valid(btn) or btn.disabled or not is_showing_choices:
		return
	if is_hover:
		btn.icon = _get_silver_arrow_texture()
	elif not btn.has_focus():
		btn.icon = _get_empty_arrow_texture()

func _on_choice_focus(btn: Button, is_focus: bool) -> void:
	if not is_instance_valid(btn) or btn.disabled or not is_showing_choices:
		return
	if is_focus:
		btn.icon = _get_silver_arrow_texture()
	elif not btn.is_hovered():
		btn.icon = _get_empty_arrow_texture()

func _stop_active_slot_glow() -> void:
	if active_glow_tween and active_glow_tween.is_valid():
		active_glow_tween.kill()
		active_glow_tween = null

func _apply_active_slot_glow(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	_stop_active_slot_glow()
	
	# สล็อตที่เลือก: ใช้กรอบ Texture ที่มีเส้นขอบสีขาวตรงตามรูปทรงกรอบเป๊ะๆ ไม่ใช้กล่องสี่เหลี่ยมคลุม และไม่ใช้เงาฟุ้ง
	var active_sb = _create_slot_active_stylebox()
	btn.add_theme_stylebox_override("normal", active_sb)
	btn.add_theme_stylebox_override("hover", active_sb)
	btn.add_theme_stylebox_override("pressed", active_sb)
	btn.add_theme_stylebox_override("focus", active_sb)
	btn.add_theme_stylebox_override("disabled", active_sb)
	
	btn.modulate = Color.WHITE
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.icon = _get_silver_arrow_texture()
	
	# พัลส์ความสว่างเบาๆ บนตัวเส้นขอบของกรอบโดยตรง (ไม่ใช้เงาฟุ้ง)
	active_glow_tween = create_tween().set_loops()
	active_glow_tween.tween_property(btn, "modulate", Color(1.20, 1.20, 1.25, 1.0), 0.70).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_glow_tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.70).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _setup_slot_button_styles(btn: Button, is_disabled: bool = false) -> void:
	if is_disabled:
		var dis_sb = _create_slot_texture_stylebox(Color(0.40, 0.38, 0.45, 0.60))
		btn.add_theme_stylebox_override("normal", dis_sb)
		btn.add_theme_stylebox_override("disabled", dis_sb)
		btn.add_theme_color_override("font_disabled_color", Color(0.50, 0.48, 0.55, 1.0))
		return
		
	# ทุกข้อความรวมถึง "ฉันจะลองดู" ใช้สไตล์สีเดียวกันทั้งหมด (อ่านซ้ำได้เรื่อยๆ ไม่เช็คว่าเคยอ่านแล้ว)
	var normal_sb = _create_slot_texture_stylebox(Color(1.0, 1.0, 1.0, 1.0))
	var hover_sb = _create_slot_active_stylebox(Color(1.0, 1.0, 1.0, 1.0))
	var pressed_sb = _create_slot_active_stylebox(Color(1.15, 1.15, 1.20, 1.0))
	
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	
	btn.add_theme_color_override("font_color", Color(0.94, 0.92, 0.96, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))

func _shrink_dialogue_box() -> void:
	if not is_instance_valid(dialogue_box):
		return
	if is_dbox_shrunk and dialogue_box.offset_right == DBOX_SHRUNK_OFFSET_RIGHT:
		return
	is_dbox_shrunk = true
	if dbox_shrink_tween and dbox_shrink_tween.is_valid():
		dbox_shrink_tween.kill()
	dialogue_box.custom_minimum_size.x = 0.0
	dbox_shrink_tween = create_tween()
	dbox_shrink_tween.tween_property(dialogue_box, "offset_right", DBOX_SHRUNK_OFFSET_RIGHT, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dbox_shrink_tween.chain().tween_callback(func():
		if is_instance_valid(dialogue_box):
			dialogue_box.custom_minimum_size.x = DBOX_SHRUNK_WIDTH
	)

func _expand_dialogue_box() -> void:
	if not is_instance_valid(dialogue_box):
		return
	if not is_dbox_shrunk and dialogue_box.offset_right == DBOX_NORMAL_OFFSET_RIGHT:
		return
	is_dbox_shrunk = false
	if dbox_shrink_tween and dbox_shrink_tween.is_valid():
		dbox_shrink_tween.kill()
	dialogue_box.custom_minimum_size.x = 0.0
	dbox_shrink_tween = create_tween()
	dbox_shrink_tween.tween_property(dialogue_box, "offset_right", DBOX_NORMAL_OFFSET_RIGHT, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dbox_shrink_tween.chain().tween_callback(func():
		if is_instance_valid(dialogue_box):
			dialogue_box.custom_minimum_size.x = DBOX_NORMAL_WIDTH
	)

func _animate_choices_exit(on_finished: Callable = Callable()) -> void:
	_stop_active_slot_glow()
	if slot_pop_tween and slot_pop_tween.is_valid():
		slot_pop_tween.kill()
		slot_pop_tween = null
	if choice_slide_tween and choice_slide_tween.is_valid():
		choice_slide_tween.kill()
		choice_slide_tween = null
		
	is_choice_sliding_out = true
	
	var valid_buttons: Array[Button] = []
	for b in choice_buttons:
		if is_instance_valid(b) and b.is_inside_tree() and b.visible:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.focus_mode = Control.FOCUS_NONE
			valid_buttons.append(b)
			
	if valid_buttons.is_empty():
		is_choice_sliding_out = false
		if is_instance_valid(choice_slots_container):
			choice_slots_container.visible = false
		if on_finished.is_valid():
			on_finished.call()
		return
		
	# ทุกช้อยส์สไลด์ออกพร้อมกันจากซ้ายไปขวา (X: 0.0 -> 160.0) พร้อมเฟดจางหายไป
	choice_slide_tween = create_tween().set_parallel(true)
	for b in valid_buttons:
		choice_slide_tween.tween_property(b, "position:x", 160.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		choice_slide_tween.tween_property(b, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	choice_slide_tween.chain().tween_callback(func():
		is_choice_sliding_out = false
		if is_instance_valid(choice_slots_container):
			choice_slots_container.visible = false
		if on_finished.is_valid():
			on_finished.call()
	)

func _display_choice_menu(menu_id: String, animate_entrance: bool = true) -> void:
	if choice_slide_tween and choice_slide_tween.is_valid():
		choice_slide_tween.kill()
		choice_slide_tween = null
	is_choice_sliding_out = false

	# หากมีช้อยส์เดิมแสดงอยู่ และเปลี่ยนเป็นเมนูใหม่ (เช่น เปลี่ยนเป็น ใช่ / ไม่)
	# ให้สไลด์ช้อยส์เดิมออกพร้อมกันจากซ้ายไปขวาก่อน แล้วจึงโหลดช้อยส์ใหม่สไลด์เข้าจากขวาไปซ้าย
	if current_menu_id != "" and current_menu_id != menu_id and is_instance_valid(choice_slots_container) and choice_slots_container.visible and choice_buttons.size() > 0:
		_animate_choices_exit(func():
			_display_choice_menu(menu_id, true)
		)
		return

	# ย่อกรอบบทสนทนาเข้ามารับกับช้อยส์
	_shrink_dialogue_box()

	var can_reuse_existing_slots: bool = (
		current_menu_id == menu_id
		and is_instance_valid(choice_slots_container)
		and choice_slots_container.visible
		and choice_buttons.size() > 0
	)

	# กรณีวนกลับมาคำถามเดิมหลังจากอ่านคำตอบจบ หรือกดย้อนกลับมาจากคำถามเดิม: ไม่ต้องสร้างปุ่มใหม่และไม่ต้องเล่นอนิเมชั่น ให้คืนค่าปุ่มเดิมที่มีอยู่บนจอทันที
	if can_reuse_existing_slots:
		_stop_active_slot_glow()
		active_choice_id = ""
		is_showing_choices = true
		is_dialogue_active = false
		is_typing = false
		_hide_continue_arrow()
		_hide_question_mark()
		
		var menu_key = "%s_choices" % menu_id
		var menu_info = level_data.get(menu_key, {})
		var prompt_text: String = menu_info.get("prompt", "")
		dialogue_label.visible = true
		
		if prompt_text.begins_with("เลือกข้อมูลที่ต้องการตรวจสอบก่อนเริ่มภารกิจ") or prompt_text == "ตัวเลือกคำถาม" or prompt_text.is_empty():
			speaker_label.visible = false
			speaker_label.text = ""
			dialogue_label.text = "\nเลือกข้อมูลที่ต้องการตรวจสอบก่อนเริ่มภารกิจ"
		else:
			speaker_label.visible = true
			speaker_label.text = "มิวรา"
			speaker_label.add_theme_color_override("font_color", Color(0.92, 0.80, 0.44, 1.0))
			dialogue_label.text = prompt_text
		dialogue_label.visible_ratio = 1.0
		_update_speaker_dim(speaker_label.text if speaker_label.visible else "", false)
		
		for b in choice_buttons:
			if is_instance_valid(b):
				_setup_slot_button_styles(b, b.disabled)
				b.icon = _get_empty_arrow_texture()
				b.position.x = 0.0
				b.modulate.a = 1.0
				if not b.disabled:
					b.mouse_filter = Control.MOUSE_FILTER_STOP
					b.focus_mode = Control.FOCUS_ALL
				var tw = create_tween()
				tw.tween_property(b, "modulate", Color.WHITE, 0.20)
				
		_update_choice_slots_layout(choice_buttons.size())
		_update_nav_arrows()
		return

	current_menu_id = menu_id
	_stop_active_slot_glow()
	active_choice_id = ""
	is_showing_choices = true
	is_dialogue_active = false
	is_typing = false
	_hide_continue_arrow()
	_hide_question_mark()
	
	if not choice_slots_container:
		return
		
	is_choice_sliding_out = false
	for c in choice_slots_container.get_children():
		choice_slots_container.remove_child(c)
		c.queue_free()
	choice_buttons.clear()
	active_choices = []
	
	var menu_key = "%s_choices" % menu_id
	var menu_info = level_data.get(menu_key, {})
	var raw_options = menu_info.get("options", [])
	active_choices = raw_options.duplicate(true)
	
	# แสดงข้อความใน DialogueBox ด้านล่าง
	var prompt_text: String = menu_info.get("prompt", "")
	dialogue_label.visible = true
	
	if prompt_text.begins_with("เลือกข้อมูลที่ต้องการตรวจสอบก่อนเริ่มภารกิจ") or prompt_text == "ตัวเลือกคำถาม" or prompt_text.is_empty():
		speaker_label.visible = false
		speaker_label.text = ""
		dialogue_label.text = "\nเลือกข้อมูลที่ต้องการตรวจสอบก่อนเริ่มภารกิจ"
	else:
		speaker_label.visible = true
		speaker_label.text = "มิวรา"
		speaker_label.add_theme_color_override("font_color", Color(0.92, 0.80, 0.44, 1.0))
		dialogue_label.text = prompt_text
		
	dialogue_label.visible_ratio = 1.0
	_update_speaker_dim(speaker_label.text if speaker_label.visible else "", false)
	
	# วางตำแหน่งช้อยส์ที่มุมล่างขวา ข้างกรอบ DialogueBox
	_update_choice_slots_layout(active_choices.size())
	choice_slots_container.modulate.a = 1.0
	choice_slots_container.visible = true
	
	if not can_reuse_existing_slots:
		animate_entrance = true

	if slot_pop_tween and slot_pop_tween.is_valid():
		slot_pop_tween.kill()
	slot_pop_tween = null
	if animate_entrance:
		slot_pop_tween = create_tween()
	
	var num_strip_regex = RegEx.new()
	num_strip_regex.compile("^\\s*\\d+[.)]\\s*")
	
	for i in range(active_choices.size()):
		var choice = active_choices[i]
		var choice_id = choice.get("id", "")
		var raw_text: String = choice["text"]
		var clean_text: String = num_strip_regex.sub(raw_text, "")
		var is_disabled: bool = choice.get("disabled", false)
		
		# Slot Item Wrapper Control เพื่อให้สามารถสไลด์ position.x ได้อิสระโดยไม่ถูก VBoxContainer บังคับพิกัด
		var slot_wrapper = Control.new()
		slot_wrapper.custom_minimum_size = Vector2(CHOICE_CONTAINER_WIDTH, CHOICE_SLOT_HEIGHT)
		slot_wrapper.size = Vector2(CHOICE_CONTAINER_WIDTH, CHOICE_SLOT_HEIGHT)
		slot_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE if is_disabled else Control.FOCUS_ALL
		btn.disabled = is_disabled
		btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_disabled else Control.CURSOR_POINTING_HAND
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(CHOICE_CONTAINER_WIDTH, CHOICE_SLOT_HEIGHT)
		btn.size = Vector2(CHOICE_CONTAINER_WIDTH, CHOICE_SLOT_HEIGHT)
		
		# ข้อความบนปุ่ม (ทุกปุ่มรวมถึง "ฉันจะลองดู" ใช้ข้อความรูปแบบเดียวกัน ไม่อิงประวัติเคยอ่าน)
		btn.text = clean_text
		btn.icon = _get_empty_arrow_texture()
		btn.expand_icon = false
		btn.add_theme_constant_override("h_separation", 12)
		
		if font_choice_regular:
			btn.add_theme_font_override("font", font_choice_regular)
			btn.add_theme_font_size_override("font_size", 20)
		elif font_chakra_regular:
			btn.add_theme_font_override("font", font_chakra_regular)
			btn.add_theme_font_size_override("font_size", 20)
		elif font_chakra_bold:
			btn.add_theme_font_override("font", font_chakra_bold)
			btn.add_theme_font_size_override("font_size", 20)
		elif font_ta8bit:
			btn.add_theme_font_override("font", font_ta8bit)
			btn.add_theme_font_size_override("font_size", 19)
			
		# กำหนด StyleBox ตาม Texture กรอบที่คุณวาด
		_setup_slot_button_styles(btn, is_disabled)
		
		if not is_disabled:
			btn.mouse_entered.connect(_on_choice_hover.bind(btn, true))
			btn.mouse_exited.connect(_on_choice_hover.bind(btn, false))
			btn.focus_entered.connect(_on_choice_focus.bind(btn, true))
			btn.focus_exited.connect(_on_choice_focus.bind(btn, false))
			btn.pressed.connect(_on_choice_selected.bind(i))
				
		slot_wrapper.add_child(btn)
		choice_slots_container.add_child(slot_wrapper)
		choice_buttons.append(btn)
		
		if animate_entrance and slot_pop_tween:
			# Animation ค่อยๆ เฟดเข้าและสไลด์จาก ขวาไปซ้าย ทีละอัน
			btn.position.x = 120.0
			btn.modulate.a = 0.0
			
			var delay: float = float(i) * 0.08
			slot_pop_tween.parallel().tween_property(btn, "position:x", 0.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)
			slot_pop_tween.parallel().tween_property(btn, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(delay)
		else:
			btn.position.x = 0.0
			btn.modulate.a = 1.0
		
	# ตอนเปิดเมนูครั้งแรก ไม่เลือกหรือไฮไลต์ข้อไหนก่อน ให้ผู้เล่นเลือกเองอย่างเป็นธรรมชาติ
	for b in choice_buttons:
		b.icon = _get_empty_arrow_texture()
		
	_update_nav_arrows()

func _on_choice_selected(index: int) -> void:
	if index < 0 or index >= active_choices.size():
		return
	var choice = active_choices[index]
	if choice.get("disabled", false):
		return
		
	if slot_pop_tween and slot_pop_tween.is_valid():
		slot_pop_tween.kill()
		slot_pop_tween = null
	if choice_slide_tween and choice_slide_tween.is_valid():
		choice_slide_tween.kill()
		choice_slide_tween = null
		
	var choice_id = choice.get("id", "")
	var seq_key = "%s_seq" % choice_id
	var seq = level_data.get(seq_key, [])
	
	var is_yes_no = (current_menu_id == "part1_purpose_sub" or choice_id == "purpose_yes" or choice_id == "purpose_no")
	var is_action_choice = choice_id.ends_with("_try") or (seq.size() > 0 and seq[0].get("type") == "open_gameplay")
	var is_question = not is_yes_no and not is_action_choice
	
	# ถ้าผู้เล่นคลิกเลือกก่อนที่อนิเมชั่นเลื่อนเข้าจะเล่นจบ (slot_pop_tween ถูกขัดจังหวะ)
	# ให้ปรับพิกัดปุ่มทุกปุ่มเข้าที่ x = 0.0 ให้เรียบร้อย ไม่ให้ค้างเยื้องกลางอากาศ
	var needs_align_tween: bool = false
	if is_question:
		for b in choice_buttons:
			if is_instance_valid(b) and absf(b.position.x) > 0.5:
				needs_align_tween = true
				break
				
	if needs_align_tween:
		slot_pop_tween = create_tween().set_parallel(true)
		for b in choice_buttons:
			if is_instance_valid(b):
				b.modulate.a = 1.0
				if absf(b.position.x) > 0.5:
					slot_pop_tween.tween_property(b, "position:x", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				else:
					b.position.x = 0.0
	else:
		for b in choice_buttons:
			if is_instance_valid(b):
				b.position.x = 0.0
				b.modulate.a = 1.0
	
	if is_question:
		# กรณีเป็นคำถามปกติ (ไม่ใช่ ใช่/ไม่ และไม่ใช่ ฉันจะลองดู):
		# ให้คำถามยังคงอยู่บนหน้าจอ โดยไฮไลต์คำถามที่เลือก และหรี่ตัวเลือกอื่น พร้อมปิดรับการคลิก
		active_choice_id = choice_id
		is_showing_choices = false
		is_choice_sliding_out = false
		
		if index < choice_buttons.size():
			var chosen_btn = choice_buttons[index]
			_apply_active_slot_glow(chosen_btn)
			chosen_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chosen_btn.focus_mode = Control.FOCUS_NONE
			
		for j in range(choice_buttons.size()):
			var b = choice_buttons[j]
			if j != index:
				b.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.focus_mode = Control.FOCUS_NONE
				b.icon = _get_empty_arrow_texture()
				var tw = create_tween()
				tw.tween_property(b, "modulate", Color(0.50, 0.48, 0.54, 1.0), 0.20)
				
		if is_instance_valid(choice_slots_container):
			choice_slots_container.visible = true
	else:
		# กรณีที่เป็น "ใช่ / ไม่" หรือ "ฉันจะลองดู":
		# ให้สไลด์ออกพร้อมกันจากซ้ายไปขวา และขยายกรอบบทสนทนากลับคืนทันที
		active_choice_id = ""
		is_showing_choices = false
		_animate_choices_exit()
		_expand_dialogue_box()
		
	if seq.size() > 0:
		_load_sequence(seq)
	else:
		if is_action_choice:
			_open_gameplay_step(1)
		else:
			push_error("[LevelDialogueView] No sequence found for choice: %s" % choice_id)
			var fallback_menu = current_menu_id if current_menu_id != "" else ("part2_main" if debug_phase == 1 else "part1_main")
			_display_choice_menu(fallback_menu)

# ==============================================================================
# GAMEPLAY STEP & STAGE FINISH
# ==============================================================================

## ผู้เล่นกด "ฉันจะลองดู" -> เปิดหน้าต่างสรุปคำสั่งก่อนเข้าสู่ Sandbox หรือดำเนินบทสนทนาเข้าสู่ช่วงถัดไป
func _open_gameplay_step(step: int) -> void:
	if is_transitioning:
		return
	_stop_active_slot_glow()
	if slot_pop_tween and slot_pop_tween.is_valid():
		slot_pop_tween.kill()
	active_choice_id = ""
	is_showing_choices = false
	is_choice_sliding_out = false
	if is_instance_valid(choice_slots_container):
		choice_slots_container.visible = false
	_expand_dialogue_box()
	_hide_continue_arrow()
	_hide_question_mark()

	if LevelDataLoader.has_gameplay(level_number, step):
		_show_command_summary_modal(step)
		return

	# เริ่มช่วงใหม่โดยไม่มีประวัติ: ไม่ให้ปุ่มย้อนกลับพากลับไปที่รายการ open_gameplay แล้ววนกลับมาที่เดิม
	sequence_history.clear()
	current_queue = []
	queue_index = 0
	
	_begin_dialogue_phase(1 if step == 1 else 2)


## แสดงหน้าต่างสรุปคำสั่งและสาธิตการร่ายมนตร์ Git ก่อนนำผู้เล่นเข้าสู่หน้าพิมพ์คำสั่ง (Sandbox)
func _show_command_summary_modal(step: int) -> void:
	if not ResourceLoader.exists(COMMAND_SUMMARY_MODAL_PATH):
		_go_to_gameplay_scene(step)
		return
	
	is_dialogue_active = false
	_hide_continue_arrow()
	_hide_question_mark()
	if is_instance_valid(dialogue_box):
		dialogue_box.visible = false
	if is_instance_valid(nav_arrows_container):
		nav_arrows_container.visible = false
	if is_instance_valid(skip_ctrl):
		skip_ctrl.visible = false
	
	var modal_scene = load(COMMAND_SUMMARY_MODAL_PATH) as PackedScene
	if modal_scene == null:
		_go_to_gameplay_scene(step)
		return
	
	var modal = modal_scene.instantiate()
	modal.level_number = level_number
	modal.current_step = step
	
	modal.proceed_to_terminal.connect(func(target_step: int) -> void:
		_go_to_gameplay_scene(target_step)
	)
	modal.modal_closed.connect(func() -> void:
		_go_to_gameplay_scene(step)
	)
	
	var ui_parent = get_node_or_null("MagicStoryUI")
	if ui_parent != null:
		ui_parent.add_child(modal)
	else:
		add_child(modal)

## ด่านที่มีนิยามขั้นเล่นจริง -> เฟดดำแล้วไป Sandbox พร้อมแผงภารกิจ คืน false ถ้าเปลี่ยนฉากไม่ได้ (ใช้ทางสำรองข้ามช่วงเล่น)
func _go_to_gameplay_scene(step: int) -> bool:
	if not ResourceLoader.exists(SANDBOX_SCENE_PATH):
		return false
	is_transitioning = true
	is_dialogue_active = false
	_hide_continue_arrow()
	_hide_question_mark()
	if is_instance_valid(dialogue_box):
		dialogue_box.visible = false
	if is_instance_valid(nav_arrows_container):
		nav_arrows_container.visible = false
	if skip_ctrl:
		skip_ctrl.visible = false
	Engine.time_scale = 1.0
	GameProgressManager.set_pending_mission_step(step)
	var open_sandbox := func() -> void:
		if not SceneLoader.change_scene(get_tree(), SANDBOX_SCENE_PATH):
			# เปิดไม่ได้จริง -> คืนสถานะแล้วเล่นช่วงถัดไปต่อ เหมือนด่านที่ยังไม่มีหน้าเล่น
			GameProgressManager.set_pending_mission_step(0)
			is_transitioning = false
			if skip_ctrl:
				skip_ctrl.visible = true
			if is_instance_valid(fade_overlay):
				fade_overlay.color.a = 0.0
				fade_overlay.visible = false
			sequence_history.clear()
			current_queue = []
			queue_index = 0
			_begin_dialogue_phase(1 if step == 1 else 2)
	if is_instance_valid(fade_overlay):
		fade_overlay.visible = true
		var tw := create_tween()
		tw.tween_property(fade_overlay, "color:a", 1.0, 0.35)
		tw.tween_callback(open_sandbox)
	else:
		open_sandbox.call()
	return true


func _finish_dialogue_stage(mark_cleared: bool = true) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	is_dialogue_active = false
	_stop_active_slot_glow()
	if slot_pop_tween and slot_pop_tween.is_valid():
		slot_pop_tween.kill()
	active_choice_id = ""
	is_showing_choices = false
	is_choice_sliding_out = false
	if is_instance_valid(choice_slots_container):
		choice_slots_container.visible = false
	_expand_dialogue_box()
	
	if char_dim_tween_vel and char_dim_tween_vel.is_valid(): char_dim_tween_vel.kill()
	if char_dim_tween_mewla and char_dim_tween_mewla.is_valid(): char_dim_tween_mewla.kill()
	if is_instance_valid(vel): vel.self_modulate = CHAR_ACTIVE_COLOR
	if is_instance_valid(mewla): mewla.self_modulate = CHAR_ACTIVE_COLOR
	
	_hide_continue_arrow()
	_hide_question_mark()
	if is_instance_valid(dialogue_box):
		dialogue_box.visible = false
	if is_instance_valid(nav_arrows_container):
		nav_arrows_container.visible = false
	if skip_ctrl:
		skip_ctrl.visible = false
		
	Engine.time_scale = 1.0
	
	# บันทึกสถานะว่าเล่นผ่านด่านนี้สำเร็จเฉพาะเมื่อ mark_cleared เป็น true
	if mark_cleared:
		var time_rem := GameProgressManager.get_level_time_remaining(level_number)
		var lvl_data := LevelDataLoader.load_data(level_number)
		var time_lim := float(lvl_data.get("time_limit", 0.0))
		var max_sc := int(lvl_data.get("max_score", 100))
		GameProgressManager.record_level_clear(level_number, time_rem, time_lim, max_sc)
		GameProgressManager.clear_level_timer(level_number)
	
	# จบบทสนทนา -> เฟดดำ แล้วไปฉากเดินขึ้นบันได (ถ้าผ่านด่าน) หรือกลับหน้าเลือกด่าน
	var next_step := _go_to_level_clear_scene if mark_cleared else _go_to_level_select
	if is_instance_valid(fade_overlay):
		fade_overlay.visible = true
		var tw = create_tween()
		tw.tween_property(fade_overlay, "color:a", 1.0, 0.35)
		tw.tween_callback(next_step)
	else:
		next_step.call()

func _go_to_level_clear_scene() -> void:
	if SceneLoader.change_scene(get_tree(), LEVEL_CLEAR_SCENE_PATH):
		return
	_go_to_level_select()

func _go_to_level_select() -> void:
	if SceneLoader.change_scene(get_tree(), LEVEL_SELECT_PATH):
		return
	if next_scene_path != "" and ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)

func _show_bad_ending_prompt() -> void:
	is_bad_ending_typing = false
	if not is_instance_valid(bad_ending_btn):
		return
	is_bad_ending_waiting = true
	bad_ending_btn.visible = true
	bad_ending_btn.disabled = false
	
	if bad_ending_pulse_tween and bad_ending_pulse_tween.is_valid():
		bad_ending_pulse_tween.kill()
	
	var tw_show = create_tween()
	tw_show.tween_property(bad_ending_btn, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw_show.tween_callback(func():
		if is_bad_ending_waiting and is_instance_valid(bad_ending_btn):
			bad_ending_pulse_tween = create_tween().set_loops()
			bad_ending_pulse_tween.tween_property(bad_ending_btn, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bad_ending_pulse_tween.tween_property(bad_ending_btn, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

func _on_bad_ending_exit() -> void:
	if not is_bad_ending_waiting:
		return
	is_bad_ending_waiting = false
	Engine.time_scale = 1.0
	if bad_ending_pulse_tween and bad_ending_pulse_tween.is_valid():
		bad_ending_pulse_tween.kill()
	if bad_ending_tween and bad_ending_tween.is_valid():
		bad_ending_tween.kill()
	if not SceneLoader.change_scene(get_tree(), "res://features/start/start_view.tscn"):
		get_tree().change_scene_to_file("res://features/start/start_view.tscn")

func _skip_bad_ending_typewriter() -> void:
	if not is_bad_ending_typing:
		return
	is_bad_ending_typing = false
	if bad_ending_tween and bad_ending_tween.is_valid():
		bad_ending_tween.kill()
	
	if is_instance_valid(bad_ending_line1):
		bad_ending_line1.visible_characters = -1
		bad_ending_line1.visible_ratio = 1.0
	if is_instance_valid(bad_ending_line2):
		bad_ending_line2.visible_characters = -1
		bad_ending_line2.visible_ratio = 1.0
		
	_show_bad_ending_prompt()

func _trigger_bad_ending() -> void:
	is_transitioning = true
	is_dialogue_active = false
	_hide_continue_arrow()
	if is_instance_valid(nav_arrows_container):
		nav_arrows_container.visible = false
	if is_instance_valid(skip_ctrl):
		skip_ctrl.visible = false
	if is_instance_valid(choice_slots_container):
		choice_slots_container.visible = false
	
	# เปิดใช้งาน FadeOverlay และเริ่มเฟดจอดำสนิท
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 0)
	
	var tw_close = create_tween()
	tw_close.tween_property(dialogue_box, "modulate:a", 0.0, 0.4)
	tw_close.parallel().tween_property(fade_overlay, "color:a", 1.0, 0.8)
	
	tw_close.tween_callback(func():
		dialogue_box.visible = false
		
		bad_ending_panel = Control.new()
		magic_ui.add_child(bad_ending_panel)
		bad_ending_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# แผ่นพื้นหลังสีดำสนิทคลุมเต็มจอ เพื่อการันตีความมืดมิด 100%
		var bg_black = ColorRect.new()
		bg_black.color = Color(0, 0, 0, 1)
		bg_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bad_ending_panel.add_child(bg_black)
		
		var center_container = CenterContainer.new()
		bad_ending_panel.add_child(center_container)
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 22)
		center_container.add_child(vbox)
		
		# โหลดและกำหนดฟอนต์ Chakra Petch (ฟอนต์หลักของระบบบทสนทนาและเกม)
		var ending_font: Font = null
		if font_chakra_regular:
			var chakra_var = FontVariation.new()
			chakra_var.base_font = font_chakra_regular
			chakra_var.spacing_top = 4
			chakra_var.spacing_bottom = 2
			ending_font = chakra_var
		elif font_chakra_bold:
			ending_font = font_chakra_bold
		elif font_ta8bit:
			ending_font = font_ta8bit
			
		var ending_font_size: int = 26
		
		# คำนวณความกว้างข้อความที่แท้จริง เพื่อตรึงขนาด Label ให้พอดีเป๊ะและจัดกึ่งกลางหน้าจออย่างสมดุล
		var str_size1: Vector2 = Vector2(900, 46)
		var str_size2: Vector2 = Vector2(820, 46)
		if ending_font:
			str_size1 = ending_font.get_string_size(BAD_END_LINE1, HORIZONTAL_ALIGNMENT_LEFT, -1, ending_font_size)
			str_size2 = ending_font.get_string_size(BAD_END_LINE2, HORIZONTAL_ALIGNMENT_LEFT, -1, ending_font_size)
		var w1: float = ceil(str_size1.x) + 6.0
		var w2: float = ceil(str_size2.x) + 6.0
		
		# บรรทัดที่ 1: "เศษเสี้ยวที่กระจัดกระจายและใครบางคน... ยังคงรอคอยอยู่ในความมืดมิด"
		bad_ending_line1 = Label.new()
		bad_ending_line1.text = BAD_END_LINE1
		bad_ending_line1.autowrap_mode = TextServer.AUTOWRAP_OFF
		bad_ending_line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bad_ending_line1.custom_minimum_size = Vector2(w1, 46)
		bad_ending_line1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bad_ending_line1.visible_characters = -1
		bad_ending_line1.visible_ratio = 0.0
		if ending_font:
			bad_ending_line1.add_theme_font_override("font", ending_font)
			bad_ending_line1.add_theme_font_size_override("font_size", ending_font_size)
		bad_ending_line1.add_theme_color_override("font_color", Color.WHITE)
		bad_ending_line1.add_theme_constant_override("outline_size", 0)
		vbox.add_child(bad_ending_line1)
		
		# บรรทัดที่ 2: "ขณะที่เวลเดินพ้นประตูหอคอยไป ทิ้งทุกคำตอบไว้เบื้องหลังตลอดกาล"
		bad_ending_line2 = Label.new()
		bad_ending_line2.text = BAD_END_LINE2
		bad_ending_line2.autowrap_mode = TextServer.AUTOWRAP_OFF
		bad_ending_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bad_ending_line2.custom_minimum_size = Vector2(w2, 46)
		bad_ending_line2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bad_ending_line2.visible_characters = -1
		bad_ending_line2.visible_ratio = 0.0
		if ending_font:
			bad_ending_line2.add_theme_font_override("font", ending_font)
			bad_ending_line2.add_theme_font_size_override("font_size", ending_font_size)
		bad_ending_line2.add_theme_color_override("font_color", Color.WHITE)
		bad_ending_line2.add_theme_constant_override("outline_size", 0)
		vbox.add_child(bad_ending_line2)
		
		# ข้อความ "กลับสู่หน้าแรก" แบบกระพริบ อยู่ด้านล่างจอ สไตล์เดียวกับ ending_cutscene (รูปที่ 2)
		bad_ending_btn = Button.new()
		bad_ending_btn.text = "กลับสู่หน้าแรก"
		bad_ending_btn.flat = true
		bad_ending_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bad_ending_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		bad_ending_btn.offset_left = -300.0
		bad_ending_btn.offset_top = -110.0
		bad_ending_btn.offset_right = 300.0
		bad_ending_btn.offset_bottom = -70.0
		bad_ending_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
		bad_ending_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
		bad_ending_btn.modulate.a = 0.0
		bad_ending_btn.visible = false
		bad_ending_btn.disabled = true
		
		var empty_sb = StyleBoxEmpty.new()
		bad_ending_btn.add_theme_stylebox_override("normal", empty_sb)
		bad_ending_btn.add_theme_stylebox_override("hover", empty_sb)
		bad_ending_btn.add_theme_stylebox_override("pressed", empty_sb)
		bad_ending_btn.add_theme_stylebox_override("focus", empty_sb)
		bad_ending_btn.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96, 0.95))
		bad_ending_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		bad_ending_btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85, 1.0))
		bad_ending_btn.add_theme_color_override("font_focus_color", Color(0.98, 0.98, 0.96, 0.95))
		
		if ending_font:
			bad_ending_btn.add_theme_font_override("font", ending_font)
			bad_ending_btn.add_theme_font_size_override("font_size", 22)
		elif font_chakra_regular:
			bad_ending_btn.add_theme_font_override("font", font_chakra_regular)
			bad_ending_btn.add_theme_font_size_override("font_size", 22)
		elif font_chakra_bold:
			bad_ending_btn.add_theme_font_override("font", font_chakra_bold)
			bad_ending_btn.add_theme_font_size_override("font_size", 22)
			
		bad_ending_btn.pressed.connect(_on_bad_ending_exit)
		bad_ending_panel.add_child(bad_ending_btn)
		
		# Typewriter Animation: พิมพ์ตัวอักษรทีละตัวอย่างนิ่งสนิท อยู่ตรงกลางจอ ไม่เลื่อน ไม่สั่น
		if bad_ending_tween and bad_ending_tween.is_valid():
			bad_ending_tween.kill()
		bad_ending_tween = create_tween()
		
		bad_ending_tween.tween_interval(0.4)
		bad_ending_tween.tween_callback(func():
			is_bad_ending_typing = true
		)
		
		# พิมพ์บรรทัดที่ 1 ด้วย visible_ratio แบบมาตรฐานของ Godot (ไม่แก้ .text ในลูป)
		var dur1: float = clampf(float(BAD_END_LINE1.length()) * 0.032, 1.2, 2.0)
		bad_ending_tween.tween_property(bad_ending_line1, "visible_ratio", 1.0, dur1)
		bad_ending_tween.tween_interval(0.4)
		
		# พิมพ์บรรทัดที่ 2
		var dur2: float = clampf(float(BAD_END_LINE2.length()) * 0.032, 1.2, 2.0)
		bad_ending_tween.tween_property(bad_ending_line2, "visible_ratio", 1.0, dur2)
		
		# หยุดรอ 0.8 วินาที แล้วแสดงข้อความกลับสู่หน้าแรกแบบกระพริบที่ด้านล่างจอ
		bad_ending_tween.tween_interval(0.8)
		bad_ending_tween.tween_callback(func():
			_show_bad_ending_prompt()
		)
	)

# ==============================================================================
# EMOTES & HELPERS
# ==============================================================================

func _on_vel_animation_looped() -> void:
	if vel.animation in VEL_IDLE_SEQ:
		vel_seq_step = (vel_seq_step + 1) % VEL_IDLE_SEQ.size()
		vel.play(VEL_IDLE_SEQ[vel_seq_step])

func _pop_question_mark() -> void:
	if question_tween and question_tween.is_valid():
		question_tween.kill()
	question_mark.visible = true
	question_mark.scale = Vector2.ZERO
	question_mark.position = Vector2(0, -36)
	question_mark.modulate.a = 1.0
	
	var tw_pop = create_tween()
	tw_pop.tween_property(question_mark, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_callback(func():
		if not is_instance_valid(question_mark) or not question_mark.visible:
			return
		question_tween = create_tween().set_loops()
		question_tween.tween_property(question_mark, "position:y", -39.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		question_tween.tween_property(question_mark, "position:y", -33.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	)
	question_tween = tw_pop

func _hide_question_mark() -> void:
	if question_tween and question_tween.is_valid():
		question_tween.kill()
	if is_instance_valid(question_mark):
		question_mark.visible = false
		question_mark.scale = Vector2.ZERO
		question_mark.position = Vector2(0, -36)

func _show_continue_arrow() -> void:
	if arrow_tween and arrow_tween.is_valid():
		arrow_tween.kill()
	if is_instance_valid(continue_arrow):
		continue_arrow.visible = false
	if is_instance_valid(arrow_wrapper):
		arrow_wrapper.visible = false
	_update_nav_arrows()

func _hide_continue_arrow() -> void:
	if arrow_tween and arrow_tween.is_valid():
		arrow_tween.kill()
	if is_instance_valid(continue_arrow):
		continue_arrow.visible = false
	if is_instance_valid(arrow_wrapper):
		arrow_wrapper.visible = false
	_update_nav_arrows()

# ==============================================================================
# NAVIGATION ARROWS SYSTEM (ลูกศรซ้าย-ขวาข้างกัน)
# ==============================================================================

static func _get_nav_arrow_texture(is_left: bool) -> ImageTexture:
	if is_left and _cached_arrow_left_tex != null:
		return _cached_arrow_left_tex
	if not is_left and _cached_arrow_right_tex != null:
		return _cached_arrow_right_tex
		
	var arrow_stream = load("res://assets/cutscene/frame dialog text/arrow.png")
	if not arrow_stream:
		return null
	var img: Image = arrow_stream.get_image()
	if not img:
		return null
	var cropped: Image = img.get_region(Rect2i(561, 344, 537, 334))
	
	if is_left:
		var img_left = cropped.duplicate()
		img_left.rotate_90(CLOCKWISE)
		_cached_arrow_left_tex = ImageTexture.create_from_image(img_left)
		return _cached_arrow_left_tex
	else:
		var img_right = cropped.duplicate()
		img_right.rotate_90(COUNTERCLOCKWISE)
		_cached_arrow_right_tex = ImageTexture.create_from_image(img_right)
		return _cached_arrow_right_tex

func _create_nav_arrows() -> void:
	if nav_arrows_container != null and is_instance_valid(nav_arrows_container):
		return
		
	var arrow_overlay = dialogue_box.get_node_or_null("ArrowOverlay")
	if not arrow_overlay:
		return
		
	# ปรับระยะขอบขวาของ Margin และเปิด fit_content เพื่อป้องกันข้อความยาวทับลูกศรซ้าย-ขวา
	var margin_node = dialogue_box.get_node_or_null("Margin")
	if margin_node:
		margin_node.add_theme_constant_override("margin_right", 96)
	if dialogue_label:
		dialogue_label.fit_content = true
		
	# ซ่อนลูกศรเดี่ยวเดิม
	if arrow_wrapper:
		arrow_wrapper.visible = false
	if continue_arrow:
		continue_arrow.visible = false
		
	nav_arrows_container = HBoxContainer.new()
	nav_arrows_container.name = "NavArrowsContainer"
	nav_arrows_container.layout_mode = 1
	nav_arrows_container.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	nav_arrows_container.anchor_left = 1.0
	nav_arrows_container.anchor_right = 1.0
	nav_arrows_container.anchor_top = 1.0
	nav_arrows_container.anchor_bottom = 1.0
	nav_arrows_container.offset_left = -78.0
	nav_arrows_container.offset_top = -42.0
	nav_arrows_container.offset_right = -24.0
	nav_arrows_container.offset_bottom = -16.0
	nav_arrows_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	nav_arrows_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	nav_arrows_container.alignment = BoxContainer.ALIGNMENT_END
	nav_arrows_container.add_theme_constant_override("separation", 12)
	
	# 1. ปุ่มลูกศรซ้าย (ย้อนกลับ)
	btn_arrow_back = TextureButton.new()
	btn_arrow_back.name = "BtnArrowBack"
	btn_arrow_back.texture_normal = _get_nav_arrow_texture(true)
	btn_arrow_back.ignore_texture_size = true
	btn_arrow_back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_arrow_back.custom_minimum_size = Vector2(20, 26)
	btn_arrow_back.focus_mode = Control.FOCUS_NONE
	btn_arrow_back.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_arrow_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_setup_arrow_hover(btn_arrow_back)
	btn_arrow_back.pressed.connect(func():
		_animate_button_press(btn_arrow_back)
		_on_player_back()
	)
	nav_arrows_container.add_child(btn_arrow_back)
	btn_back = btn_arrow_back
	
	# 2. ปุ่มลูกศรขวา (ไปต่อ)
	btn_arrow_next = TextureButton.new()
	btn_arrow_next.name = "BtnArrowNext"
	btn_arrow_next.texture_normal = _get_nav_arrow_texture(false)
	btn_arrow_next.ignore_texture_size = true
	btn_arrow_next.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_arrow_next.custom_minimum_size = Vector2(20, 26)
	btn_arrow_next.focus_mode = Control.FOCUS_NONE
	btn_arrow_next.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_arrow_next.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_setup_arrow_hover(btn_arrow_next)
	btn_arrow_next.pressed.connect(func():
		_animate_button_press(btn_arrow_next)
		_on_player_advance()
	)
	nav_arrows_container.add_child(btn_arrow_next)
	
	arrow_overlay.add_child(nav_arrows_container)
	_update_nav_arrows()

func _animate_button_press(btn: TextureButton) -> void:
	if not is_instance_valid(btn) or not btn.visible or btn.disabled:
		return
	if btn == btn_arrow_back and press_tween_back and press_tween_back.is_valid():
		press_tween_back.kill()
	elif btn == btn_arrow_next and press_tween_next and press_tween_next.is_valid():
		press_tween_next.kill()
		
	btn.pivot_offset = btn.size / 2.0
	btn.position.y = 2.0
	btn.scale = Vector2(0.90, 0.90)
	btn.modulate = Color(2.4, 2.4, 2.4, 1.0)
	
	var tw = btn.create_tween()
	tw.set_parallel(true)
	tw.tween_property(btn, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var is_hovered = btn.get_global_rect().has_point(btn.get_global_mouse_position())
	var target_mod = Color(1.4, 1.4, 1.4, 1.0) if is_hovered else Color(1.0, 1.0, 1.0, 1.0)
	tw.tween_property(btn, "modulate", target_mod, 0.14)
	
	if btn == btn_arrow_back:
		press_tween_back = tw
	elif btn == btn_arrow_next:
		press_tween_next = tw

func _setup_arrow_hover(btn: TextureButton) -> void:
	btn.mouse_entered.connect(func():
		var is_pressing = (btn == btn_arrow_back and press_tween_back and press_tween_back.is_valid()) or \
			(btn == btn_arrow_next and press_tween_next and press_tween_next.is_valid())
		if not is_pressing and not btn.disabled and btn.visible:
			var tw = create_tween()
			tw.tween_property(btn, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.08)
	)
	btn.mouse_exited.connect(func():
		var is_pressing = (btn == btn_arrow_back and press_tween_back and press_tween_back.is_valid()) or \
			(btn == btn_arrow_next and press_tween_next and press_tween_next.is_valid())
		if not is_pressing and not btn.disabled and btn.visible:
			var tw = create_tween()
			tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	)

func _update_nav_arrows() -> void:
	if not nav_arrows_container or not is_instance_valid(nav_arrows_container):
		return
	if not is_instance_valid(dialogue_box) or not dialogue_box.visible or is_transitioning:
		nav_arrows_container.visible = false
		return
		
	nav_arrows_container.visible = true
	
	# ลูกศรซ้าย (ย้อนกลับ)
	var can_back = _can_go_back()
	btn_arrow_back.disabled = not can_back
	btn_arrow_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_back else Control.CURSOR_ARROW
	if can_back:
		if not (press_tween_back and press_tween_back.is_valid()):
			var is_hovered = btn_arrow_back.get_global_rect().has_point(btn_arrow_back.get_global_mouse_position())
			btn_arrow_back.modulate = Color(1.4, 1.4, 1.4, 1.0) if is_hovered else Color(1.0, 1.0, 1.0, 1.0)
	else:
		if press_tween_back and press_tween_back.is_valid():
			press_tween_back.kill()
		btn_arrow_back.position.y = 0.0
		btn_arrow_back.scale = Vector2.ONE
		btn_arrow_back.modulate = Color(1.0, 1.0, 1.0, 0.25)
	
	# ลูกศรขวา (ไปต่อ)
	var can_next = (is_dialogue_active or is_typing) and not is_showing_choices and not is_choice_sliding_out
	btn_arrow_next.disabled = not can_next
	btn_arrow_next.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_next else Control.CURSOR_ARROW
	if can_next:
		if not (press_tween_next and press_tween_next.is_valid()):
			var is_hovered = btn_arrow_next.get_global_rect().has_point(btn_arrow_next.get_global_mouse_position())
			btn_arrow_next.modulate = Color(1.4, 1.4, 1.4, 1.0) if is_hovered else Color(1.0, 1.0, 1.0, 1.0)
	else:
		if press_tween_next and press_tween_next.is_valid():
			press_tween_next.kill()
		btn_arrow_next.position.y = 0.0
		btn_arrow_next.scale = Vector2.ONE
		btn_arrow_next.modulate = Color(1.0, 1.0, 1.0, 0.25)

func _update_back_button_state() -> void:
	_update_nav_arrows()

func _can_go_back() -> bool:
	if not is_instance_valid(dialogue_box) or not dialogue_box.visible:
		return false
	if is_transitioning or is_choice_sliding_out:
		return false
	if not is_dialogue_active and not is_showing_choices:
		return false
	if queue_index > 0:
		return true
	if sequence_history.size() > 0:
		return true
	return false

func _on_player_back() -> void:
	if not _can_go_back():
		return
		
	# 1. หยุด typewriter tween ทันที
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
		
	# 2. ปิดเอฟเฟกต์เครื่องหมายคำถาม/ตกใจ
	_hide_question_mark()
	if is_instance_valid(exclamation_mark):
		exclamation_mark.visible = false
		
	# 3. หากกำลังแสดงเมนูช้อยส์อยู่
	if is_showing_choices:
		if current_menu_id.ends_with("_sub"):
			_stop_active_slot_glow()
			active_choice_id = ""
			var target_parent_menu := "part1_main"
			if current_menu_id.begins_with("part2_") or debug_phase == 1:
				target_parent_menu = "part2_main"
			if sequence_history.size() > 0:
				var parent_state = sequence_history.pop_back()
				current_queue = parent_state.get("queue", current_queue)
				queue_index = parent_state.get("index", queue_index)
				if parent_state.has("is_in_entrance_cutscene"):
					is_in_entrance_cutscene = parent_state["is_in_entrance_cutscene"]
			_animate_choices_exit(func():
				_display_choice_menu(target_parent_menu, true)
			)
			_update_nav_arrows()
			return
			
		is_showing_choices = false
		_stop_active_slot_glow()
		active_choice_id = ""
		_animate_choices_exit()
		_expand_dialogue_box()
		dialogue_label.visible = true
		
		# ถอยกลับไปประโยคก่อนหน้าช้อยส์
		if queue_index > 0 and queue_index < current_queue.size() and current_queue[queue_index].get("type") == "choice_menu":
			queue_index -= 1
		elif queue_index > 0:
			queue_index -= 1
		elif sequence_history.size() > 0:
			var prev_state = sequence_history.pop_back()
			current_queue = prev_state.get("queue", [])
			queue_index = prev_state.get("index", 0)
			if prev_state.has("is_in_entrance_cutscene"):
				is_in_entrance_cutscene = prev_state["is_in_entrance_cutscene"]
			if queue_index > 0 and queue_index < current_queue.size() and current_queue[queue_index].get("type") == "choice_menu":
				queue_index -= 1
				
		_show_current_queue_item(true)
		_update_nav_arrows()
		return
			
	# 4. หากแสดงข้อความปกติ
	if queue_index > 0:
		queue_index -= 1
		_show_current_queue_item(true)
	elif sequence_history.size() > 0:
		var prev_state = sequence_history.pop_back()
		current_queue = prev_state.get("queue", [])
		queue_index = prev_state.get("index", 0)
		if prev_state.has("is_in_entrance_cutscene"):
			is_in_entrance_cutscene = prev_state["is_in_entrance_cutscene"]
		_show_current_queue_item(true)
		
	_update_nav_arrows()
