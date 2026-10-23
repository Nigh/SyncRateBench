extends SceneTree

const Scores = preload("res://scripts/score_store.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefix := "user://display-selection-%d" % Time.get_ticks_usec()
	var store = Scores.new()
	store.score_path = prefix + "-scores.txt"
	assert(store.set_display_screen(2))
	var loaded = Scores.new()
	loaded.score_path = store.score_path
	loaded.load_scores()
	assert(loaded.writable and loaded.display_screen == 2)
	store.score_path = prefix + "/missing/scores.txt"
	assert(not store.set_display_screen(1))
	assert(store.display_screen == 2, "failed saves restore the previous preference")
	assert(not store.set_display_screen(-1))
	var file := FileAccess.open(loaded.score_path, FileAccess.WRITE)
	file.store_string("data_epoch 2\ndisplay_screen 1.5\n")
	file.close()
	loaded.load_scores()
	assert(not loaded.writable, "fractional screen indices must not overwrite settings")
	DirAccess.remove_absolute(loaded.score_path)

	var app = load("res://scenes/Main.tscn").instantiate()
	app.scores.score_path = prefix + "-app.txt"
	app.history.path = prefix + "-history.json"
	root.add_child(app)
	await process_frame
	app.show_settings()
	app.scores.display_screen = DisplayServer.get_screen_count() + 10
	assert(app._preferred_display() == DisplayServer.get_primary_screen())
	app._refresh_display_options()
	assert(app.display_option.selected == 0, "missing screen falls back to primary")
	app.scores.display_screen = 0
	app._refresh_display_options()
	if DisplayServer.get_name() not in ["headless", "Wayland"]:
		var original := DisplayServer.window_get_current_screen()
		var target := (original + 1) % DisplayServer.get_screen_count()
		app.display_option.item_selected.emit(target + 1)
		while app.display_switching:
			await process_frame
		assert(DisplayServer.window_get_current_screen() == target, app.display_status.text)
		assert(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		assert(app.scores.display_screen == target + 1)
		loaded.score_path = app.scores.score_path
		loaded.load_scores()
		assert(loaded.display_screen == target + 1)
		# Failed persistence must also restore the actual window, not only the dropdown.
		app.scores.score_path = prefix + "/missing/scores.txt"
		app.display_option.item_selected.emit(original + 1)
		while app.display_switching:
			await process_frame
		assert(DisplayServer.window_get_current_screen() == target)
		assert(app.scores.display_screen == target + 1)
		assert(app.display_status.text.contains("Could not save"))
		app.scores.score_path = loaded.score_path
		app.display_option.item_selected.emit(original + 1)
		while app.display_switching:
			await process_frame
		assert(DisplayServer.window_get_current_screen() == original)
		print("Native fullscreen switch verified across %d displays" % DisplayServer.get_screen_count())
	else:
		assert(app.display_option.disabled)
	DirAccess.remove_absolute(prefix + "-app.txt")
	app.queue_free()
	await process_frame
	print("display_selection_test: PASS")
	quit()
