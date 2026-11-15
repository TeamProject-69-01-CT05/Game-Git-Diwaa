extends SceneTree

func _init() -> void:
	_run_tests()

func _run_tests() -> void:
	print("--- Running Dialogue <-> Modal Integration Test ---")
	var scene: PackedScene = load("res://features/dialogue/level_dialogue_view.tscn")
	if scene == null:
		push_error("Failed to load level_dialogue_view.tscn")
		quit(1)
		return
	
	var view = scene.instantiate()
	root.add_child(view)
	await process_frame
	
	# Simulate open_gameplay_step
	view._open_gameplay_step(1)
	await process_frame
	
	var modal = view.get_node_or_null("MagicStoryUI/CommandSummaryModal")
	assert(modal != null, "CommandSummaryModal should be instantiated under MagicStoryUI")
	print("Modal successfully created under MagicStoryUI: ", modal.name)
	
	# Verify modal setup
	assert(modal.level_number == 1, "Modal level_number should be 1")
	assert(modal.current_step == 1, "Modal current_step should be 1")
	assert(modal.slides.size() >= 1, "Modal should have slides")
	print("Modal parameters correctly initialized: level %d step %d with %d slides" % [modal.level_number, modal.current_step, modal.slides.size()])
	
	print("=== ALL Dialogue Integration Tests PASSED! ===")
	quit(0)
