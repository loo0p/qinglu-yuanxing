extends RefCounted
## 最小示例胶水：一个小村子，四个人。演示 adapter 需要实现的全部方法。
var day := 0
var people := []
var logs := {}   # id -> [[day, text]]

func _init() -> void:
	var names := ["阿青", "老周", "小满", "柳娘"]
	for i in names.size():
		people.append({"id": i + 1, "name": names[i], "brave": [0.8, 0.3, 0.6, 0.2][i], "kind": [0.4, 0.7, 0.5, 0.9][i], "gold": 5, "friend": {}})
		logs[i + 1] = []

# ---- 必需
func se_now() -> int: return day
func se_actors() -> Array: return people
func se_id(a) -> int: return int(a["id"])
func se_actor(id):
	for p in people:
		if int(p["id"]) == int(id):
			return p
	return null
func se_name(a) -> String: return String(a["name"])
func se_chronicle(a, text: String, inst, eng) -> void:
	logs[int(a["id"])].append([day, text])
# ---- 可选
func se_alive(a) -> bool: return true
func se_var(nm: String, inst, eng):
	if nm == "天气": return ["晴", "小雨", "大风"][day % 3]
	return null
func se_op(op: Dictionary, inst, eng) -> void:
	match String(op["op"]):
		"gold":
			var a = eng.actor(inst, String(op.get("who", "A")))
			a["gold"] = int(a["gold"]) + int(op.get("add", 0))
		"befriend":
			var a = eng.actor(inst, String(op["a"]))
			var b = eng.actor(inst, String(op["b"]))
			a["friend"][str(int(b["id"]))] = int(a["friend"].get(str(int(b["id"])), 0)) + int(op.get("add", 1))
			b["friend"][str(int(a["id"]))] = int(b["friend"].get(str(int(a["id"])), 0)) + int(op.get("add", 1))
func se_offer(inst, eng) -> void:
	pass
# ---- 表达式里用的游戏函数（g.xxx）
func fr(a, b) -> int: return int(a["friend"].get(str(int(b["id"])), 0))
