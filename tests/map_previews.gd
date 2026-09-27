extends SceneTree
## Генерация миникарт всех карт (проверка раскладки баз) и замер времени генерации рельефа.
## godot --headless --path . --script res://tests/map_previews.gd -- --out=DIR [--res=1024]

func _initialize() -> void:
	var out := "user://map_previews"
	var res := 512
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--res="):
			res = int(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out)
	for map_id: String in MapPresets.ORDER:
		var t0 := Time.get_ticks_msec()
		var layout := MapLayout.new(map_id)
		var terrain := Terrain.new(layout, 12345, res)
		terrain.generate()
		var t1 := Time.get_ticks_msec()
		var img := MapPreview.render(terrain, 768, true, layout.world)
		img.save_png(out.path_join("%s.png" % map_id))
		var issues := PackedStringArray()
		for team in 2:
			var af := layout.airfield[team]
			if terrain.get_height(af.x, af.y) < 2.0:
				issues.append("airfield%d under water" % team)
			var root := layout.pier_root[team]
			var tip := layout.pier_tip(team)
			if terrain.get_height(root.x, root.y) < -1.0:
				issues.append("pier root%d under water h=%.1f" % [team, terrain.get_height(root.x, root.y)])
			if not terrain.is_navigable(tip.x + layout.pier_dir[team].x * 80.0, tip.y + layout.pier_dir[team].y * 80.0, 20.0):
				issues.append("pier tip%d not navigable" % team)
			var w := layout.warship[team]
			if not terrain.is_navigable(w.x, w.y, 200.0):
				issues.append("warship%d not navigable" % team)
			for p: Vector2 in [layout.hq[team], layout.radar[team], layout.ad[team]]:
				if terrain.get_height(p.x, p.y) < 2.0:
					issues.append("base point %s%d low h=%.1f" % [str(p), team, terrain.get_height(p.x, p.y)])
		print("%s: gen %d ms (res %d), preview %d ms, issues: %s" % [map_id, t1 - t0, res, Time.get_ticks_msec() - t1, ", ".join(issues) if not issues.is_empty() else "none"])
	quit()
