extends Node
## Проверка компиляции всех скриптов проекта (с загруженными Autoload).
## Запуск: godot --headless --path . res://tests/compile_check.tscn

func _ready() -> void:
	var files: Array[String] = []
	_collect("res://autoload", files)
	_collect("res://scripts", files)
	var failed := 0
	for f in files:
		var s := load(f) as Script
		if s == null or not s.can_instantiate():
			failed += 1
			printerr("[CHECK] FAILED: ", f)
	print("[CHECK] scripts: %d, failed: %d" % [files.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
