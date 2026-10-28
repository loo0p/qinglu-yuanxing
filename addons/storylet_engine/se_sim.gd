extends RefCounted
## 模拟测试台：跑 N 天，统计覆盖率（哪些 storylet / 结果从没出现）与重复率。
## 用法：
##   eng.trace = []
##   for d in days: game_tick()          # 游戏自己推进（内部调 eng.tick_due / beat / emit…）
##   var rep = SESim.report(eng, func(t): return t.replace(名字, "X"))

## normalize：把人名等可变部分换掉，算“同一句式”的重复
static func report(eng, normalize: Callable = Callable()) -> Dictionary:
	var lines: Array = eng.trace if eng.trace != null else []
	var seen := {}
	var by_sid := {}
	for t in lines:
		var s := String(t[4])
		if normalize.is_valid():
			s = String(normalize.call(s))
		seen[s] = int(seen.get(s, 0)) + 1
		by_sid[t[1]] = int(by_sid.get(t[1], 0)) + 1
	var n := lines.size()
	var top := []
	for k in seen:
		top.append([seen[k], k])
	top.sort_custom(func(a, b): return a[0] > b[0])
	var cov := coverage(eng)
	return {"lines": n, "distinct": seen.size(), "distinct_ratio": (float(seen.size()) / n) if n > 0 else 0.0,
		"repeat_rate": (1.0 - float(seen.size()) / n) if n > 0 else 0.0, "top": top.slice(0, 10), "by_sid": by_sid,
		"storylets_hit": cov["storylets_hit"], "storylets": cov["storylets"], "outcomes_hit": cov["outcomes_hit"],
		"outcomes": cov["outcomes"], "never": cov["never"]}

## 覆盖：每条 storylet 的每个结果（含玩家选项的结果）是否至少出现过一次
static func coverage(eng) -> Dictionary:
	var oc: Dictionary = eng.outcome_counts()
	var total := 0
	var hit := 0
	var s_hit := 0
	var never := []
	for sid in eng.order:
		var s: Dictionary = eng.defs[sid]
		if s.get("trigger", "") == "bio":
			continue
		if eng.fired(sid) > 0:
			s_hit += 1
		var keys := []
		if s.has("choices"):
			for c in s["choices"]:
				for o in c.get("outcomes", []):
					keys.append(sid + "/" + String(c["id"]) + ":" + String(o.get("id", "")))
		else:
			for o in s.get("outcomes", []):
				keys.append(sid + "/" + String(o.get("id", "")))
		for k in keys:
			total += 1
			if oc.has(k):
				hit += 1
			else:
				never.append(k)
	var n_s := 0
	for sid in eng.order:
		if eng.defs[sid].get("trigger", "") != "bio":
			n_s += 1
	return {"storylets": n_s, "storylets_hit": s_hit, "outcomes": total, "outcomes_hit": hit, "never": never}
