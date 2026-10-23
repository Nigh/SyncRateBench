extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app = load("res://scenes/Main.tscn").instantiate()
	var prefix := "user://frame-metrics-%d" % Time.get_ticks_usec()
	app.scores.score_path = prefix + "-scores.txt"
	app.history.path = prefix + "-history.json"
	root.add_child(app)
	await process_frame
	app.set_process(false)
	for project in ["color", "corner", "osu", "spheres", "tracking"]:
		app.enter_project(project)
		match project:
			"color", "corner":
				app.state.start_wait(1, app.rng)
			"osu":
				app.osu_state.start_gate()
				app.osu_state.begin_wait(1, app.rng)
			"spheres":
				app.sphere_state.start_gate()
				app.sphere_state.begin_wait(1, app.rng)
		app._update_frame_metrics(1_000_000)
		for index in 100:
			app._update_frame_metrics(1_000_000 + (index + 1) * 10_000)
		assert(app.frame_times_us.size() == 100)
		# Nearest-rank P95 and P99 differ from both mean and best-frame FPS.
		app.frame_times_us[94] = 20_000
		for index in range(95, 100):
			app.frame_times_us[index] = 40_000
		if project == "tracking":
			app.tracking_state.coverage.assign([10.0, 20.0, 30.0, 40.0, 50.0])
			app.tracking_state.errors.assign([1.0, 1.0, 1.0, 1.0, 1.0])
			app.tracking_state.stage = app.TrackingState.Stage.SUMMARY
		else:
			var state = app.state
			if project == "osu":
				state = app.osu_state
			elif project == "spheres":
				state = app.sphere_state
			state.reactions_us.assign([200_000, 210_000, 220_000, 230_000, 240_000])
			state.stage = state.Stage.SUMMARY
		app.complete_summary()
		assert(app.summary.visible)
		assert(app.summary_fps.text == "TEST FPS  P95 50.0    P99 25.0")
		app._update_frame_metrics(9_000_000)
		assert(app.frame_times_us.size() == 100, "results must stop sampling")
		app.enter_project(project)
		assert(app.frame_times_us.is_empty(), "retry must discard previous samples")
	app.enter_project("color")
	app.state.start_wait(1, app.rng)
	app._update_frame_metrics(1_000_000)
	app._update_frame_metrics(1_010_000)
	app.state.invalidate()
	app._update_frame_metrics(1_020_000)
	assert(app.frame_times_us.is_empty(), "invalid sets must discard frame samples")
	app.show_menu()
	app.queue_free()
	await process_frame
	print("Frame metrics checks passed")
	quit()
