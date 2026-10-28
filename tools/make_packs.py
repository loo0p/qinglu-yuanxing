#!/usr/bin/env python3
"""生成 data/packs/*.json：青庐的事件内容包（给 addons/storylet_engine 用）。
- qinglu_core：语法表 + 旧版“江湖自转”的迁移（两人相遇的八种事、独处、破境/走火/坐化/飞升/新人）+ 丧事
- qinglu_life：v0.12 新增的人生阶段事（日常、闭关、同门之争、情愫/表白、道侣、麟儿、收徒、心魔、宗门大比、秘境）
- qinglu_bio：前尘（入青庐之前的经历，Qud 式先定事再成文）
- qinglu_offer：交给她来选的事（满月酒、吊唁、观大比、秘境归来、心魔劫、求拜师、情劫）
改了要重跑本脚本 + tools/make_font.py，再跑 tools/lint_packs.sh（或 tests/saga_test.gd）。"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_saga import G as SAGA
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
G = {k: list(v) for k, v in SAGA.items()}
def g(k, *alts): G[k] = list(alts)

HOST_VARS = ["p", "s", "r", "age", "ta", "y", "pn", "jie"]
HOST_OPS = ["rel", "meet", "tag", "mem", "inj", "home", "move", "die", "rumor", "goal", "lv", "xp", "sect", "wflag",
            "kid", "spawn", "seclude", "xm", "fav", "ling", "wu", "pinj", "pchron", "mark", "beat", "gen_item", "give_item", "take_item", "pick_lost"]

def chron(who, text, **vars):
    o = {"op": "chron", "who": who, "text": text}
    if vars: o["vars"] = vars
    return o
def rel(a, b, f=None, gg=None, both=False):
    o = {"op": "rel", "a": a, "b": b}
    if f is not None: o["f"] = f
    if gg is not None: o["g"] = gg
    if both: o["both"] = True
    return o
def rumor(text, about=("A",), kind="", **vars):
    o = {"op": "rumor", "text": text, "about": list(about)}
    if kind: o["kind"] = kind
    if vars: o["vars"] = vars
    return o
def mem(who, about, text, wt, kind="", **vars):
    o = {"op": "mem", "who": who, "about": about, "text": text, "wt": wt}
    if kind: o["kind"] = kind
    if vars: o["vars"] = vars
    return o
def chance(p, *then, els=None):
    o = {"op": "chance", "p": p, "then": list(then)}
    if els: o["else"] = els
    return o
def iff(cond, *then, els=None):
    o = {"op": "if", "when": cond, "then": list(then)}
    if els: o["else"] = els
    return o
def setv(name, value): return {"op": "set", "name": name, "value": value}
def wflag(key): return {"op": "wflag", "key": key}

# ================================================================ 语法：旧版 VAR / SOLO 原样迁入，再加变体
g("v_lundao", "在{p}与{o}论道半夜。", "与{o}在{p}煮茶谈剑，相见恨晚。", "在{p}得{o}指点，解了一处功法上的疑难。", "与{o}在{p}对弈一局，输了半子。",
  "和{o}在{p}比了一回剑，点到为止。", "在{p}替{o}挡了一场雨，两人聊到天明。", "在{p}与{o}说起各自的师门，说到月上中天。",
  "在{p}和{o}为一句经文争了半日，谁也没说服谁，倒都笑了。", "与{o}在{p}共用一堆篝火，交换了几样干粮。")
g("v_lundao_deep", "在{p}与{o}论道三日，出来时眼里有光。", "听{o}在{p}讲了一夜的剑意，回去后把剑谱重抄了一遍。", "与{o}在{p}论道，被一句话点醒，当场打坐了半日。")
g("v_spar", "在{p}与{o}切磋了三十招，各自记下对方的破绽。", "和{o}在{p}试剑，削断了彼此的一缕头发，都笑了。", "与{o}在{p}比了一场，打完一起去喝了酒。")
g("v_zb_w", "在{p}与{o}争一株灵草，得手。", "从{o}手里抢下一枚兽丹。", "在{p}比{o}先一步拓下残碑。", "在{p}的拍卖会上压了{o}一头，拍走一卷残图。",
  "赶在{o}之前收服了{p}的一只灵狐。", "在{p}与{o}同时看中一块灵石，抢先付了钱。", "在{p}的古洞里与{o}争一只玉匣，先拿到了手。")
g("v_zb_l", "在{p}看中的灵草被{o}夺去。", "到手的兽丹被{o}截了。", "在{p}晚了{o}一步，残碑被拓走了。", "在{p}的拍卖会上叫价输给了{o}。",
  "眼看要收服的灵狐，被{o}抢了先。", "在{p}看中的灵石被{o}先付了钱。", "在{p}的古洞里，玉匣被{o}抢了先。")
g("r_zhengbao", "听说{w}在{p}抢先得了一件宝物，{l}空手而回。", "{w}在{p}和{l}争一株灵草，争赢了。", "{w}从{p}带回一卷残图，据说是从{l}手里截下的。")
g("v_df_w", "在{p}与{o}斗法，胜。", "一剑挑落了{o}的发冠。", "在{p}把{o}逼退三十里。", "在{p}以一道符破了{o}的护体灵光。", "三十招后，{o}的剑断在{p}。",
  "在{p}与{o}斗了半日，最后一掌定了胜负。")
g("v_df_l", "在{p}败于{o}手下，重伤。", "被{o}一掌震伤心脉。", "在{p}输给{o}，养了几个月伤。", "在{p}被{o}的飞剑穿了肩。", "与{o}斗法落败，本命法器裂了一道缝。",
  "在{p}被{o}打落山崖，挂在树上才捡回一条命。")
g("v_df_draw", "在{p}与{o}斗法，斗到天黑不分胜负，各自收手。", "与{o}在{p}交手，两败俱伤，约了来日再战。")
g("r_doufa", "{w}与{l}在{p}斗法，{l}落败。", "{w}在{p}一剑挑伤了{l}。", "{l}在{p}输给了{w}，被抬回了山门。")
g("v_wed", "与{o}结为道侣。", "与{o}在{p}结为道侣，交换了信物。", "与{o}结为道侣。拜天地时，两人都红了眼。")
g("r_wed", "{A}与{B}结为道侣，在{p}摆了三桌素席。", "{A}与{B}在{p}结为道侣，来贺的人站满了半条街。", "听说{A}和{B}结了道侣。")
g("v_drink", "与{o}在{p}喝了一夜的酒。", "与{o}在{p}说了很久的话，天亮才散。")
g("v_shoutu", "收{o}为徒。", "在{p}收{o}为徒，赐了一块玉牌。", "看中{o}的心性，收作弟子。")
g("v_baishi", "拜{o}为师。", "在{p}拜{o}为师，磕了三个头。", "被{o}收作弟子。")
g("v_jieyi", "与{o}义结金兰。", "与{o}在{p}撮土为香，义结金兰。", "与{o}结为异姓兄妹，约定有难同当。")
g("v_beiqi", "弃了道侣{o}，独自远走。", "与道侣{o}割袍断义，头也不回地走了。", "留了一封信给道侣{o}，人已不知去向。")
g("v_beiqi_l", "被{o}所负。", "道侣{o}一走了之，只留下一封信。", "被{o}弃了。那夜在山门口站到天亮。")
g("r_beiqi", "听说{A}负了{B}。", "{A}弃了道侣{B}，一个人走了。")
g("v_fuchou_ok", "在{p}寻到{o}，了结旧仇。", "追了{o}三百里，在{p}了结了旧仇。")
g("v_fuchou_spare", "在{p}寻到{o}，一剑挑落了{o}的兵刃，没有下杀手。", "在{p}截住{o}，赢了，收了剑：“今日饶你。”")
g("v_fuchou_spared", "在{p}败给了寻仇而来的{o}，{o}没有下杀手。")
g("v_fuchou_fail", "寻{o}报仇不成，负伤遁走。", "在{p}截住{o}，没打过，负伤而逃。")
SOLO = {
  "求长生": ["在{p}闭了一回死关。", "寻到半部长生诀，读到天亮。", "在{p}的古洞里找到一具坐化的骸骨，拜了三拜。", "数了数自己的寿元，又多坐了一个周天。", "在{p}寻访一位据说活了八百岁的散修，没寻到。"],
  "寻道侣": ["在{p}的灯会上站了一夜，没等到人。", "托媒的信又退了回来。", "在{p}替人写了一封情书，自己的那封没寄。", "给不知是谁的人刻了一支木簪。", "在{p}的姻缘树下系了一根红绳。"],
  "振兴师门": ["替{s}跑了三处坊市，换回一车灵材。", "把师门塌了的偏殿重新立了起来。", "替{s}收了两个新弟子。", "为{s}的护山大阵补了一角。", "替{s}去{p}讨回了一笔旧账。"],
  "寻亲": ["在{p}打听到一点亲人的消息，又断了。", "梦见幼时的门槛。", "在{p}的旧户籍册里找到一个相近的名字。", "托人往北边送了一封不知寄给谁的信。", "在{p}见到一个眉眼相似的人，追上去，认错了。"],
  "炼一炉九转丹": ["丹炉又炸了，眉毛燎去半边。", "炼出一炉三转丹，离九转还远。", "在{p}寻到一味主药。", "把丹方抄了第三遍，改了两处火候。", "开炉七七四十九日，出来一炉焦炭。"],
  "收个好徒弟": ["在{p}看了十几个孩子的根骨，摇头。", "捡了个孩子，养了三天又送回去了。", "在{p}听说有个放牛娃能引气入体，赶去时人已被收走。", "把自己的入门剑擦了又擦。", "在{p}考校了一个少年三日，少年跑了。"],
  "报仇": ["磨了一夜剑。", "在{p}打听仇人的下落。", "把仇人的名字写在符纸上，烧了。", "在{p}练了一整日的杀招。", "梦见那年的火，醒来手还在抖。"],
  "游遍云梦泽": ["到了{p}，记下一页游记。", "在泽边看了一夜的萤火。", "在{p}的渡口等了三天的船。", "游记写满了第二本。", "在{p}画了一张地图，比旧图多了三条河。"],
}
for k, v in SOLO.items():
    g("solo_" + k, *v)
g("d_dan_done", "九转丹成。", "九转丹成，满室异香，丹炉裂了一道缝。")
g("r_dan", "{A}炼成了九转丹。", "听说{A}的丹炉里出了九转丹，坊市的药价涨了三成。")
g("r_break", "{A}（{s}）突破至{r}。")
g("r_ascend", "天现异象：{A}渡劫飞升。")
g("d_youli_find", "在{p}的溪边拾到#treasure#。", "在{p}的旧墓里摸到#treasure#，拜了三拜才拿。")
g("d_gift_cold", "收到{o}送来的#gift#，放在一边，没回信。", "{o}送来#gift#，转手送了人。")
g("d_gift_greedy", "收到{o}送来的#gift#，掂了掂，拿去坊市换了灵石。")
g("d_visited", "{o}来{p}看望，坐了一下午。", "{o}来访，两人下了一盘棋。", "{o}来了，带了些山下的消息。", "陪来访的{o}在{p}走了一程。")
g("d_split", "与道侣{o}和离了。", "与{o}吵到最后，各自收回了信物。", "与{o}缘尽，从此各走各的路。")
g("d_mend", "与道侣{o}说开了心结，和好如初。", "与{o}吵过之后，又在{p}一起看了一回日落。")
g("r_split", "听说{A}和{B}和离了。", "{A}与{B}的道侣之缘，到头了。")
g("d_duel_w", "与同门{o}约战于{p}，胜了。", "与{o}积怨已久，在{p}一战，挑落了{o}的剑。")
g("d_duel_l", "与同门{o}约战于{p}，败了，伤得不轻。", "与{o}在{p}一战，落败。")
g("d_duel_draw", "与同门{o}在{p}打了一日，不分胜负，打完一起喝了酒。不打不相识。", "与{o}约战，斗到力竭，两人躺在地上笑了。")
g("r_duel", "{A}与同门{B}在{p}约战，闹得满门皆知。", "{s}里两个弟子{A}、{B}积怨已久，终于动了手。")
g("r_xia", "听说{A}在{p}行侠，救了人。", "{p}的凡人说，有个姓{sur}的修士替他们斩了妖。")
g("r_wed2", "{A}向{B}表了心意，两人结为道侣。", "听说{A}与{B}成了道侣，是{A}先开的口。")
g("r_kid", "{A}与{B}添了个孩子，取名{k}。", "{A}家添了丁，名叫{k}。")
g("d_see_master", "回山看望师尊{o}，带了#gift#。", "陪师尊{o}在{p}下了一局棋，输了。", "替师尊{o}守了三日的丹炉。")
g("d_see_tudi", "徒弟{o}回山来看，带了#gift#。", "陪徒弟{o}下了一局棋，赢了。", "徒弟{o}来替自己守丹炉，守了三日。")
g("d_teach", "教徒弟{o}一式剑招，教了十遍。", "考校徒弟{o}的功课，罚{o}抄了三遍心法。", "带徒弟{o}去{p}历练。")
g("d_taught", "师尊{o}教了一式剑招，练到半夜。", "被师尊{o}罚抄了三遍心法。", "随师尊{o}去{p}历练。")
g("r_mijing", "有秘境开启，{n0}等人结伴进去了。", "听说云梦泽深处的秘境开了，进去的人里有{n0}。")
g("r_dabi", "{sect}门内大比，{w1}夺魁。", "{sect}大比落幕，魁首是{w1}。")
g("r_fall", "{A}心魔入体，叛出{s0}，投了血煞门。", "听说{A}走了魔道，{s0}已把{A}除名。")
g("r_mjdie", "{A}陨于秘境，魂灯灭了。")

# 交给她选的事（≤150 字）
g("o_mj_treasure", "{B}从秘境回来，路过青庐，从怀里摸出一只玉匣给她看：“差点没命拿出来。”")
g("o_mj_hurt", "{B}从秘境出来，肩上缠着渗血的布，在青庐门口歇脚。")
g("o_mj_save", "{B}从秘境回来，说里头塌了一半，是拉了同伴一把才出来的。")
g("o_mj_none", "{B}从秘境回来，空着手，坐在青庐的石凳上发呆。")

# ================================================================ qinglu_core：迁移旧版江湖自转
MEET = []
def meet(sid, k, weight, outcomes, when=None, effects=()):
    s = {"id": sid, "trigger": "on:meet", "in": ["A", "B"], "family": "meet", "weight": weight,
         "effects": [wflag("w:" + k)] + list(effects), "outcomes": outcomes, "doc": "旧版 world_event 的“%s”" % k}
    if when: s["when"] = when
    MEET.append(s)

meet("meet_lundao", "论道", "3.0 + max(0.0, (g.opn(A, B) + g.opn(B, A)) / 20.0) + 1.5 * g.mpos(A, B)", [
    {"id": "plain", "weight": 1.0, "effects": [setv("d", "se.ri(6, 15)"), rel("A", "B", f="ctx.d", both=True),
        chron("A", "#v_lundao#", o="B"), chron("B", "#v_lundao#", o="A")]},
    {"id": "deep", "weight": "0.2 + 0.25 * int(g.trt(A, '好奇')) + 0.2 * int(g.trt(B, '淡泊'))", "effects": [setv("d", "se.ri(10, 18)"), rel("A", "B", f="ctx.d", both=True),
        {"op": "xp", "who": "A", "frac": 0.15}, chron("A", "#v_lundao_deep#", o="B"), chron("B", "#v_lundao#", o="A")]},
    {"id": "spar", "weight": "0.15 + 0.4 * int(g.trt(A, '嗜战') or g.trt(B, '嗜战'))", "effects": [setv("d", "se.ri(4, 10)"), rel("A", "B", f="ctx.d", both=True),
        chron("A", "#v_spar#", o="B"), chron("B", "#v_spar#", o="A")]},
])
def zb(W, L):
    return [rel(W, L, gg=5), rel(L, W, gg=20), mem(L, W, "{o}抢了我在{p}看中的灵物", -15, "夺", o=W),
            chron(W, "#v_zb_w#", o=L), chron(L, "#v_zb_l#", o=W), chance(0.3, rumor("#r_zhengbao#", (W, L), w=W, l=L))]
meet("meet_zhengbao", "争宝", "(1.5 + (int(g.trt(A, '贪财')) + int(g.trt(B, '贪财'))) * 2 + int(g.wild(ctx.p)) * 2 + 1.0 * g.mneg(A, B)) * (1.0 - 0.8 * int(g.bonded(A, B)))", [
    {"id": "a", "first": True, "when": "g.lv(A) + se.roll(0, 4) > g.lv(B) + se.roll(0, 4)", "effects": zb("A", "B")},
    {"id": "b", "first": True, "effects": zb("B", "A")},
])
def df(W, L):
    return [rel(L, W, gg=30), {"op": "inj", "who": L, "days": 15}, chron(W, "#v_df_w#", o=L), chron(L, "#v_df_l#", o=W), {"op": "home", "who": L},
            chance(0.5, rumor("#r_doufa#", (W, L), "伤", w=W, l=L)),
            iff("g.lv(%s) - g.lv(%s) >= 3 and (g.trt(%s, '阴狠') or g.side(%s) == '魔') and g.may_kill(%s, %s) and se.chance(0.5)" % (W, L, W, W, W, L),
                {"op": "die", "who": L, "how": "死于{w}之手", "vars": {"w": W}},
                els=[mem(L, W, "{o}伤我", -25, "伤", o=W)])]
meet("meet_doufa", "斗法", "2.0 + max(0.0, -(g.opn(A, B) + g.opn(B, A)) / 15.0) + 1.5 * g.mneg(A, B)", [
    {"id": "draw", "first": True, "when": "se.chance(0.1)", "effects": [rel("A", "B", gg=8, both=True), chron("A", "#v_df_draw#", o="B"), chron("B", "#v_df_draw#", o="A")]},
    {"id": "a", "first": True, "when": "g.lv(A) + se.roll(0, 5) > g.lv(B) + se.roll(0, 5)", "effects": df("A", "B")},
    {"id": "b", "first": True, "effects": df("B", "A")},
], when="not g.bonded(A, B) and (g.opn(A, B) < -20 or g.opn(B, A) < -20 or g.foes(A, B))")
LOVE1 = "(g.opn(A, B) > 35 and g.opn(B, A) > 35 and g.meets(A, B) >= 2)"
LOVE2 = "(A.sect == B.sect and g.f(A, B) > 20 and g.f(B, A) > 20 and g.meets(A, B) >= 2 and g.seeks(A, B))"
meet("meet_daolv", "结为道侣", "6.0 * int(%s) + 5.0 * int(%s)" % (LOVE1, LOVE2), [
    {"id": "prot", "first": True, "when": "g.prot(A) or g.prot(B)", "effects": [rel("A", "B", f=5), chron("A", "#v_drink#", o="B")]},
    {"id": "wed", "first": True, "effects": [{"op": "tag", "a": "A", "b": "B", "t": "道侣"}, chron("A", "#v_wed#", o="B"), chron("B", "#v_wed#", o="A"),
        rumor("#r_wed#", ("A", "B"), "侣"),
        iff("A.goal == '寻道侣'", {"op": "goal", "who": "A", "value": "'求长生'"}), iff("B.goal == '寻道侣'", {"op": "goal", "who": "B", "value": "'求长生'"})]},
], when="A.sex != B.sex and g.single(A) and g.single(B) and (%s or %s)" % (LOVE1, LOVE2))
def st(M, D):
    return [{"op": "tag", "a": M, "b": D, "t": "徒", "t2": "师"}, chron(M, "#v_shoutu#", o=D), chron(D, "#v_baishi#", o=M),
            iff("%s.sect != %s.sect and %s.sect != '散修'" % (D, M, M), {"op": "sect", "who": D, "value": "%s.sect" % M})]
meet("meet_shoutu", "收徒", 4.0, [
    {"id": "a", "first": True, "when": "g.lv(A) > g.lv(B)", "effects": st("A", "B")},
    {"id": "b", "first": True, "effects": st("B", "A")},
], when="abs(g.lv(A) - g.lv(B)) >= 5 and g.opn(A, B) > 25 and g.opn(B, A) > 25 and not g.shi(A, B)")
meet("meet_jieyi", "结义", 2.0, [{"id": "ok", "effects": [{"op": "tag", "a": "A", "b": "B", "t": "结义"}, chron("A", "#v_jieyi#", o="B"), chron("B", "#v_jieyi#", o="A")]}],
     when="A.sex == B.sex and g.opn(A, B) > 40 and g.opn(B, A) > 40 and not g.has_tag(A, B, '结义')")
meet("meet_beiqi", "背弃", 3.0, [{"id": "ok", "effects": [
        {"op": "tag", "a": "A", "b": "B", "t": "道侣", "remove": True}, rel("B", "A", gg=60), mem("B", "A", "{o}负我", -40, "负", o="A"),
        chron("A", "#v_beiqi#", o="B"), chron("B", "#v_beiqi_l#", o="A"), rumor("#r_beiqi#", ("A", "B")),
        iff("g.trt(B, '记仇') or g.trt(B, '痴情')", {"op": "goal", "who": "B", "value": "'报仇'", "gt": "A"})]}],
     when="g.is_partner(A, B) and (g.trt(A, '薄情') or g.trt(A, '阴狠')) and se.chance(0.3)")
meet("meet_fuchou", "复仇", 12.0, [
    # v0.12.1（Gemini v5 P1#6）：侠义之人赢了也不下杀手，除非深仇；输了记下“败给谁”，冷却期内、修为没长不再去
    {"id": "ok", "first": True, "when": "g.lv(A) + se.roll(0, 4) > g.lv(B) + se.roll(0, 3) and g.may_kill(A, B)", "effects": [
        chron("A", "#v_fuchou_ok#", o="B"), {"op": "die", "who": "B", "how": "被{w}寻仇所杀", "vars": {"w": "A"}}, {"op": "goal", "who": "A", "value": "g.newgoal()"}]},
    {"id": "spare", "first": True, "when": "g.lv(A) + se.roll(0, 4) > g.lv(B) + se.roll(0, 3)", "effects": [
        {"op": "inj", "who": "B", "days": 20}, chron("A", "#v_fuchou_spare#", o="B"), chron("B", "#v_fuchou_spared#", o="A"), {"op": "goal", "who": "A", "value": "g.newgoal()"}]},
    {"id": "fail", "first": True, "effects": [{"op": "inj", "who": "A", "days": 25}, {"op": "beat", "a": "A", "b": "B"}, chron("A", "#v_fuchou_fail#", o="B"), rel("B", "A", gg=30)]},
], when="A.goal == '报仇' and int(A.gt) == int(B.id) and not g.cowed(A, B)")

CORE = list(MEET)
# 独处（旧版 solo）：现在是人物“一拍”里的一种；九转丹要先炼过三回才可能成（组合事件）
CORE.append({"id": "solo_goal", "trigger": "actor", "weight": "0.9 * int(not g.busy(A))", "doc": "旧版 solo()",
    "effects": [setv("g0", "A.goal"), setv("aid", "int(A.id)"), wflag("solo:{g0}"), {"op": "flag", "key": "dan:{aid}"}, chron("A", "#solo_{g0}#")],
    "outcomes": [
        {"id": "dan", "when": "A.goal == '炼一炉九转丹' and se.flag('dan:' + str(int(A.id))) >= 3", "weight": 0.06, "effects": [
            chron("A", "#d_dan_done#"), {"op": "lv", "who": "A", "add": 2, "max": 18}, rumor("#r_dan#"), {"op": "goal", "who": "A", "value": "'求长生'"}]},
        {"id": "plain", "weight": 1.0, "effects": [iff("A.goal == '寻道侣' and not g.single(A)", {"op": "goal", "who": "A", "value": "'求长生'"})]},
    ]})
CORE += [
    {"id": "break_big", "trigger": "on:break", "family": "break", "when": "ctx.big", "effects": [chron("A", "#d_break_big#"), rumor("#r_break#", kind="破")],
     "outcomes": [{"id": "promote", "when": "A.sect != '散修' and (g.lv(A) == 12 or g.lv(A) == 15 or g.lv(A) == 18)", "weight": 0.6, "effects": [setv("pl", "g.lv(A)"), chron("A", "#d_promote_{pl}#")]},
                  {"id": "plain", "weight": 0.4}]},
    {"id": "break_small", "trigger": "on:break", "family": "break", "when": "not ctx.big",
     "outcomes": [{"id": "say", "weight": 0.25, "effects": [chron("A", "#d_break_small#")]}, {"id": "quiet", "weight": 0.75}]},
    {"id": "break_fail", "trigger": "on:break_fail", "effects": [chron("A", "#d_break_fail#")],
     "outcomes": [{"id": "xinmo", "weight": "0.2 + 0.2 * int(g.trt(A, '多疑'))", "effects": [{"op": "run", "id": "xinmo_start"}]}, {"id": "plain", "weight": 1.0}]},
    {"id": "newcomer", "trigger": "on:newcomer", "effects": [iff("A.sect == '散修'", chron("A", "#d_newcomer_san#"), els=[chron("A", "#d_newcomer#")])]},
    {"id": "ascend", "trigger": "on:ascend", "effects": [chron("A", "#d_ascend#"), rumor("#r_ascend#")]},
    # 丧事：同一个信号，徒弟、道侣、她各自一条（不同 family，同时发）
    {"id": "mourn_tudi", "trigger": "on:death", "family": "mourn_tudi", "roles": [{"name": "D", "from": "g.disciples(A)", "each": True, "limit": 5}],
     "effects": [setv("aid", "int(A.id)"), iff("se.flag('inh:' + str(ctx.aid)) == 0", chron("D", "#d_inherit#", o="A"), {"op": "flag", "key": "inh:{aid}", "set": 1})],
     "outcomes": [
        {"id": "ok", "weight": "1.0 + int(g.trt(D, '淡泊')) + 0.5 * int(g.trt(D, '傲气'))", "effects": [chron("D", "#d_mourn_ok#", o="A"), {"op": "xp", "who": "D", "frac": 0.6}]},
        {"id": "low", "weight": "1.5 + int(g.trt(D, '痴情')) + 0.5 * int(g.trt(D, '温柔'))", "effects": [chron("D", "#d_mourn_low#", o="A"), {"op": "inj", "who": "D", "days": 10}]},
        {"id": "drop", "when": "g.lv(D) > 0", "weight": "0.3 + 0.8 * int(g.trt(D, '痴情')) + 0.4 * int(g.trt(D, '记仇'))", "effects": [chron("D", "#d_mourn_drop#", o="A"), {"op": "lv", "who": "D", "add": -1}]},
     ]},
    {"id": "mourn_partner", "trigger": "on:death", "family": "mourn_partner", "roles": [{"name": "B", "fixed": "g.partner(A)"}],
     "effects": [chron("B", "#d_partner_lost#", o="A"), iff("g.kids(B) > 0", chron("B", "#d_kid_lost#", o="A", k="=g.kid(B)"))],
     "outcomes": [{"id": "xinmo", "weight": "0.25 + 0.4 * int(g.trt(B, '痴情'))", "effects": [{"op": "run", "id": "xinmo_start", "cast": {"A": "B"}}]},
                  {"id": "goal", "when": "g.trt(B, '记仇') or g.trt(B, '痴情')", "weight": 0.3, "effects": [{"op": "goal", "who": "B", "value": "'报仇'"}]},
                  {"id": "plain", "weight": 1.0}]},
    {"id": "mourn_offer", "trigger": "on:death", "family": "mourn_offer", "when": "g.known(A)",
     "roles": [{"name": "B", "from": "g.mourners(A)", "where": "not g.busy(SELF)"}],
     "effects": [{"op": "offer", "id": "吊唁", "cast": {"B": "B", "D": "A"}}]},
]

# ================================================================ qinglu_life：v0.12 新增
NB = "not g.busy(A)"
LIFE = [
    {"id": "youli", "trigger": "actor", "weight": 1.2, "when": NB, "outcomes": [
        {"id": "plain", "weight": 1.0, "effects": [chron("A", "#d_youli#")]},
        {"id": "find", "weight": "0.08 + 0.1 * int(g.trt(A, '好奇'))", "effects": [chron("A", "#d_youli_find#"), {"op": "xp", "who": "A", "frac": 0.1}]}]},
    {"id": "like", "trigger": "actor", "weight": 1.0, "when": NB, "effects": [setv("like", "g.like(A)"), chron("A", "#d_like_{like}#")]},
    {"id": "sectday", "trigger": "actor", "weight": 0.9, "when": NB, "effects": [setv("sct", "A.sect if (A.sect != '散修' or g.lv(A) < 9) else '散修高'"), chron("A", "#d_sect_{sct}#")]},
    {"id": "gift", "trigger": "actor", "weight": 0.9, "when": NB, "roles": [{"name": "B", "where": "g.met(A, SELF) and g.opn(A, SELF) > 15", "weight": "max(1.0, g.opn(A, SELF))"}],
     "effects": [chron("A", "#d_gift_give#", o="B"), rel("A", "B", f=2)],
     "outcomes": [
        {"id": "warm", "weight": 1.0, "effects": [chron("B", "#d_gift_get#", o="A"), rel("B", "A", f=5), mem("B", "A", "{o}送过东西来", 4, o="A")]},
        {"id": "cold", "weight": "2.0 * int(g.trt(B, '薄情'))", "effects": [chron("B", "#d_gift_cold#", o="A")]},
        {"id": "greedy", "weight": "1.0 * int(g.trt(B, '贪财'))", "effects": [chron("B", "#d_gift_greedy#", o="A"), rel("B", "A", f=1)]}]},
    {"id": "visit", "trigger": "actor", "weight": 0.9, "when": NB, "roles": [{"name": "B", "where": "g.met(A, SELF) and g.opn(A, SELF) > 5 and not g.busy(SELF)"}],
     "effects": [chron("A", "#d_visit#", o="B"), chron("B", "#d_visited#", o="A"), rel("A", "B", f=3, both=True), {"op": "meet", "a": "A", "b": "B"}]},
    {"id": "couple", "trigger": "actor", "weight": 2.0, "when": NB + " and g.partner(A) != null", "roles": [{"name": "B", "fixed": "g.partner(A)"}],
     "effects": [setv("pk", "g.pk(A, B)")],
     "outcomes": [
        {"id": "sweet", "weight": 3.0, "effects": [chron("A", "#d_couple#", o="B"), rel("A", "B", f=2, both=True)]},
        {"id": "fight", "weight": "0.4 + 0.8 * int(g.trt(A, '多疑')) + 0.6 * int(g.trt(A, '傲气')) + 0.3 * g.mneg(A, B)", "effects": [
            chron("A", "#d_couple_fight#", o="B"), rel("A", "B", gg=6), {"op": "flag", "key": "cf:{pk}"},
            iff("se.flag('cf:' + ctx.pk) >= 3", {"op": "flag", "key": "cf:{pk}", "set": 0}, {"op": "schedule", "id": "couple_split", "in": [3, 10]})]}]},
    {"id": "couple_split", "trigger": "chain", "in": ["A", "B"], "when": "g.is_partner(A, B)", "outcomes": [
        {"id": "split", "weight": "0.6 + 2.0 * int(g.trt(A, '薄情')) + 0.5 * int(g.trt(B, '傲气'))", "effects": [
            {"op": "tag", "a": "A", "b": "B", "t": "道侣", "remove": True}, chron("A", "#d_split#", o="B"), chron("B", "#d_split#", o="A"),
            rel("B", "A", gg=15), rumor("#r_split#", ("A", "B"))]},
        {"id": "mend", "weight": "1.5 + int(g.trt(B, '温柔')) + int(g.trt(A, '痴情'))", "effects": [chron("A", "#d_mend#", o="B"), chron("B", "#d_mend#", o="A"), rel("A", "B", f=10, both=True)]}]},
    {"id": "close_in", "trigger": "actor", "weight": "0.5 + 0.5 * int(A.goal == '求长生')", "when": NB + " and g.lv(A) >= 3 and not g.xm(A)", "actor_cooldown": 40,
     "effects": [setv("dd", "se.ri(8, 20)"), setv("nr", "g.next_realm(A)"), {"op": "seclude", "who": "A", "days": "ctx.dd"}, chron("A", "#d_close_in#"),
                 {"op": "schedule", "id": "close_out", "in": "ctx.dd"}]},
    {"id": "close_out", "trigger": "chain", "outcomes": [
        {"id": "ok", "weight": "1.0 + 0.5 * int(g.trt(A, '淡泊'))", "effects": [chron("A", "#d_close_ok#"), {"op": "xp", "who": "A", "frac": 0.45}]},
        {"id": "meh", "weight": 1.0, "effects": [chron("A", "#d_close_meh#")]}]},
    {"id": "rival", "trigger": "actor", "weight": 0.8, "when": NB + " and A.sect != '散修'",
     "roles": [{"name": "B", "from": "g.mates(A)", "where": "abs(g.lv(SELF) - g.lv(A)) <= 2 and not g.bonded(A, SELF)"}],
     "effects": [setv("pk", "g.pk(A, B)"), {"op": "flag", "key": "rv:{pk}"}],
     "outcomes": [
        {"id": "lose", "weight": "1.0 + max(0, g.lv(B) - g.lv(A))", "effects": [chron("A", "#d_rival#", o="B"), rel("A", "B", gg=6)]},
        {"id": "win", "weight": "1.0 + max(0, g.lv(A) - g.lv(B))", "effects": [chron("A", "#d_rival_win#", o="B"), rel("B", "A", gg=6)]}],
     "after": None},
    {"id": "rival_duel", "trigger": "chain", "in": ["A", "B"], "when": "not g.bonded(A, B)",
     "effects": [chance(0.5, rumor("#r_duel#", ("A", "B")))],
     "outcomes": [
        {"id": "draw", "first": True, "when": "se.chance(0.25)", "effects": [chron("A", "#d_duel_draw#", o="B"), chron("B", "#d_duel_draw#", o="A"), rel("A", "B", f=15, gg=-10, both=True)]},
        {"id": "a", "first": True, "when": "g.lv(A) + se.roll(0, 4) > g.lv(B) + se.roll(0, 4)", "effects": [chron("A", "#d_duel_w#", o="B"), chron("B", "#d_duel_l#", o="A"), {"op": "inj", "who": "B", "days": 12}, rel("B", "A", gg=15)]},
        {"id": "b", "first": True, "effects": [chron("B", "#d_duel_w#", o="A"), chron("A", "#d_duel_l#", o="B"), {"op": "inj", "who": "A", "days": 12}, rel("A", "B", gg=15)]}]},
    {"id": "xia", "trigger": "actor", "weight": "0.15 + 1.2 * int(g.trt(A, '侠义')) + 0.5 * int(g.trt(A, '温柔'))", "when": NB,
     "effects": [chron("A", "#d_xia#"), chance(0.2, rumor("听说{A}在{p}行侠，救了人。"))]},
    {"id": "bad", "trigger": "actor", "weight": "0.1 + 1.0 * int(g.trt(A, '阴狠')) + 0.6 * int(g.trt(A, '贪财')) + 0.5 * int(g.side(A) == '魔')", "when": NB,
     "effects": [chron("A", "#d_bad#")]},
    {"id": "crush", "trigger": "actor", "weight": "1.2 * (1.0 + int(A.goal == '寻道侣') + 0.5 * int(g.trt(A, '痴情')) - 0.8 * int(g.trt(A, '薄情')))",
     "when": NB + " and g.single(A) and g.lf(A) < 0.8 and not g.prot(A)",
     "roles": [{"name": "B", "where": "SELF.sex != A.sex and g.single(SELF) and g.met(A, SELF) and g.opn(A, SELF) > 10 and not g.shi(A, SELF) and not g.prot(SELF)", "weight": "max(1.0, g.opn(A, SELF))"}],
     "effects": [setv("ab", "str(int(A.id)) + '>' + str(int(B.id))"), {"op": "flag", "key": "cr:{ab}"}, chron("A", "#d_crush#", o="B"), rel("A", "B", f=2),
                 iff("g.known(A) and se.chance(0.3)", {"op": "offer", "id": "情劫", "cast": {"B": "A", "C": "B"}}),
                 iff("se.flag('cr:' + ctx.ab) >= 2 and se.chance(0.2 + 0.3 * int(not g.trt(A, '怯懦')))", {"op": "flag", "key": "cr:{ab}", "set": 0},
                     {"op": "schedule", "id": "confess", "in": [3, 12]})]},
    {"id": "confess", "trigger": "chain", "in": ["A", "B"], "actor_cooldown": 30, "when": "g.single(A) and g.single(B) and not g.prot(A) and not g.prot(B)",
     "outcomes": [
        {"id": "ok", "weight": "max(0.1, (g.opn(B, A) + 10.0) / 30.0) + 0.8 * se.flag('qj:' + str(int(A.id)))", "effects": [
            {"op": "tag", "a": "A", "b": "B", "t": "道侣"}, chron("A", "#d_confess_ok#", o="B"), chron("B", "#d_confess_got_ok#", o="A"),
            rumor("#r_wed2#", ("A", "B"), "侣"), wflag("w:结为道侣"), setv("aid", "int(A.id)"), {"op": "flag", "key": "qj:{aid}", "set": 0},
            iff("A.goal == '寻道侣'", {"op": "goal", "who": "A", "value": "'求长生'"})]},
        {"id": "no", "weight": "max(0.2, (20.0 - g.opn(B, A)) / 25.0)", "effects": [
            chron("A", "#d_confess_no#", o="B"), chron("B", "#d_confess_got_no#", o="A"), rel("A", "B", f=-5),
            chance(0.5, chron("A", "#d_heart_broken#")), iff("g.trt(A, '记仇')", rel("A", "B", gg=10)),
            chance("0.12 + 0.3 * int(g.trt(A, '痴情'))", {"op": "run", "id": "xinmo_start", "cast": {"A": "A"}})]}]},
    {"id": "kid", "trigger": "actor", "weight": 0.35, "when": NB + " and g.partner(A) != null and g.kids(A) < 2 and g.lf(A) < 0.7 and A.sex == '女'", "actor_cooldown": 120,
     "roles": [{"name": "B", "fixed": "g.partner(A)"}],
     "effects": [{"op": "kid", "who": "A", "with": "B"}, chron("A", "#d_kid#"), chron("B", "#d_kid#"), chance(0.5, rumor("#r_kid#", ("A", "B"))),
                 {"op": "schedule", "id": "kid_month", "in": 30, "keep": ["k"]}]},
    {"id": "kid_month", "trigger": "chain", "in": ["A", "B"], "dead_ok": ["B"], "effects": [
        chron("A", "#d_kid_month#"), iff("B.alive", chron("B", "#d_kid_month#")),
        iff("g.known(A)", {"op": "offer", "id": "满月酒", "cast": {"B": "A", "C": "B"}, "keep": ["k"]},
            els=[iff("g.known(B) and B.alive", {"op": "offer", "id": "满月酒", "cast": {"B": "B", "C": "A"}, "keep": ["k"]})])]},
    {"id": "kid_day", "trigger": "actor", "weight": "0.6 * int(g.kids(A) > 0)", "when": NB, "effects": [setv("k", "g.kid(A)"), chron("A", "#d_kid_day#")]},
    {"id": "take_tudi", "trigger": "actor", "weight": "0.3 + 0.6 * int(A.goal == '收个好徒弟')", "actor_cooldown": 90,
     "when": NB + " and g.lv(A) >= 12 and A.sect != '散修' and g.ndisc(A) < 3 and g.pop() < 32",
     "roles": [{"name": "D", "fixed": "null", "optional": True}],
     "effects": [{"op": "spawn", "who": "A", "as": "D"},
                 iff("D != null", {"op": "tag", "a": "A", "b": "D", "t": "徒", "t2": "师"}, chron("A", "#d_take_tudi#", o="D"), chron("D", "#d_tudi_new#", o="A"),
                     rel("A", "D", f=20, both=True), iff("A.goal == '收个好徒弟'", {"op": "goal", "who": "A", "value": "'求长生'"}))]},
    {"id": "see_master", "trigger": "actor", "weight": 0.6, "when": NB + " and g.master(A) != null", "roles": [{"name": "B", "fixed": "g.master(A)"}],
     "effects": [chron("A", "#d_see_master#", o="B"), chron("B", "#d_see_tudi#", o="A"), rel("A", "B", f=3, both=True)]},
    {"id": "teach", "trigger": "actor", "weight": 0.7, "when": NB + " and g.ndisc(A) > 0", "roles": [{"name": "D", "from": "g.disciples(A)"}],
     "effects": [chron("A", "#d_teach#", o="D"), chron("D", "#d_taught#", o="A"), {"op": "xp", "who": "D", "frac": 0.1}, rel("D", "A", f=2)]},
    {"id": "old", "trigger": "actor", "weight": 3.0, "when": "g.lf(A) > 0.9", "actor_cooldown": 99999, "effects": [chron("A", "#d_old#")]},
    {"id": "seek_player", "trigger": "actor", "weight": 0.4, "max": 3, "actor_cooldown": 9999,
     "when": NB + " and g.known(A) and g.plv() >= 9 and g.lv(A) + 3 <= g.plv() and not g.shi(A, g.player()) and g.lf(A) < 0.4 and g.master(A) == null",
     "effects": [{"op": "offer", "id": "求拜师", "cast": {"B": "A"}}]},
    {"id": "xinmo_spont", "trigger": "actor", "weight": "0.1 + 0.25 * int(g.trt(A, '多疑')) + 0.2 * int(g.trt(A, '记仇')) + 0.2 * int(g.trt(A, '痴情'))",
     "when": NB + " and g.lv(A) >= 6 and not g.xm(A)", "actor_cooldown": 120, "effects": [{"op": "run", "id": "xinmo_start"}]},
    {"id": "xinmo_start", "trigger": "chain", "when": "not g.xm(A)", "effects": [
        {"op": "xm", "who": "A", "set": 1}, chron("A", "#d_xinmo_in#"), {"op": "schedule", "id": "xinmo_out", "in": [10, 25]},
        iff("g.known(A)", {"op": "offer", "id": "心魔劫", "cast": {"B": "A"}})]},
    {"id": "xinmo_out", "trigger": "chain", "effects": [{"op": "xm", "who": "A", "set": 0}, setv("aid", "int(A.id)"), setv("s0", "A.sect"), setv("hp", "se.flag('xmh:' + str(int(A.id)))")],
     "outcomes": [
        {"id": "ok", "weight": "1.0 + 0.6 * int(g.trt(A, '淡泊')) + 0.8 * ctx.hp", "effects": [chron("A", "#d_xinmo_ok#"), {"op": "xp", "who": "A", "frac": 0.3}, {"op": "flag", "key": "xmh:{aid}", "set": 0}]},
        {"id": "bad", "weight": "1.0 + 0.4 * int(g.trt(A, '多疑'))", "effects": [chron("A", "#d_xinmo_bad#"), {"op": "inj", "who": "A", "days": 15}, {"op": "flag", "key": "xmh:{aid}", "set": 0}]},
        {"id": "fall", "weight": "(0.12 + 0.4 * int(g.trt(A, '阴狠'))) * int(g.side(A) == '正') * max(0.0, 1.0 - 0.5 * ctx.hp)", "effects": [
            chron("A", "#d_xinmo_fall#"), {"op": "sect", "who": "A", "value": "'血煞门'"}, {"op": "home", "who": "A"}, rumor("#r_fall#")]}]},
    # 世界级（每日掷一次）
    {"id": "dabi", "trigger": "daily", "p": 0.02, "cooldown": 20, "when": "g.dabi_sect() != ''",
     "effects": [setv("sect", "g.dabi_sect()"), {"op": "mark", "key": "dabi:{sect}"}, setv("rk", "g.dabi_rank(ctx.sect)"),
                 rumor("#r_dabi#", (), w1="=g.nm(ctx.rk[0])"), {"op": "run", "id": "dabi_x", "keep": ["sect", "rk"]}]},
    {"id": "dabi_x", "trigger": "chain", "roles": [{"name": "X", "from": "g.ids(ctx.rk)", "each": True, "limit": 12}],
     "outcomes": [
        {"id": "win", "first": True, "when": "g.rank_of(X, ctx.rk) == 1", "effects": [
            chron("X", "#d_dabi_1#"), {"op": "xp", "who": "X", "frac": 0.2},
            {"op": "cast", "name": "M", "fixed": "g.master(X)"}, iff("M != null", chron("M", "#d_dabi_master#", o="X", rk="=g.cnr(X, ctx.rk)")), {"op": "drop", "name": "M"},
            iff("g.known(X)", {"op": "offer", "id": "观大比", "cast": {"B": "X"}, "ctx": {"rk": "g.cnr(X, ctx.rk)", "sect": "ctx.sect"}})]},
        {"id": "upset", "first": True, "when": "g.upset_over(X, ctx.rk) != null and se.chance(0.6)", "effects": [
            {"op": "cast", "name": "O", "fixed": "g.upset_over(X, ctx.rk)"},
            iff("O != null", chron("X", "#d_dabi_upset#", o="O"), chron("O", "#d_dabi_grudge#", o="X"), rel("O", "X", gg=8)), {"op": "drop", "name": "O"}]},
        {"id": "top", "first": True, "when": "g.rank_of(X, ctx.rk) <= 3", "effects": [chron("X", "#d_dabi_top#", rk="=g.cnr(X, ctx.rk)"),
            iff("g.known(X)", {"op": "offer", "id": "观大比", "cast": {"B": "X"}, "ctx": {"rk": "g.cnr(X, ctx.rk)", "sect": "ctx.sect"}})]},
        {"id": "mid", "first": True, "when": "g.rank_of(X, ctx.rk) * 2 <= ctx.rk.size()", "effects": [
            {"op": "cast", "name": "O", "fixed": "g.beat_by(X, ctx.rk)"}, iff("O != null", chron("X", "#d_dabi_mid#", o="O", rk="=g.cnr(X, ctx.rk)")), {"op": "drop", "name": "O"}]},
        {"id": "out", "first": True, "effects": [
            {"op": "cast", "name": "O", "fixed": "g.beat_by(X, ctx.rk)"},
            iff("O != null", chron("X", "#d_dabi_out#", o="O"), iff("g.trt(X, '记仇') or g.trt(X, '傲气')", rel("X", "O", gg=6), chron("X", "#d_dabi_grudge#", o="O"))),
            {"op": "drop", "name": "O"}]}]},
    {"id": "mijing", "trigger": "daily", "p": 0.018, "cooldown": 40, "when": "g.mj_ok()",
     "effects": [setv("party", "g.mj_ids(se.ri(3, 5))"), setv("p", "'秘境'"), rumor("#r_mijing#", (), n0="=g.nm(ctx.party[0])"), {"op": "run", "id": "mijing_x", "keep": ["party", "p"]}]},
    {"id": "mijing_x", "trigger": "chain", "roles": [{"name": "X", "from": "g.ids(ctx.party)", "each": True, "limit": 6}],
     "effects": [chron("X", "#d_mj_in#")],
     "outcomes": [
        {"id": "treasure", "weight": "1.0 + 0.5 * int(g.trt(X, '好奇'))", "effects": [chron("X", "#d_mj_treasure#"), {"op": "xp", "who": "X", "frac": 0.2},
            iff("g.known(X)", {"op": "offer", "id": "秘境归来", "cast": {"B": "X"}, "ctx": {"res": "'treasure'"}})]},
        {"id": "hurt", "weight": "0.7 + 0.5 * int(g.trt(X, '嗜战'))", "effects": [chron("X", "#d_mj_hurt#"), {"op": "inj", "who": "X", "days": 15},
            iff("g.known(X)", {"op": "offer", "id": "秘境归来", "cast": {"B": "X"}, "ctx": {"res": "'hurt'"}})]},
        {"id": "none", "weight": 1.0, "effects": [chron("X", "#d_mj_none#")]},
        {"id": "save", "weight": "0.4 + 0.4 * int(g.trt(X, '侠义'))", "effects": [
            {"op": "cast", "name": "Y", "from": "g.ids(ctx.party)", "where": "int(SELF.id) != int(X.id)", "else": [chron("X", "#d_mj_none#")]},
            iff("Y != null", chron("X", "#d_mj_save#", o="Y"), chron("Y", "#d_mj_saved#", o="X"), rel("Y", "X", f=15), mem("Y", "X", "{o}在秘境里救过我", 20, "救", o="X"),
                iff("g.known(X)", {"op": "offer", "id": "秘境归来", "cast": {"B": "X"}, "ctx": {"res": "'save'"}})),
            {"op": "drop", "name": "Y"}]},
        {"id": "rob", "weight": "0.15 + 0.6 * int(g.trt(X, '贪财')) + 0.6 * int(g.trt(X, '阴狠'))", "effects": [
            {"op": "cast", "name": "Y", "from": "g.ids(ctx.party)", "where": "int(SELF.id) != int(X.id)", "else": [chron("X", "#d_mj_none#")]},
            iff("Y != null", chron("X", "#d_mj_rob#", o="Y"), chron("Y", "#d_mj_robbed#", o="X"), rel("Y", "X", gg=20), mem("Y", "X", "{o}在秘境里夺我的东西", -20, "夺", o="X")),
            {"op": "drop", "name": "Y"}]},
        {"id": "die", "weight": "0.06 * int(not g.prot(X))", "effects": [{"op": "die", "who": "X", "how": "#d_mj_die#"}]}]},
]
for s in LIFE:
    s.pop("after", None)
    if s["trigger"] == "chain" and "in" not in s and "roles" not in s:
        s["in"] = ["A"]

# rival 的组合：同一对积怨三回 → 约战（连锁）
for s in LIFE:
    if s["id"] == "rival":
        s["effects"].append(iff("se.flag('rv:' + ctx.pk) >= 3", {"op": "flag", "key": "rv:{pk}", "set": 0}, {"op": "schedule", "id": "rival_duel", "in": [5, 15]}))

# ================================================================ qinglu_bio：前尘
FREE_HI = "g.agei(A) - 1"
BIO = [
    {"id": "bio_origin", "trigger": "bio", "order": 0, "age": [0, 0], "effects": [setv("sx", "g.sx(A)"), chron("A", "#pre_origin{sx}#")]},
    {"id": "bio_dao", "trigger": "bio", "order": 1, "age": [6, 12], "effects": [chron("A", "#pre_dao#")]},
    {"id": "bio_join", "trigger": "bio", "order": 2, "age": ["ctx.age + 1", "min(ctx.age + 5, g.agei(A) - 1)"],
     "effects": [setv("jt", "g.jt(A)"), setv("join", "ctx.age"), chron("A", "#pre_join{jt}#")]},
    {"id": "bio_master_real", "trigger": "bio", "order": 3, "when": "A.sect != '散修' and ctx.old == 0", "p": 0.5, "age": ["ctx.age", "min(ctx.age + 3, g.agei(A) - 1)"],
     "roles": [{"name": "M", "from": "g.mates(A)", "where": "g.lv(SELF) >= g.lv(A) + 3 and g.age(SELF) > g.age(A) + 15 and not g.shi(A, SELF) and g.disc_ok(SELF)"}],
     "effects": [setv("mreal", 1), {"op": "tag", "a": "M", "b": "A", "t": "徒", "t2": "师"}, rel("A", "M", f=30), rel("M", "A", f=20), chron("A", "#pre_master#", m="M")]},
    {"id": "bio_master_fake", "trigger": "bio", "order": 4, "when": "A.sect != '散修' and ctx.get('mreal', 0) == 0", "p": 0.8, "age": ["ctx.age", "min(ctx.age + 3, g.agei(A) - 1)"],
     "effects": [setv("m", "g.fake_name(['女', '男'][se.ri(0, 1)], se.ri(0, 999999))"), setv("mfake", 1), chron("A", "#pre_master#")]},
    {"id": "bio_master_die", "trigger": "bio", "order": 5, "free_age": True, "when": "ctx.get('mfake', 0) == 1", "p": 0.45, "age": ["ctx.age + 2", FREE_HI],
     "effects": [chron("A", "#pre_master_die#")]},
    {"id": "bio_break", "trigger": "bio", "order": 6, "when": "g.lv(A) >= 9", "age": ["ctx.age + 3", "g.agei(A) - 2 * (g.lv(A) - 9) - 1"], "effects": [chron("A", "#pre_break#")]},
    {"id": "bio_jindan", "trigger": "bio", "order": 7, "when": "g.lv(A) >= 12", "age": ["ctx.age + 5", "g.agei(A) - 2 * (g.lv(A) - 12) - 1"], "effects": [chron("A", "#pre_jindan#")]},
    {"id": "bio_yuanying", "trigger": "bio", "order": 8, "when": "g.lv(A) >= 15", "age": ["ctx.age + 8", "g.agei(A) - 2"], "effects": [chron("A", "#pre_yuanying#")]},
    {"id": "bio_dabi", "trigger": "bio", "order": 10, "free_age": True, "when": "A.sect != '散修' and g.side(A) != '魔'", "p": 0.5, "age": ["ctx.join + 2", FREE_HI], "effects": [chron("A", "#pre_dabi#")]},
    {"id": "bio_mijing", "trigger": "bio", "order": 11, "free_age": True, "when": "g.lv(A) >= 3", "p": 0.45, "age": ["ctx.join + 2", FREE_HI], "effects": [chron("A", "#pre_mijing#")]},
    {"id": "bio_xinmo", "trigger": "bio", "order": 12, "free_age": True, "when": "g.lv(A) >= 6", "p": 0.3, "age": ["ctx.join + 4", FREE_HI], "effects": [chron("A", "#pre_xinmo#")]},
    {"id": "bio_youli", "trigger": "bio", "order": 13, "free_age": True, "p": 0.6, "age": ["ctx.join + 1", FREE_HI], "effects": [chron("A", "#pre_youli#")]},
    {"id": "bio_youli2", "trigger": "bio", "order": 14, "free_age": True, "p": 0.3, "age": ["ctx.join + 1", FREE_HI], "effects": [chron("A", "#pre_youli#")]},
    {"id": "bio_like", "trigger": "bio", "order": 15, "free_age": True, "p": 0.55, "age": [10, FREE_HI], "effects": [setv("like", "g.like(A)"), chron("A", "#pre_like_{like}#")]},
    {"id": "bio_goal", "trigger": "bio", "order": 16, "free_age": True, "when": "A.goal != '报仇'", "p": 0.65, "age": [12, FREE_HI], "effects": [setv("g0", "A.goal"), chron("A", "#pre_goal_{g0}#")]},
    {"id": "bio_love", "trigger": "bio", "order": 17, "free_age": True, "when": "g.agei(A) >= 18", "p": 0.45, "age": [16, FREE_HI], "effects": [setv("sx", "g.sx(A)")],
     "outcomes": [
        {"id": "single", "weight": 2.0, "effects": [chron("A", "#pre_love_s{sx}#")]},
        {"id": "wed", "weight": 1.0, "when": "g.single(A)", "effects": [setv("o2", "g.fake_name(g.opp(A.sex), se.ri(0, 999999))"), setv("wed", 1), setv("wage", "ctx.age"),
            chron("A", "#pre_love_wed#")]}]},
    {"id": "bio_widow", "trigger": "bio", "order": 18, "free_age": True, "when": "ctx.get('wed', 0) == 1", "p": 0.55, "age": ["ctx.wage + 3", FREE_HI],
     "effects": [chron("A", "#pre_widow#")]},
    {"id": "bio_kid", "trigger": "bio", "order": 19, "free_age": True, "when": "ctx.get('wed', 0) == 1", "p": 0.5, "age": ["ctx.wage + 1", FREE_HI],
     "effects": [setv("k", "g.kid_name(A, se.ri(0, 99999))"), iff("ctx.old == 0", {"op": "kid", "who": "A", "with": "A", "name": "{k}"}), chron("A", "#pre_kid#")]},
    {"id": "bio_tudi", "trigger": "bio", "order": 20, "free_age": True, "when": "g.lv(A) >= 12", "p": 0.6, "age": ["ctx.join + 20", FREE_HI], "effects": [chron("A", "#pre_tudi#")]},
    {"id": "bio_chou", "trigger": "bio", "order": 21, "free_age": True, "when": "A.goal == '报仇'", "age": [8, FREE_HI],
     "roles": [{"name": "O", "fixed": "g.gtgt(A)"}], "effects": [chron("A", "#pre_chou#", o="O")]},
]

# ================================================================ qinglu_offer：交给她选
def ch(cid, label, outcomes=None, when=None, effects=(), text=None):
    c = {"id": cid, "label": label}
    if when: c["when"] = when
    if effects: c["effects"] = list(effects)
    if outcomes: c["outcomes"] = outcomes
    if text: c["text"] = text
    return c
def out(oid, text, weight=1.0, effects=(), when=None):
    o = {"id": oid, "text": text, "weight": weight, "effects": list(effects)}
    if when: o["when"] = when
    return o
def fav(d, m="", wt=0): 
    o = {"op": "fav", "who": "B", "d": d}
    if m: o["mem"] = m; o["wt"] = wt
    return o
def pc(t, **v):
    o = {"op": "pchron", "text": t}
    if v: o["vars"] = v
    return o
OFFER = [
    {"id": "满月酒", "trigger": "offer", "tier": 0, "tension": -4, "speaker": "B", "in": ["B", "C"], "dead_ok": ["C"],
     "text": ["{B}托人捎来一张红帖：孩子{k}满月，请她去喝一杯。", "山下来了个小童，递上{B}的红帖——{k}满月，摆了几桌酒。"],
     "choices": [
        ch("go", "去喝满月酒", [
            out("warm", "席上{B}抱着{k}给她看，小脸皱成一团。{B}笑：“将来叫你一声姨。”", "1.0 + int(g.pf(B) > 20)", [fav(6, "她来喝了{k}的满月酒", 8), pc("去{B}那里喝了{k}的满月酒。"), {"op": "ling", "n": -1}]),
            out("crowd", "席上都是{B}的同门，她坐在角落，吃完就走。{B}送到门口，道了声谢。", "0.3 + 0.6 * int(g.trt(B, '傲气') or g.trt(B, '薄情'))", [fav(3), pc("去{B}那里喝了{k}的满月酒，人多，没说上几句话。")])]),
        ch("gift", "托人送一把长命锁（2 灵石）", when="g.ls() >= 2", effects=[{"op": "ling", "n": -2}],
           outcomes=[out("ok", "长命锁送去了。{B}回信说，{k}戴着它睡了一下午。", 1.0, [fav(4, "她给{k}送过长命锁", 5), pc("托人给{B}的孩子{k}送了一把长命锁。")])]),
        ch("no", "回封信道喜", outcomes=[out("ok", "她回了一封信，道了声喜。", 1.0, [fav(1)])])]},
    {"id": "吊唁", "trigger": "offer", "tier": 1, "tension": -2, "speaker": "B", "in": ["B", "D"], "dead_ok": ["D"],
     "text": ["{D}走了。{B}在灵前守着，见她来，起身还了一礼。", "{D}的丧事办得简单。{B}一身素白，眼睛是肿的。"],
     "choices": [
        ch("xiang", "上一炷香", [
            out("calm", "香烧到一半，{B}说：“{D}走前，说过你的好。”", "1.0 + int(g.trt(B, '淡泊'))", [fav(5, "她来给{D}上过香", 6), pc("去给{D}上了一炷香。")]),
            out("cry", "她刚插上香，{B}就背过身去，肩膀一直在抖。", "0.5 + int(g.trt(B, '痴情')) + int(g.trt(B, '温柔'))", [fav(6, "她来给{D}上过香", 6), pc("去给{D}上了一炷香，{B}哭了。")])]),
        ch("ling", "守一夜灵", outcomes=[
            out("ok", "她陪{B}守到天亮。灯芯剪了三回，谁也没说话。", 1.0, [fav(8, "她陪我给{D}守过灵", 10), {"op": "wu", "n": 1}, pc("为{D}守了一夜的灵。")])]),
        ch("ask", "问{D}是怎么走的", when="g.trt(B, '记仇') or g.trt(B, '多疑')", outcomes=[
            out("ok", "{B}盯着灵位看了很久：“我会查清楚的。”", 1.0, [fav(2), pc("去吊唁{D}，{B}说要查清楚。")])]),
        ch("no", "远远拜一拜就走", outcomes=[out("ok", "她在门外拜了三拜，没有进去。", 1.0, [pc("听说{D}走了，在门外拜了三拜。")])])]},
    {"id": "观大比", "trigger": "offer", "tier": 0, "tension": -3, "speaker": "B",
     "text": ["{B}托人带话：{sect}大比，{B}得了第{rk}。问她下回要不要去看。", "{sect}大比刚散，{B}顺路来青庐，袖口还沾着灰：“第{rk}。”"],
     "choices": [
        ch("praise", "夸{B}几句", [
            out("shy", "{B}挠了挠头：“运气好。”走时脚步都是轻的。", "1.0 + int(g.trt(B, '温柔') or g.trt(B, '怯懦'))", [fav(5, "她夸过我大比打得好", 5)]),
            out("proud", "{B}扬了扬下巴：“下回第一也是我的。”", "0.5 + int(g.trt(B, '傲气') or g.trt(B, '嗜战'))", [fav(4)])]),
        ch("ask", "请{B}讲讲那几场", outcomes=[out("ok", "{B}比划了半个时辰，她听出几处剑理。", 1.0, [fav(3), {"op": "wu", "n": 1}, pc("听{B}讲了{sect}大比，第{rk}。")])]),
        ch("no", "点点头", outcomes=[out("ok", "她点点头，说了声恭喜。", 1.0, [])])]},
    {"id": "秘境归来", "trigger": "offer", "tier": 1, "tension": -1, "speaker": "B",
     "text": "#o_mj_{res}#",
     "choices": [
        ch("listen", "听{B}讲讲秘境", outcomes=[out("ok", "{B}讲了半夜，哪里有禁制、哪里有妖兽，她都记了下来。", 1.0, [fav(3), {"op": "wu", "n": 2}, pc("听{B}讲了秘境里的事。")])]),
        ch("heal", "替{B}上药（1 灵石）", when="ctx.res == 'hurt' and g.ls() >= 1", effects=[{"op": "ling", "n": -1}], outcomes=[
            out("ok", "她替{B}换了药。{B}疼得直吸气，还是道了谢。", 1.0, [fav(7, "她替我疗过伤", 10), pc("替从秘境出来的{B}疗伤。")])]),
        ch("share", "开口要一份", when="ctx.res == 'treasure'", outcomes=[
            out("give", "{B}想了想，分了她一份：“见者有份。”", "1.0 + int(g.trt(B, '侠义') or g.trt(B, '温柔'))", [{"op": "ling", "n": 3}, fav(-1), pc("{B}从秘境回来，分了她一份。")]),
            out("no", "{B}把玉匣往怀里一揣：“这可是拿命换的。”", "0.4 + 1.5 * int(g.trt(B, '贪财'))", [fav(-3, "她开口要我秘境里的东西", -5)])]),
        ch("no", "道声平安", outcomes=[out("ok", "她说了句平安就好。{B}点点头，走了。", 1.0, [fav(1)])])]},
    {"id": "心魔劫", "trigger": "offer", "tier": 1, "tension": 2, "speaker": "B",
     "text": ["{B}心魔缠身，闭门不出。有人说，{B}夜里一直在喊一个名字。", "{B}来青庐讨一碗水，眼底青黑，说话时总往身后看。"],
     "choices": [
        ch("talk", "陪{B}说说话", outcomes=[out("ok", "她陪{B}从天黑说到天亮。临走，{B}的手不那么抖了。", 1.0,
            [fav(5, "她在我心魔缠身时陪过我", 10), setv("bid", "int(B.id)"), {"op": "flag", "key": "xmh:{bid}"}, pc("陪着心魔缠身的{B}说了一夜的话。")])]),
        ch("guard", "替{B}护法（会受点伤）", when="g.plv() >= 3", outcomes=[out("ok", "心魔发作时，她一掌按住{B}的灵台，自己也被震得咳了血。", 1.0,
            [fav(8, "她替我护法斩心魔", 15), {"op": "pinj", "days": 2}, setv("bid", "int(B.id)"), {"op": "flag", "key": "xmh:{bid}", "add": 2}, pc("替{B}护法，助{B}斩心魔。")])]),
        ch("point", "点破{B}的心结", outcomes=[
            out("hit", "她只说了一句。{B}愣了很久，忽然笑了，笑着笑着哭了。", "1.0 + int(g.trt(B, '淡泊') or g.trt(B, '温柔'))",
                [fav(4), setv("bid", "int(B.id)"), {"op": "flag", "key": "xmh:{bid}", "add": 2}, pc("点破了{B}的心结。")]),
            out("hurt", "{B}脸色一变：“你懂什么。”摔门走了。", "0.5 + int(g.trt(B, '傲气') or g.trt(B, '多疑'))", [fav(-4, "她揭我的伤疤", -6)])]),
        ch("no", "这事帮不上", outcomes=[out("ok", "她没有去。听说{B}的院门一直关着。", 1.0, [])])]},
    {"id": "求拜师", "trigger": "offer", "tier": 1, "tension": -2, "speaker": "B",
     "text": ["{B}在青庐门口跪了一上午，说想拜她为师。", "{B}捧着一包干粮站在桂树下：“我想跟你学。什么都行。”"],
     "choices": [
        ch("yes", "收下{B}", when="g.plv() >= 9 and g.lv(B) + 3 <= g.plv()", outcomes=[out("ok", "{B}磕了三个头，额头上沾了泥，笑得像个孩子。", 1.0, [
            {"op": "tag", "a": "B", "b": "P", "t": "师", "t2": "徒"}, fav(10, "她收我为徒", 20), pc("收{B}为徒。"), chron("B", "拜{pn}为师。")])]),
        ch("teach", "指点几句，不收徒", outcomes=[out("ok", "她教了{B}一段吐纳。{B}记得很认真。", 1.0, [fav(3), {"op": "xp", "who": "B", "frac": 0.2}, pc("没有收{B}为徒，只指点了几句。")])]),
        ch("refer", "写封信引荐去青云宗", when="B.sect == '散修'", outcomes=[out("ok", "{B}揣着信下了山。后来听说，过了青云宗的问心阶。", 1.0, [
            {"op": "sect", "who": "B", "value": "'青云宗'"}, {"op": "home", "who": "B"}, fav(6, "她引荐我入了青云宗", 12), pc("把{B}引荐去了青云宗。"), chron("B", "经{pn}引荐，拜入青云宗。")])]),
        ch("no", "婉拒", outcomes=[out("ok", "{B}低着头走了。走到半山，回头看了一眼。", 1.0, [fav(-2)])])]},
    {"id": "情劫", "trigger": "offer", "tier": 0, "tension": -1, "speaker": "B", "in": ["B", "C"],
     "text": ["{B}来青庐坐了半日，绕了许多弯，才说起{C}。", "{B}问她：“你说，{C}那样的人，会喜欢什么样的人？”"],
     "choices": [
        ch("push", "劝{B}直说", outcomes=[out("ok", "{B}攥着衣角想了很久：“好，我去说。”", 1.0, [fav(3), setv("bid", "int(B.id)"), {"op": "flag", "key": "qj:{bid}"},
            {"op": "schedule", "id": "confess", "in": [2, 6], "cast": {"A": "B", "B": "C"}}, pc("听{B}说了心事，劝{B}直说。")])]),
        ch("drink", "陪{B}喝一壶", outcomes=[out("ok", "一壶喝完，{B}说了许多{C}的事。她只是听。", 1.0, [fav(6, "她听我说过心事", 8), {"op": "ling", "n": -1}, pc("陪{B}喝了半夜的酒。")])]),
        ch("go", "替{B}去说", when="g.met(g.player(), C)", outcomes=[
            out("yes", "{C}听完，低头笑了：“让{B}自己来说。”", "max(0.1, (g.opn(C, B) + 10.0) / 30.0)", [fav(8, "她替我去说过", 12), setv("bid", "int(B.id)"), {"op": "flag", "key": "qj:{bid}", "add": 2},
                {"op": "schedule", "id": "confess", "in": [1, 3], "cast": {"A": "B", "B": "C"}}, pc("替{B}去{C}那里说了一回。")]),
            out("no", "{C}摇头：“替我谢谢{B}。”她回去不知怎么开口。", "max(0.2, (20.0 - g.opn(C, B)) / 25.0)", [fav(2), pc("替{B}去说，{C}婉拒了。")])]),
        ch("let", "劝{B}放下", outcomes=[
            out("ok", "{B}点点头，又摇摇头，最后说：“我试试。”", "1.0 + int(g.trt(B, '淡泊'))", [fav(1)]),
            out("no", "{B}没听进去，起身告辞，茶都没喝完。", "0.5 + int(g.trt(B, '痴情'))", [fav(-1)])])]},
]

CTX_IN = {"满月酒": ["k"], "观大比": ["sect", "rk"], "秘境归来": ["res"]}
for s in OFFER:
    s.setdefault("in", ["B"])
    if s["id"] in CTX_IN:
        s["ctx_in"] = CTX_IN[s["id"]]

def pack(pid, name, storylets, grammar=None, doc=""):
    p = {"id": pid, "name": name, "doc": doc, "host_vars": HOST_VARS, "host_ops": HOST_OPS, "storylets": storylets}
    if grammar is not None: p["grammar"] = grammar
    return p
os.makedirs(R + "/data/packs", exist_ok=True)
# 组合句式：江湖自转、人生阶段里写进履历的句子，前面随机挂一个时令 / 时辰的引子（约一半不挂）
g("t_lead", "", "", "", "", "", "{jie}", "{jie}", "{jie}", "清早，", "晌午，", "暮色里，", "夜里，", "这日，")
def _lead(v, top=True):
    if isinstance(v, dict):
        if v.get("op") == "chron" and isinstance(v.get("text"), str) and v["text"].startswith("#") and not v["text"].startswith("#t_lead#"):
            v["text"] = "#t_lead#" + v["text"]
        for x in v.values():
            _lead(x, False)
    elif isinstance(v, list):
        for x in v:
            _lead(x, False)
for s in CORE + LIFE:
    if s["trigger"] in ("on:meet", "actor", "chain", "daily"):
        _lead(s)

# 争宝 / 斗法：宝物 × 得失 × 收尾，组合出句子（旧句照旧保留）
g("zb_obj", "一株三百年的血参", "一枚刚熟的朱果", "半卷残缺的剑谱", "一块雷击木", "一头受伤的灵狐", "一窝玄蜂蜜", "一眼刚冒头的灵泉", "一具前人坐化的洞府",
  "一柄锈住的古剑", "一块天外陨铁", "一株月下昙", "一枚兽丹", "半张丹方", "一只空储物镯")
g("zb_win", "抢先一步到手", "先下手为强", "仗着身法快了半步", "斗了几个回合，夺下", "使了个障眼法，到手", "出价高了一截，买下")
g("zb_lose", "晚了一步，被对方抢走", "斗不过，只得让出", "被对方用障眼法骗走", "眼看到手，又被截了去", "被对方高价买走", "争了半天，落了空")
g("zb_tail", "", "", "", "，回去后懊恼了好些天", "，临走撂下一句“来日方长”", "，从此记下了这个人", "，心里不痛快了许久")
g("zb_tail_w", "", "", "", "，回去后得意了好几日", "，也没多看对方一眼", "，心里却有些过意不去", "，当晚便闭关去炼化")
G["v_zb_w"] += ["在{p}与{o}争#zb_obj#，#zb_win#。", "在{p}与{o}争#zb_obj#，#zb_win##zb_tail_w#。", "和{o}同时看中#zb_obj#，#zb_win#。"]
G["v_zb_l"] += ["在{p}与{o}争#zb_obj#，#zb_lose#。", "在{p}与{o}争#zb_obj#，#zb_lose##zb_tail#。", "和{o}同时看中#zb_obj#，#zb_lose#。"]
g("df_how", "飞剑", "掌力", "符箓", "阵法", "雷法", "毒雾", "傀儡", "琴音", "火鸦", "冰针")
g("df_w_end", "对方吐血退走", "对方的本命法器裂了", "削断了对方半截衣袖", "逼得对方认输", "把对方打落山崖，没再追", "对方伤得不轻")
g("df_l_end", "伤了经脉", "本命法器裂了一道缝", "被打落山崖，侥幸未死", "连夜逃回了山门", "躺了半个月才下得了床", "丢了半截衣袖和一点颜面")
G["v_df_w"] += ["在{p}与{o}斗法，以#df_how#取胜，#df_w_end#。", "与{o}在{p}交手，#df_how#压过对方一头，#df_w_end#。", "在{p}撞上{o}，二话不说动了手，#df_w_end#。"]
G["v_df_l"] += ["在{p}与{o}斗法，被对方的#df_how#所破，#df_l_end#。", "与{o}在{p}交手，没挡住对方的#df_how#，#df_l_end#。", "在{p}撞上{o}，打了一场，#df_l_end#。"]
G["v_df_draw"] += ["在{p}与{o}斗法，#df_how#对#df_how#，谁也没占到便宜。", "和{o}在{p}打了一夜，天亮时各自退走。"]
G["v_spar"] += ["与{o}在{p}切磋#df_how#，互有胜负。", "在{p}请{o}喂了几招#df_how#，受益不浅。"]

# ================================================================ qinglu_gear：v0.14 法宝与人（炼器、寻宝、赠物、夺宝结仇、捡到遗物、送她东西）
GEAR = [
    {"id": "lianqi", "trigger": "actor", "weight": "0.12 * int(g.lv(A) >= 9)", "when": NB, "actor_cooldown": 120,
     "effects": [{"op": "gen_item", "who": "A", "origin": "{A}闭关炼成。"}, chron("A", "闭门炼器，炼成一件{itg}{it}。"), chance(0.4, rumor("听说{A}炼成了一件{itg}，叫{it}。", kind="宝"))]},
    {"id": "xunqi", "trigger": "actor", "weight": "0.15 * int(g.lv(A) >= 3)", "when": NB + " and g.gear_n(A) < 3", "actor_cooldown": 60,
     "outcomes": [
        {"id": "find", "weight": "0.35 + 0.3 * int(g.trt(A, '好奇'))", "effects": [{"op": "gen_item", "who": "A", "origin": "{A}在{p}一处旧洞府里寻得。"}, chron("A", "在{p}一处旧洞府里寻到一件{it}。")]},
        {"id": "none", "weight": 1.0, "effects": [chron("A", "在{p}寻了一个月的宝，一无所获。")]}]},
    {"id": "zengqi", "trigger": "actor", "weight": 0.3, "when": NB + " and g.partner(A) != null and g.gear_n(A) >= 2", "actor_cooldown": 200,
     "roles": [{"name": "B", "fixed": "g.partner(A)"}],
     "effects": [{"op": "give_item", "a": "A", "b": "B", "h": "{A}赠给道侣{B}。"}, chron("A", "把一件{it}赠给了{B}。"), chron("B", "{A}送来一件{it}，贴身收着。"), rel("B", "A", f=5)]},
    {"id": "duoqi", "trigger": "actor", "weight": "0.2 + 0.5 * int(g.trt(A, '贪财')) + 0.4 * int(g.trt(A, '阴狠'))", "when": NB + " and g.lv(A) >= 3", "actor_cooldown": 60,
     "roles": [{"name": "B", "where": "int(SELF.id) != 1 and g.has_gear(SELF, 'fabao') and not g.bonded(A, SELF) and not g.prot(SELF) and abs(g.lv(SELF) - g.lv(A)) <= 3 and (g.foes(A, SELF) or g.trt(A, '贪财'))"}],
     "outcomes": [
        {"id": "win", "first": True, "when": "g.lv(A) + g.gear_pw(A) + se.roll(0, 4) > g.lv(B) + g.gear_pw(B) + se.roll(0, 4)", "effects": [
            {"op": "take_item", "a": "A", "b": "B", "h": "{A}在{p}从{B}手里夺去。"}, chron("A", "在{p}截住{B}，夺了{B}的{it}。"), chron("B", "在{p}被{A}截住，{it}被夺了去。"),
            rel("B", "A", gg=25), mem("B", "A", "{A}夺了我的{it}", -20, "夺"), rumor("听说{A}为一件{it}截了{B}的道。", ("A", "B"), "宝"),
            iff("g.trt(B, '记仇')", {"op": "goal", "who": "B", "value": "'报仇'", "gt": "A"})]},
        {"id": "lose", "first": True, "effects": [{"op": "inj", "who": "A", "days": 10}, chron("A", "想夺{B}的法宝，反被打伤。"), chron("B", "在{p}打退了来夺宝的{A}。"), rel("B", "A", gg=10)]}]},
    {"id": "shiyi", "trigger": "actor", "weight": "1.5 * int(g.lost_here(A))", "when": NB,
     "effects": [{"op": "pick_lost", "who": "A"}, iff("ctx.it != ''", chron("A", "在{p}捡到一件{it}，上头还刻着{own}的名字。"))]},
    {"id": "song_ta", "trigger": "actor", "weight": "0.15 * int(g.known(A) and g.opn(A, g.player()) > 30)", "when": NB + " and g.gear_n(A) >= 1", "actor_cooldown": 240,
     "roles": [{"name": "B", "fixed": "g.player()"}],
     "effects": [{"op": "give_item", "a": "A", "b": "B", "h": "{A}托人送给{pn}。"}, iff("ctx.it != ''", chron("A", "托人给{pn}送去一件{it}。"), {"op": "pchron", "text": "{A}托人送来一件{it}。"}, mem("A", "B", "送过{pn}一件{it}", 3))]},
]
for s in GEAR:
    _lead(s)
    s["effects"] = [setv("it", "''"), setv("itg", "''"), setv("own", "''")] + s.get("effects", [])   # 物品 op 往 ctx 里写名字；先声明（lint 认得）

PK = [pack("qinglu_core", "青庐·江湖自转（迁移自 v0.11 world_event / solo）", CORE, G, "两人相遇八种事、独处、破境走火坐化飞升、新人、丧事"),
      pack("qinglu_life", "青庐·人生阶段（v0.12 新增）", LIFE, None, "日常、闭关、同门之争、情愫表白、道侣、麟儿、收徒、心魔、大比、秘境"),
      pack("qinglu_bio", "青庐·前尘", BIO, None, "入青庐之前的经历"),
      pack("qinglu_offer", "青庐·交给她选的事", OFFER, None, "满月酒、吊唁、观大比、秘境归来、心魔劫、求拜师、情劫"),
      pack("qinglu_gear", "青庐·法宝与人（v0.14）", GEAR, None, "炼器、寻宝、赠物、夺宝结仇、捡到遗物、送她东西")]
for p in PK:
    p.setdefault("unit", "month")   # v0.13：包里的冷却/连锁/min_t 都按“月”读（回合=月）；换算交给 saga.gd 的 se_ticks
    json.dump(p, open(R + "/data/packs/%s.json" % p["id"], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
ns = sum(len(p["storylets"]) for p in PK)
no = sum(len(s.get("outcomes", [])) for p in PK for s in p["storylets"]) + sum(len(c.get("outcomes", [])) for s in OFFER for c in s["choices"])
print("packs", len(PK), "storylets", ns, "outcomes", no, "symbols", len(G), "alts", sum(len(v) for v in G.values()))
