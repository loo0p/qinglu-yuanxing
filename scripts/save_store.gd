extends RefCounted
## 存档（user://，Web 端为 IndexedDB）
## 写入顺序：写临时文件 → 读回校验 → 旧档改名为 .bak → 临时文件改名为正式档。
## 读档：正式档损坏则退回 .bak。rev 递增，用于发现“两个标签页同时写同一存档”。

## v0.6 起存到新槽 qinglu_v6_slot1（v0.5 的 qinglu_slot1 原样保留，只读，用来迁移）
const SLOT := "qinglu_v6_slot1"
const LEGACY_SLOT := "qinglu_slot1"
var PATH := "user://qinglu_v6_slot1.json"
var TMP := "user://qinglu_v6_slot1.tmp"
var BAK := "user://qinglu_v6_slot1.bak"
var LS_KEY := SLOT
var PREV := "qinglu_v6_prev"

func _init(slot: String = SLOT) -> void:
	PATH = "user://%s.json" % slot
	TMP = "user://%s.tmp" % slot
	BAK = "user://%s.bak" % slot
	LS_KEY = slot
	PREV = "qinglu_v6_prev" if slot == SLOT else "qinglu_prev"

var rev := 0
var conflict := false


## Web：IndexedDB（user://）是异步同步的，刷新太快可能丢最后一步；
## 所以同时写一份到 localStorage（同步、各标签页共享），读档时取 rev 更大的那份。
func _web() -> bool:
	return OS.has_feature("web")

func _ls_get() -> Variant:
	if not _web():
		return null
	var w = JavaScriptBridge.get_interface("localStorage")
	if w == null:
		return null
	var t = w.getItem(LS_KEY)
	if t == null or String(t) == "":
		return null
	var d = JSON.parse_string(String(t))
	return d if (d is Dictionary and d.has("state")) else null

func _ls_set(payload: String) -> void:
	if not _web():
		return
	var w = JavaScriptBridge.get_interface("localStorage")
	if w:
		w.setItem(LS_KEY, payload)

func exists() -> bool:
	return FileAccess.file_exists(PATH) or FileAccess.file_exists(BAK) or _ls_get() != null

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var t := FileAccess.get_file_as_string(path)
	var d = JSON.parse_string(t)
	if d is Dictionary and d.has("state"):
		return d
	return null

func load_data():
	var d = _read(PATH)
	if d == null:
		d = _read(BAK)
	var l = _ls_get()
	if l != null and (d == null or int(l.get("rev", 0)) > int(d.get("rev", 0))):
		d = l
	if d != null:
		rev = int(d.get("rev", 0))
	return d

func peek_rev() -> int:
	var d = _ls_get() if _web() else _read(PATH)
	return int(d.get("rev", 0)) if d != null else 0

func save(state: Dictionary) -> bool:
	if conflict:
		return false
	var on_disk := peek_rev()
	if on_disk > rev:
		conflict = true   # 别的标签页写过更新的档：停止写入，交给 UI 提示
		return false
	rev += 1
	var payload := JSON.stringify({"rev": rev, "saved_at": Time.get_datetime_string_from_system(), "state": state})
	_ls_set(payload)
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(payload)
	f.close()
	var chk: Variant = _read(TMP)
	if not (chk is Dictionary) or int((chk as Dictionary).get("rev", -1)) != rev:
		return false
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists(BAK):
			dir.remove(BAK.get_file())
		dir.rename(PATH.get_file(), BAK.get_file())
	dir.rename(TMP.get_file(), PATH.get_file())
	return true

## 新游戏：不删除旧档，改名存为 <PREV>.json（只保留最近一份）
func archive() -> void:
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists("user://%s.json" % PREV):
			dir.remove("%s.json" % PREV)
		dir.rename(PATH.get_file(), "%s.json" % PREV)
	for p in [TMP, BAK]:
		if FileAccess.file_exists(p):
			dir.remove(p.get_file())
	if _web():
		var w = JavaScriptBridge.get_interface("localStorage")
		var cur = w.getItem(LS_KEY) if w else null
		if w and cur != null:
			w.setItem(PREV, cur)
			w.removeItem(LS_KEY)
	rev = 0
	conflict = false
