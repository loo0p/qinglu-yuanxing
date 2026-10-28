extends SceneTree
## 江湖（world.gd）指标测试：8 个种子 × 100 日，说书人每天都可出事件，选项随机点。
## 门槛（design-v4 §8）：最常见模板 < 20%，三连序列去重率 > 95%，生平句骨架去重率 > 65%；
## 并检查：存档 JSON 往返后继续跑，结果与不存档完全一致（确定性）。
const W = preload("res://scripts/world.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func run(seed_v: int, days: int, roundtrip_at: int = -1) -> Object:
	var x = W.new()
	x.create(seed_v, "苏青禾")
	for d in days:
		if d == roundtrip_at:
			var j := JSON.stringify(x.w)
			var y = W.new()
			y.attach(null, JSON.parse_string(j))
			x = y
		x.tick(true)
		x.auto_choose()
	return x

func metrics(x) -> Dictionary:
	var ev: Array = x.w["events"]
	var cnt := {}
	for e in ev:
		cnt[e] = int(cnt.get(e, 0)) + 1
	var top := 0
	for k in cnt:
		top = maxi(top, cnt[k])
	var tri := {}
	for i in ev.size() - 2:
		tri["%s|%s|%s" % [ev[i], ev[i + 1], ev[i + 2]]] = 1
	var sk := {}
	var lg: Array = x.P()["log"]
	for l in lg:
		var t: String = l[1]
		for c in x.w["C"].values():
			t = t.replace(c["name"], "某")
		sk[t] = 1
	return {"n": ev.size(), "tpl": cnt.size(), "top": float(top) / maxf(1, ev.size()), "tri": float(tri.size()) / maxf(1, ev.size() - 2),
		"skel": float(sk.size()) / maxf(1, lg.size()), "met": x.acquaintances().size(), "cnt": cnt}

## 把一段文字切成句子：去掉（…）数值提示，人名换“某”，数字换 N；句末引号跟着前一句
func _sents(x, t: String) -> Array:
	var re := RegEx.new()
	re.compile("（[^）]*）")
	t = re.sub(t, "", true)
	for c in x.w["C"].values():
		t = t.replace(String(c["name"]), "某")
	var rn := RegEx.new()
	rn.compile("[0-9]+")
	t = rn.sub(t, "N", true)
	var out := []
	var cur := ""
	for i in t.length():
		cur += t[i]
		var end := t[i] in ["。", "！", "？"] and not (i + 1 < t.length() and t[i + 1] in ["”", "」"])
		if t[i] in ["”", "」"] and i > 0 and t[i - 1] in ["。", "！", "？"]:
			end = true
		if end:
			if cur.strip_edges() != "":
				out.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out

func _init() -> void:
	var agg := {"top": 0.0, "tri": 0.0, "skel": 0.0, "n": 0.0, "tpl": 0.0, "met": 0.0}
	var all := {}
	for sd in range(7, 15):
		var m := metrics(run(sd, 100))
		lines.append("seed %d: 事件 %d 模板 %d 最常见 %.2f 三连 %.2f 骨架 %.2f 结识 %d" % [sd, m.n, m.tpl, m.top, m.tri, m.skel, m.met])
		for k in agg:
			agg[k] += float(m[k]) / 8.0
		for k in m.cnt:
			all[k] = int(all.get(k, 0)) + m.cnt[k]
	lines.append("均值：%s" % JSON.stringify(agg))
	lines.append("模板计数：%s" % JSON.stringify(all))
	ok(agg.top < 0.20, "最常见模板占比 < 20%%（%.3f）" % agg.top)
	ok(agg.tri > 0.95, "三连序列去重率 > 95%%（%.3f）" % agg.tri)
	ok(agg.skel > 0.65, "生平句骨架去重率 > 65%%（%.3f）" % agg.skel)
	ok(agg.n >= 25, "每 100 日至少 25 件玩家事件（%.1f）" % agg.n)
	# v0.9：模板与人物自主的事分着出，稀有模板少了一半——出现与否改看 16 局（种子 7–22）
	for sd in range(15, 23):
		var m2 := metrics(run(sd, 100))
		for k in m2.cnt:
			all[k] = int(all.get(k, 0)) + m2.cnt[k]
	var miss := []
	for k in ["宗门招徒", "入门试炼", "秘境请柬", "拍卖会", "劫修伏击", "师弟惹祸", "天材地宝", "宝地相争", "对手突破", "旧债上门", "节令"]:
		if int(all.get(k, 0)) == 0:
			miss.append(k)
	ok(miss.is_empty(), "v0.7.2 新事件在 16 局 100 日里都出现过（缺：%s）" % "、".join(miss))
	# v0.7.6：从后窗躲仇人——再上门的开场换一套；躲满三回，对方不再找来（不会每 20 日一字不差地重来）
	var xr = W.new()
	xr.create(77, "苏青禾")
	var foe: Dictionary = xr.npcs()[0]
	var bid := int(foe["id"])
	var texts := []
	var resched := []
	for k in 3:
		xr.fire("仇人上门", {"B": bid}, {})
		texts.append(String(xr.pending()["text"]))
		var q0: int = xr.w["queue"].size()
		var out_r: String = xr.choose("run")
		xr.close()
		resched.append(xr.w["queue"].size() > q0)
		ok(out_r != "" and not out_r.contains("%s"), "后窗躲仇人第 %d 回有结果文字" % (k + 1))
	var again_ok: bool = texts[1] != texts[0] and texts[2] != texts[0] and int(xr.R(foe, xr.P()).get("run", 0)) == 3
	lines.append("后窗躲仇人：再上门开场 %s；是否再排期 %s" % [JSON.stringify(texts.slice(1)), JSON.stringify(resched)])
	ok(again_ok and resched == [true, true, false], "躲过的仇人再上门换开场，躲满三回不再排期")
	# v0.7.5：小师弟/小师妹只给看着年轻、比她小或境界比她低的人；没人合适就现生一个年轻的
	var sd_n := 0
	var sd_bad := []
	for sd in range(7, 23):   # v0.9：16 局（模板份额减半后，8 局样本太少）
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 100:
			x.tick(true)
			var ev = x.pending()
			if ev != null and not ev.is_empty() and ev.get("tid", "") == "师弟惹祸":
				sd_n += 1
				var c: Dictionary = x.C(ev["roles"]["B"])
				if float(c["age"]) >= 36.0 or not (float(c["age"]) < float(x.P()["age"]) or int(c["lv"]) < x.plv()) or x.portrait_opts(c)["elder"] or Portrait5Lib.roll(int(c["pseed"]), x.portrait_opts(c))["beard"] != null:
					sd_bad.append("%s %.0f岁 lv%d" % [c["name"], float(c["age"]), int(c["lv"])])
			x.auto_choose()
	lines.append("师弟惹祸：16 局 100 日 %d 次" % sd_n)
	ok(sd_bad.is_empty() and sd_n >= 3 and sd_n <= 14, "小师弟/小师妹都年轻、比她小或境界低（16 局 %d 次，不合：%s）" % [sd_n, "、".join(sd_bad)])
	# v0.7.7：小师弟不带胡子（选人时看立绘；现生的后辈不抽胡子）。旧人物（无 young 键）立绘逐项不变
	var bd_n := 0
	var bd_bad := []
	for sd in range(1, 41):
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 100:
			x.tick(true)
			var ev = x.pending()
			if ev != null and not ev.is_empty() and ev.get("tid", "") == "师弟惹祸":
				bd_n += 1
				var c: Dictionary = x.C(ev["roles"]["B"])
				var spc = Portrait5Lib.roll(int(c["pseed"]), x.portrait_opts(c))
				if spc["beard"] != null or float(c["age"]) >= 36.0:
					bd_bad.append("%s %.0f岁 %s" % [c["name"], float(c["age"]), spc["beard"]])
			x.auto_choose()
	var same_pv := true
	var nb_any := 0
	for sd in 200:
		var om := {"sex": "m", "elder": false, "demonic": false, "demon_mix": true}
		var on := om.duplicate(); on["no_beard"] = true
		var r1 := Portrait5Lib.roll(sd, om)
		var r2 := Portrait5Lib.roll(sd, on)
		if r1["beard"] != null:
			nb_any += 1
		r1["beard"] = null
		same_pv = same_pv and JSON.stringify(r1) == JSON.stringify(r2)
	lines.append("师弟惹祸（胡子）：40 局 100 日 %d 次" % bd_n)
	ok(bd_bad.is_empty() and bd_n >= 10, "小师弟/小师妹立绘不带胡子（%d 次，不合：%s）" % [bd_n, "、".join(bd_bad)])
	ok(same_pv and nb_any > 20, "no_beard 只去掉胡子，其余部件与原抽签逐项相同（200 个里原本带胡子 %d 个）" % nb_any)
	var oc := {"sex": "男", "age": 20.0, "sect": "散修", "pv": 8, "traits": ["冷淡", "温和"]}
	ok(not a_opts_has_nb(oc), "没有 young 键的人物（旧档/普通 NPC）不加 no_beard")
	var a = run(3, 80)
	var b = run(3, 80, 37)
	var ja := JSON.stringify(JSON.parse_string(JSON.stringify(a.w)))
	var jb := JSON.stringify(JSON.parse_string(JSON.stringify(b.w)))
	if ja != jb:
		for i in ja.length():
			if ja[i] != jb[i]:
				lines.append("差异：" + ja.substr(maxi(0, i - 80), 160) + " ||| " + jb.substr(maxi(0, i - 80), 160))
				break
	ok(ja == jb, "存档往返后继续跑，结果一致（确定性）")
	# 立绘：每个 NPC 的立绘选项可还原
	ok(a.portrait_opts(a.npcs()[0]).has("sex"), "NPC 立绘选项")
	var n0: Dictionary = a.npcs()[0]
	ok(int(n0.get("pv", 0)) >= 7 and not a.portrait_opts(n0).has("exclude"), "新人物可抽 v0.7 立绘部件")
	var old_c := n0.duplicate(true); old_c.erase("pv")
	ok(a.portrait_opts(old_c).get("exclude", []).size() == 9, "旧存档人物不抽新部件（脸不变）")
	var r_old := Portrait5Lib.roll(123, a.portrait_opts(old_c))
	ok(not (r_old["hair"] in a.PV7_NEW) and not (r_old["robe"] in a.PV7_NEW), "旧人物立绘只用旧部件")
	# v0.7.4：魔门新人物袍子有变化；pv7 的魔门旧人物仍是原来那件（脸和衣裳都不变）
	var robes_new := {}
	var same_old := true
	for sd in 40:
		var o7 := {"sex": "f", "elder": false, "demonic": true, "robe_tint": [120, 40, 40]}
		var o8 := o7.duplicate(); o8["demon_mix"] = true
		robes_new[Portrait5Lib.roll(sd, o8)["robe"]] = true
		same_old = same_old and Portrait5Lib.roll(sd, o7)["robe"] == "robe_f3@base_f"
	ok(robes_new.size() >= 3 and same_old, "魔门新人物袍子不止一种（%d 种），旧人物不变" % robes_new.size())
	# v0.9.3：pv10 新人物带 robe_v/sect，能穿新绘宗门服且按宗门加权；pv9 旧人物整份立绘一模一样
	var c9 := n0.duplicate(true); c9["pv"] = 9
	var c10 := n0.duplicate(true); c10["pv"] = 10
	ok(int(a.portrait_opts(c10).get("robe_v", 0)) == 10 and not a.portrait_opts(c9).has("robe_v"), "pv10 人物带 robe_v，pv9 不带")
	var same9 := true
	var new_kinds := {}
	var pref_hit := 0
	for sd in 80:
		var o9 := {"sex": "f" if sd % 2 == 0 else "m", "elder": false, "demonic": false, "demon_mix": true, "robe_tint": [104, 140, 104]}
		var o10 := o9.duplicate(); o10["robe_v"] = 10; o10["sect"] = "药王谷"
		var s9 := Portrait5Lib.roll(sd, o9)
		var s10 := Portrait5Lib.roll(sd, o10)
		var a9 := s9.duplicate(); a9.erase("robe"); a9.erase("outer")
		var a10 := s10.duplicate(); a10.erase("robe"); a10.erase("outer")
		same9 = same9 and JSON.stringify(a9) == JSON.stringify(a10) and JSON.stringify(Portrait5Lib.roll(sd, o9)) == JSON.stringify(s9)
		if int(String(s10["robe"]).get_slice("@", 0).substr(6)) >= 10: new_kinds[s10["robe"]] = true
		if String(s10["robe"]).begins_with("robe_f11") or String(s10["robe"]).begins_with("robe_m11"): pref_hit += 1
	ok(same9 and new_kinds.size() >= 5 and pref_hit >= 12, "robe_v 只换袍子、不动脸和别的签；新袍 %d 种，药王谷穿药师服 %d/80" % [new_kinds.size(), pref_hit])
	# 文字重复度：玩家 100 日里读到的事件文字、结果、自己的生平，按句切开（人名换成“某”、数字换成 N、去掉括号里的数值提示），不同句子占比
	var ur := 0.0
	var worst := ""
	for sd in range(51, 59):
		var x = W.new()
		x.create(sd, "苏青禾")
		var sents := []
		for d in 100:
			x.tick(true)
			var ev = x.pending()
			if ev.is_empty():
				continue
			sents.append_array(_sents(x, String(ev["text"])))
			var o: Array = x._ch(ev["opts"])
			sents.append_array(_sents(x, x.choose(String(o[0]))))
			x.close()
		for l in x.P()["log"]:
			sents.append_array(_sents(x, String(l[1])))
		var uq := {}
		var cnt := {}
		for t in sents:
			uq[t] = 1
			cnt[t] = int(cnt.get(t, 0)) + 1
		ur += float(uq.size()) / maxf(1, sents.size()) / 8.0
		if sd == 51:
			var top := []
			for t in cnt:
				if cnt[t] >= 3:
					top.append("%d×%s" % [cnt[t], t])
			worst = "；".join(top)
	lines.append("100 日不同句子占比 %.3f（种子 51 里出现 ≥3 次的：%s）" % [ur, worst])
	ok(ur >= 0.85, "100 日内玩家读到的句子不同句占比 ≥ 0.85（%.3f）" % ur)
	# 故事线：一局 45 日（约 6 成日子在青庐、其余在路上），玩家总选第一个选项（结伴/救人/应下/收殓/去寻）
	var arcs := {"表白": 0, "道侣遇险": 0, "旧友死讯": 0, "寻凶": 0}
	var tops := 0.0
	for sd in range(21, 29):
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 45:
			var home: bool = (d % 10) < 6
			x.tick(home)
			var ev = x.pending()
			if not ev.is_empty():
				x.choose(String(ev["opts"][0][0]))
				x.close()
		var m := metrics(x)
		tops += m.top / 8.0
		for k in arcs:
			if m.cnt.has(k):
				arcs[k] += 1
	lines.append("45 日故事线（8 局里出现的局数）：%s；最常见模板占比均值 %.3f" % [JSON.stringify(arcs), tops])
	ok(arcs["表白"] >= 7 and arcs["旧友死讯"] >= 7, "45 日内：表白、旧友死讯至少 7/8 局出现")
	ok(arcs["道侣遇险"] >= 6 and arcs["寻凶"] >= 6, "45 日内：道侣遇险、寻凶至少 6/8 局出现（应下/收殓时）")
	ok(tops < 0.20, "45 日局最常见模板占比 < 0.20（%.3f）" % tops)
	# 拒绝型玩家：总选第二个选项（婉拒/遥遥一拜/烧香送走……），后续也要有戏
	var arcs2 := {"婉拒后": 0, "旧友托梦": 0, "仇家寻上门": 0}
	var tops2 := 0.0
	for sd in range(31, 39):
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 45:
			x.tick((d % 10) < 6)
			var ev = x.pending()
			if not ev.is_empty():
				var o: Array = ev["opts"][1] if ev["opts"].size() > 1 else ev["opts"][0]
				x.choose(String(o[0]))
				x.close()
		var m := metrics(x)
		tops2 += m.top / 8.0
		if m.cnt.has("暗恋不舍") or m.cnt.has("怨偶"):
			arcs2["婉拒后"] += 1
		for k in ["旧友托梦", "仇家寻上门"]:
			if m.cnt.has(k):
				arcs2[k] += 1
	lines.append("拒绝型 45 日（8 局里出现的局数）：%s；最常见模板占比均值 %.3f" % [JSON.stringify(arcs2), tops2])
	ok(arcs2["婉拒后"] >= 7 and arcs2["旧友托梦"] >= 7, "拒绝型：婉拒后有暗恋不舍/怨偶、不收殓有旧友托梦，至少 7/8 局")
	ok(arcs2["仇家寻上门"] >= 6, "拒绝型：送走故人后仇家寻上门，至少 6/8 局")
	ok(tops2 < 0.20, "拒绝型 45 日局最常见模板占比 < 0.20（%.3f）" % tops2)
	# 节奏（v0.7.3）：50 日局、约 6 成日子在青庐，16 局均值——既要有事，也别天天有人敲门
	# v0.9：路上也会碰上事（人物自主 + 路上的旧模板），在家与路上分开量
	var pt := 0.0
	var phd := 0.0
	var prd := 0.0
	var ph := 0.0
	var pr := 0.0
	var pst := 0.0
	for sd in range(500, 516):
		var x = W.new()
		x.create(sd, "苏青禾")
		var st := 0
		var smax := 0
		for d in 50:
			var home: bool = (d % 10) < 6
			x.tick(home)
			if home:
				phd += 1
			else:
				prd += 1
			var ev = x.pending()
			if ev.is_empty():
				st = 0
				continue
			pt += 1
			if home:
				ph += 1
			else:
				pr += 1
			st += 1
			smax = maxi(smax, st)
			x.choose(String(ev["opts"][d % ev["opts"].size()][0]))
			x.close()
		pst += smax / 16.0
	lines.append("50 日节奏：%.1f 件/局，在家 %.2f 件/日，路上 %.2f 件/日，最长连续有事 %.1f 日" % [pt / 16.0, ph / phd, pr / prd, pst])
	ok(ph / phd >= 0.35 and ph / phd <= 0.55 and pst <= 3.2, "50 日局：每个在家日 0.35–0.55 件事，最长连着有事 ≤3.2 日（%.2f，%.1f）" % [ph / phd, pst])
	ok(pr / prd >= 0.18 and pr / prd <= 0.45, "50 日局：路上每日 0.18–0.45 件事——有事可遇，又不至于站站都被拦（%.2f）" % (pr / prd))
	# 节令只在历法上的日子出现（第 1 日 = 正月初一，30 日一月）
	var fest_bad := []
	var fest_n := 0
	for sd in [61, 62, 63]:
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 200:
			x.tick(true)
			var ev = x.pending()
			if ev.is_empty():
				continue
			if String(ev["tid"]) == "节令":
				fest_n += 1
				var f := String(ev["ctx"].get("fest", ""))
				var c: Array = W.cal(int(x.w["day"]))
				var md: Array = W.FEST_DATES.get(f, [0, 0])
				if int(md[0]) != int(c[1]) or int(c[2]) < int(md[1]) or int(c[2]) > int(md[1]) + 2 or not String(ev["text"]).contains(f):
					fest_bad.append("%s@%s" % [f, W.cal_text(int(x.w["day"]))])
			x.choose(String(ev["opts"][0][0]))
			x.close()
	lines.append("节令 3 局 × 200 日：%d 次，错日 %s" % [fest_n, JSON.stringify(fest_bad)])
	ok(fest_bad.is_empty() and fest_n >= 9, "节令落在真实日子上（上元正月十五、清明三月初五、端午五月初五……），200 日里多数节都过上")
	# 第三拍：对后话也说不（总挑“拒绝”那一项）→ 远方来信/落难；总选第二项（收下心意→再问→仍婉拒）→ 喜帖
	var REFUSE := ["no", "bye", "cut", "let", "bow", "wait", "pass", "shrug", "hide", "keep_no"]
	var third := {"拒绝到底": 0, "再问又拒": 0, "喜帖": 0}
	for sd in range(31, 47):
		for mode in ["refuse", "second"]:
			var x = W.new()
			x.create(sd, "苏青禾")
			for d in 100:
				x.tick((d % 10) < 6)
				var ev = x.pending()
				if not ev.is_empty():
					var pick: Array = ev["opts"][1] if ev["opts"].size() > 1 else ev["opts"][0]
					if mode == "refuse":
						for o in ev["opts"]:
							if String(o[0]) in REFUSE:
								pick = o
					x.choose(String(pick[0]))
					x.close()
			var cnt: Dictionary = metrics(x).cnt
			if mode == "refuse" and (cnt.has("远方来信") or cnt.has("落难") or cnt.has("喜帖")):
				third["拒绝到底"] += 1
			if mode == "second" and cnt.has("再问"):
				third["再问又拒"] += 1
				if cnt.has("喜帖"):
					third["喜帖"] += 1
	lines.append("第三拍（16 局 100 日里出现的局数）：%s" % JSON.stringify(third))
	ok(third["拒绝到底"] >= 12, "拒绝到底的玩家也有第三拍（远方来信/落难/喜帖），至少 12/16 局")
	ok(third["喜帖"] == third["再问又拒"] and third["再问又拒"] >= 1, "再问仍婉拒的局都有喜帖/辞行（%d/%d）" % [third["喜帖"], third["再问又拒"]])
	# 像真人一样乱点：3 个种子 × 120 日，每件事随机挑一项；检查文字没有漏网的占位符、选项不空、事件不卡住
	var bad := []
	var seen := {}
	for sd in [101, 202, 303]:
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 120:
			x.tick((d % 9) < 6)
			var ev = x.pending()
			if ev.is_empty():
				continue
			seen[String(ev["tid"])] = 1
			var txt := String(ev["text"])
			if txt.strip_edges() == "" or ev["opts"].is_empty():
				bad.append("%s 空文字/无选项" % ev["tid"])
			var o: Array = x._ch(ev["opts"])
			var res: String = x.choose(String(o[0]))
			for t in [txt, res, String(o[1])]:
				if "%s" in t or "%d" in t or "{n}" in t or "{p}" in t or "{m}" in t or "<null>" in t or "Nil" in t:
					bad.append("%s：%s" % [ev["tid"], t.substr(0, 40)])
			x.close()
			if not x.pending().is_empty():
				bad.append("%s 关不掉" % ev["tid"])
		for l in x.P()["log"]:
			var t2 := String(l[1])
			if "%s" in t2 or "%d" in t2 or "<null>" in t2:
				bad.append("生平：" + t2.substr(0, 40))
	lines.append("乱点 3 局 × 120 日：见过 %d 种事件；问题 %s" % [seen.size(), JSON.stringify(bad.slice(0, 8))])
	ok(bad.is_empty(), "乱点 3 局：没有空文字、漏网占位符或关不掉的事件")
	# 旧档补种故事线
	var y = W.new()
	y.create(41, "苏青禾")
	for d in 30:
		y.tick(true)
		if not y.pending().is_empty():
			y.auto_choose()
			y.close()
	y.w.erase("arc")
	var y2 = W.new()
	y2.attach(null, JSON.parse_string(JSON.stringify(y.w)))
	ok(y2.w.has("arc") and int(y2.w["arc"]["death_day"]) > int(y2.w["day"]), "没有故事线的旧档读入时补种，排在今天之后")
	# 接进青庐规则：v1 旧档迁移 + 世界随日子走 + 存读档
	var GS = load("res://scripts/game_state.gd")
	var h = GS.new()
	h.new_game("苏青禾", "aunt", 11)
	var v1: Dictionary = h.to_dict()
	v1["v"] = 1
	v1.erase("world")
	var m = GS.new()
	ok(m.from_dict(JSON.parse_string(JSON.stringify(v1))) and m.world == null, "v1 旧档可读（迁移前没有江湖）")
	m.start_world(99)
	for i in 30:
		m.tick("biguan")
		m.world.auto_choose()
	ok(int(m.world.w["day"]) == 30 and m.world.w["events"].size() > 0, "迁移后江湖随闭关日推进（事件 %d 件）" % m.world.w["events"].size())
	for i in 3:
		m.tick("road")
	ok(int(m.world.w["day"]) == 33, "路上的日子照走（v0.9 起路上也可能碰上事，见“路上奇遇”测试）")
	var m2 = GS.new()
	ok(m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict()))) and m2.world != null and int(m2.world.w["day"]) == 33, "带江湖的 v2 存档往返")
	ok(int(m2.s["v"]) == GS.SAVE_VERSION, "存档版本号 = %d" % GS.SAVE_VERSION)
	# ---------------------------------------------------------------- v0.8（Gemini 评审 v4 后的修正）
	var q = W.new()
	q.create(5, "苏青禾")
	var qp: Dictionary = q.P()
	var qn: Dictionary = q.npcs()[0]
	var op0: float = q.opinion(qn, qp)
	for k in 4:
		q.fav(qn, 0, "救命之恩", 30)
	ok(q.opinion(qn, qp) - op0 <= 25.01, "记忆加成封顶 ±25（4 条 +30 的记忆只加 %.0f）" % (q.opinion(qn, qp) - op0))
	# 硬锁：好感 > 25 或结义/道侣/师徒的人不当劫修、欺客、争果的施害者
	for c in q.npcs():
		q.R(c, qp)["f"] = 40
		q.R(c, qp)["m"] = 1
		q.R(qp, c)["m"] = 1
	var bad_cast := 0
	for k in 40:
		for tid in ["劫修拦路", "坊市欺客", "朱果之争", "劫修伏击", "旧债上门", "魔修袭镇"]:
			if q.bind(tid) != null:
				bad_cast += 1
	ok(bad_cast == 0, "亲近的人从不被选进日常恶意模板（%d 次）" % bad_cast)
	var q2 = W.new()
	q2.create(6, "苏青禾")
	var sworn: Dictionary = q2.npcs()[1]
	q2.R(q2.P(), sworn)["t"].append("结义")
	ok(q2._close_p(sworn), "结义的人算亲近（好感再低也一样）")
	# 慢热：一面之缘救了命，也够不上表白的门槛（要好感 > 45 且同历 ≥ 3 件事）
	var q3 = W.new()
	q3.create(8, "苏青禾")
	var tg8: Dictionary = q3.npcs().filter(func(c): return c["sex"] == "男")[0]
	q3.fire("求助", {"B": int(tg8["id"])}, {})
	q3.choose("help"); q3.close()
	var conf = q3.bind("表白")
	ok(conf == null or int(conf["B"]) != int(tg8["id"]), "救过一回命的人不会立刻来表白")
	# 焦点社交圈
	var q4 = W.new()
	q4.create(9, "苏青禾")
	var ns8: Array = q4.npcs()
	for i in 4:
		q4.R(q4.P(), ns8[i])["m"] = 1
		q4.R(ns8[i], q4.P())["m"] = 1
		q4.R(ns8[i], q4.P())["f"] = 30
		q4.R(q4.P(), ns8[i])["d"] = 0
	ok(q4.active_bonds() == 4, "活跃羁绊计数（%d）" % q4.active_bonds())
	var met_a := 0.0
	var met_b := 0.0
	for sd in range(30, 36):
		var xa = W.new(); xa.create(sd, "苏青禾")
		for d in 80:
			xa.tick(true); xa.auto_choose()
		met_a += xa.acquaintances().size() / 6.0
	lines.append("v0.8 焦点社交圈：80 日平均结识 %.1f 人" % met_a)
	ok(met_a <= 14.0, "80 日内结识的人不再无限增长（%.1f ≤ 14）" % met_a)
	# 骨龄比：新人物（pv 9）金丹百岁不显老；旧人物（pv 8）仍按 75 岁
	var jd := {"sex": "男", "age": 100.0, "lv": 12, "sect": "散修", "pv": 9}
	var jd8 := jd.duplicate(); jd8["pv"] = 8
	ok(not q.portrait_opts(jd)["elder"] and q.portrait_opts(jd8)["elder"], "衰老按寿元剩余比例（pv9），旧人物不变")
	var lq := {"sex": "女", "age": 80.0, "lv": 4, "sect": "散修", "pv": 9}
	ok(q.portrait_opts(lq)["elder"], "炼气八十岁（骨龄比 0.8）白发")
	# 信物：报恩留茶会换信物；人没了，坊市能认出来
	var q5 = W.new()
	q5.create(12, "苏青禾")
	var fr8: Dictionary = q5.npcs()[2]
	q5.fire("报恩", {"B": int(fr8["id"])}, {})
	var r5: String = q5.choose("tea"); q5.close()
	ok(q5.R(q5.P(), fr8).has("ks") and q5.R(fr8, q5.P()).has("ks") and r5.contains(String(q5.R(q5.P(), fr8)["ks"])), "报恩留茶：交换信物（%s）" % r5.split("\n")[-1])
	q5.R(q5.P(), fr8)["m"] = 1
	q5.die(fr8, "死于无名劫修之手")
	var rb5 = q5.bind("坊市认物")
	ok(rb5 != null and int(rb5["B"]) == int(fr8["id"]), "故人死后，坊市能认出当年送的信物")
	q5.fire("坊市认物", rb5, {})
	ok(String(q5.pending()["text"]).contains(String(q5.R(fr8, q5.P())["ks"])), "认物文字里是她送出的那件")
	ok(q5.choose("buy") != "", "认物有结果")
	q5.close()
	# 新模板随机点：都有文字、没有漏网占位符
	var nb := []
	for tid in ["两难", "暗涌", "道途殊归", "重逢", "白首", "借庐", "点化"]:
		for sd in range(40, 46):
			var z = W.new(); z.create(sd, "苏青禾")
			for c in z.npcs():
				z.R(c, z.P())["m"] = 1; z.R(z.P(), c)["m"] = 1
				z.R(c, z.P())["f"] = 30; z.R(z.P(), c)["f"] = 30
				c["age"] = 80.0 if int(c["lv"]) < 9 else float(c["age"])
				z.R(z.P(), c)["lv0"] = [int(c["lv"]) + 3, 0]
				c["lv"] = 0
			var ptn: Dictionary = z.npcs().filter(func(c): return c["sex"] == "男")[0]
			ptn["traits"] = ["淡泊", "温柔"]
			if tid == "道途殊归":
				z.R(z.P(), ptn)["t"].append("道侣"); z.R(ptn, z.P())["t"].append("道侣")
			if tid == "借庐":
				for c in z.npcs().slice(-6):
					z.R(c, z.P())["f"] = 0; z.R(z.P(), c)["f"] = 0
			z.w["day"] = 40
			var rl = z.bind(tid)
			if rl == null:
				nb.append(tid + ":无人")
				continue
			z.fire(tid, rl, {})
			var ev8: Dictionary = z.pending()
			var o8: Array = ev8["opts"][sd % ev8["opts"].size()]
			var res: String = z.choose(String(o8[0]))
			for t2 in [String(ev8["text"]), res]:
				if t2.contains("%") or t2.contains("{") or t2.length() > 170:
					nb.append("%s:%s" % [tid, t2])
			if String(ev8["text"]).strip_edges() == "":
				nb.append(tid + ":空")
			z.close()
	ok(nb.is_empty(), "v0.8 新事件：都能选上人、有文字、无占位符、正文 ≤170 字（%s）" % "；".join(nb.slice(0, 4)))
	# 家里的产出接进事件：有驱瘴丹时，求助多一条“喂丹”，不伤经脉
	var hh = GS.new()
	hh.new_game("苏青禾", "aunt", 21, true)
	hh.s["store"]["pill_quzhang"] = 1
	var hw = hh.world
	var vic: Dictionary = hw.npcs()[0]
	hw.fire("求助", {"B": int(vic["id"])}, {})
	var has_pill := false
	for o in hw.pending()["opts"]:
		if String(o[0]) == "pill":
			has_pill = true
	var inj0 := int(hh.s.get("injured", 0))
	var rp: String = hw.choose("pill"); hw.close()
	ok(has_pill and hh.store_n("pill_quzhang") == 0 and int(hh.s.get("injured", 0)) == inj0 and rp.contains("驱瘴丹"), "求助：喂一粒自炼的驱瘴丹（丹用掉、不受伤）")
	hh.s["store"]["pill_juqi"] = 2
	var cr: Dictionary = hw.npcs()[3]
	hw.fire("旧债上门", {"B": int(cr["id"])}, {})
	var rj: String = hw.choose("dan"); hw.close()
	ok(hh.store_n("pill_juqi") == 1 and int(hh.s["flags"].get("juqi_given", 0)) == 1 and rj.contains("聚气丹"), "旧债：拿自炼的聚气丹抵债（计入 juqi_given）")
	hh.s["store"]["herb_qingzhi"] = 4
	hw.fire("赠礼", {"B": int(cr["id"])}, {})
	var rq: String = hw.choose("qz"); hw.close()
	ok(hh.store_n("herb_qingzhi") == 2 and rq.contains("青芝"), "赠礼：送自家灵田的青芝")
	# 境界差重逢（要青庐的修为）：初见时对方高三层以上，如今她追平了
	hh.s["xiuwei"] = 400
	var up: Dictionary = hw.npcs()[4]
	up["lv"] = 3
	hw.R(hw.P(), up)["m"] = 1; hw.R(up, hw.P())["m"] = 1
	hw.R(hw.P(), up)["lv0"] = [3, 0]
	hw.w["last"].erase("重逢")
	var rr2 = hw.bind("重逢")
	ok(rr2 != null and hw.C(rr2["B"])["lv"] <= hw.plv(), "昔日仰望，今日平视：能选上当年高她三层的人")
	for l in lines:
		print(l)
	print("江湖测试：%d 失败" % fails)
	quit(0 if fails == 0 else 1)

func a_opts_has_nb(c: Dictionary) -> bool:
	var x = W.new()
	x.create(1, "苏青禾")
	return x.portrait_opts(c).has("no_beard")
