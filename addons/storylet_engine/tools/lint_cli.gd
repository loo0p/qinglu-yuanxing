extends SceneTree
## 命令行校验：godot --headless --path . -s res://addons/storylet_engine/tools/lint_cli.gd -- a.json b.json
const L = preload("res://addons/storylet_engine/se_lint.gd")

func _init() -> void:
	var packs := []
	for a in OS.get_cmdline_user_args():
		var f := FileAccess.open(a if a.begins_with("res://") or a.begins_with("/") else "res://" + a, FileAccess.READ)
		if f == null:
			print("打不开：", a)
			quit(2)
			return
		var d = JSON.parse_string(f.get_as_text())
		if not (d is Dictionary):
			print("不是 JSON 对象：", a)
			quit(2)
			return
		packs.append(d)
	var r: Dictionary = L.lint(packs)
	for e in r["errors"]:
		print("ERROR ", e)
	for w in r["warnings"]:
		print("WARN  ", w)
	print("storylets=%d outcomes=%d choices=%d symbols=%d errors=%d warnings=%d" % [r["stats"]["storylets"], r["stats"]["outcomes"], r["stats"]["choices"], r["stats"]["symbols"], r["errors"].size(), r["warnings"].size()])
	quit(1 if not r["errors"].is_empty() else 0)
