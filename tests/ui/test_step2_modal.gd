extends SceneTree

const CommandSummaryModal = preload("res://features/dialogue/command_summary_modal.gd")

func _init() -> void:
	_run_tests()

func _run_tests() -> void:
	print("--- Running Level 1 Step 2 Config Modal Test ---")
	var scene: PackedScene = load("res://features/dialogue/command_summary_modal.tscn")
	var modal: CommandSummaryModal = scene.instantiate() as CommandSummaryModal
	modal.level_number = 1
	modal.current_step = 2
	root.add_child(modal)
	await process_frame
	
	assert(modal.slides.size() == 1, "Should have 1 slide for step 2")
	assert(modal.title_label.text.contains("ประกาศนาม"), "Title should be about declaring name")
	print("Step 2 Title: ", modal.title_label.text)
	
	# Test casting step 2 command
	modal._on_cast_command_pressed()
	modal._on_canvas_animation_finished("git config --global user.name \"Vel\"")
	assert(modal.outcome_panel.visible == true, "Outcome panel should be visible")
	print("Step 2 Tested successfully")
	
	print("=== Step 2 Test Passed ===")
	quit(0)
