#!/usr/bin/env python3
"""《青庐远行》设计草案 v3.1 · 首个切片（炼气→筑基）脱离引擎的日结算模拟器。

规则全部取自 design-v3.1.md（v3 版本另存为 sim_v3.py） 第 2.1 / 4 / 8 节；这里只模拟“数值账”，不模拟文本。
用法：python3 sim.py [branch ...]   不带参数则跑全部 5 条分支并输出汇总。
"""
import sys, math, json, os

# ---------- 常量（对应 design-v3 8.2 初始条件） ----------
FIELD_DAYS = 6          # 青芝 6 日一熟
FIELD_YIELD = 2         # 每茬 2 株（v3 下调：基础种不再消耗）
JUQI_COST, JUQI_DAYS, JUQI_XW = 2, 2, 30
JUQI_SOFTCAP = 8        # 本境界第 9 颗起收益减半
QUZHANG_COST, QUZHANG_DAYS = 1, 1
ZHUJI_QZ, ZHUJI_DAYS = 3, 6
BIGUAN_XW = 10          # 闭关基础修为/日
REFINE_CAP = 20         # 每日炼化感悟上限（蒲团 30）
XW_GOAL = 600
YUYUN_CAP = 120         # 圆满余韵上限
RATION_TOPUP, RATION_CAP = 8, 12
VILLAGE_DEADLINE = 30
WU_SOFTCAP = 140        # v3.1：待炼化感悟软上限，超出部分新得感悟减半
GREY_DEADLINE = 23      # v3.1：灰盒期向阳坡期限   # 世事：第 30 日（含）前未到枯田，山村迁走
# 实际时长估算口径（秒）
T_HEAVY, T_LIGHT, T_REVISIT, T_HOME, T_PACK = 50, 12, 4, 90, 45
T_OPEN, T_XINMO, T_ENDING = 120, 240, 60

class Sim:
    def __init__(s, br):
        s.br = br; s.day = 0
        s.fields = [0, 0]                 # 两块阳田的生长进度（日）；基础青芝种不消耗
        s.extra = None                    # 第 5 点灵脉：'field' | 'putuan' | 'shuitian'
        s.qz = 0; s.lian = 0; s.guo = 0; s.lianzi = 0; s.shuitian = None
        s.queue = []                      # [name, days_left]
        s.ready = {'juqi': 0, 'quzhang': 0, 'zhuji': 0}
        s.juqi_brewed = 0; s.juqi_eaten = 0
        s.xw = 0; s.yuyun = 0; s.wu = 0   # 修为 / 余韵 / 待炼化感悟
        s.src = {'biguan': 0, 'ganwu': 0, 'dan': 0}
        s.ration = 8; s.lingshi = 20; s.hunger = 0; s.shouyuan_loss = 0
        s.items = {'避水符': 1}
        s.secs = T_OPEN; s.log = []; s.letter = False
        s.village = 'ok'; s.zhuji_fail_left = 1 if br == '筑基丹失败' else 0
        s.xinmo_fail_left = 1 if br == '心魔失败' else 0
        s.biguan_days = 0; s.idle_days = 0; s.trip_days = 0
        s.harvests = 0; s.qz_used = 0; s.injured = 0
        s.cnt = {'heavy':0,'light':0,'revisit':0,'home':0,'pack':0,'xinmo':0}
    # ---- 日结算：①日初生产 → ②收获入库 → ③（玩家操作，在调用方）→ ④新队列当日生效 ----
    def tick(s, mode):
        s._tick(mode); s.trace(mode)
    def _tick(s, mode):
        s.day += 1
        nf = len(s.fields)
        for i in range(nf):
            s.fields[i] += 1
            if s.fields[i] >= FIELD_DAYS:
                s.fields[i] = 0; s.qz += FIELD_YIELD; s.harvests += 1
        if s.extra == 'shuitian' and s.shuitian is None:
            s.gu_prog = getattr(s, 'gu_prog', 0) + 1
            if s.gu_prog >= FIELD_DAYS: s.gu_prog = 0; s.grain = getattr(s, 'grain', 0) + 2; s.qz += 1; s.harvests_gu = getattr(s,'harvests_gu',0) + 1
        if s.shuitian is not None:
            s.shuitian += 1
            if s.shuitian >= 20: s.lian += 1; s.shuitian = None; s.log.append(f"D{s.day} 水田莲子成熟：寒潭莲+1")
        if s.queue:
            s.queue[0][1] -= 1
            if s.queue[0][1] <= 0:
                name = s.queue.pop(0)[0]
                if name == 'zhuji' and s.zhuji_fail_left:
                    s.zhuji_fail_left -= 1
                    s.log.append(f"D{s.day} 筑基丹成丹失败（青芝损失，主药保留）；得筑基药渣（+20 余韵），次炉 3 日必成")
                    s.lian += 1; s.guo += 1; s.second_batch = True
                    s.yuyun = min(YUYUN_CAP, s.yuyun + 20); s.residue = 20
                else:
                    s.ready[name] += 1
        if mode == 'road':
            s.trip_days += 1
            if s.ration > 0: s.ration -= 1
            else: s.hunger += 1; s.shouyuan_loss += 1
        elif mode == 'biguan':
            s.biguan_days += 1
            s._biguan_pending = True
            cap = 30 if s.extra == 'putuan' else REFINE_CAP
            if s.injured: cap //= 2; s.injured -= 1
            r = min(cap, s.wu); s.wu -= r
            s.gain(BIGUAN_XW, 'biguan'); s.gain(r, 'ganwu')
            if s.xw >= XW_GOAL and s.ready['zhuji'] == 0: s.idle_days += 0  # 计在 wait 判定里
    def add_wu(s, v):
        room = max(0, WU_SOFTCAP - s.wu)
        full = min(v, room); half = (v - full) // 2
        s.wu += full + half; s.wu_lost = getattr(s, 'wu_lost', 0) + (v - full - half)
    def trace(s, mode):
        if not hasattr(s, 'tr'): s.tr = []
        s.tr.append({'day': s.day, 'mode': mode, 'xiuwei': s.xw, 'yuyun': s.yuyun, 'ganwu': s.wu,
                     'qingzhi': s.qz, 'ganliang': s.ration, 'lingshi': s.lingshi,
                     'queue': [[n, d] for n, d in s.queue], 'ready': dict(s.ready),
                     'lian': s.lian, 'guo': s.guo})
    def gain(s, v, k):
        room = XW_GOAL - s.xw
        a = min(v, max(room, 0)); s.xw += a; s.src[k] += a
        s.yuyun = min(YUYUN_CAP, s.yuyun + (v - a))
    # ---- 在家操作（0 日） ----
    def home_ops(s, plan):
        n = s.ready['juqi'] - getattr(s, 'reserve', 0)
        for _ in range(max(0, n)):
            s.juqi_eaten += 1
            s.gain(JUQI_XW if s.juqi_eaten <= JUQI_SOFTCAP else JUQI_XW // 2, 'dan')
        s.ready['juqi'] -= max(0, n)
        # 入队：先满足本趟需要的驱瘴丹，再炼聚气丹到 8 颗，主药齐了排筑基丹
        need_qz = plan.get('quzhang', 0) - s.ready['quzhang'] - sum(1 for q in s.queue if q[0]=='quzhang')
        for _ in range(max(0, need_qz)):
            if s.qz >= QUZHANG_COST: s.qz -= QUZHANG_COST; s.qz_used += 1; s.queue.append(['quzhang', QUZHANG_DAYS])
        zj_q = any(q[0]=='zhuji' for q in s.queue) or s.ready['zhuji']
        if s.lian and s.guo and not zj_q and s.qz >= ZHUJI_QZ and plan.get('zhuji_first'):
            s.qz -= ZHUJI_QZ; s.qz_used += ZHUJI_QZ; s.lian -= 1; s.guo -= 1; s.queue.append(['zhuji', 3 if getattr(s,'second_batch',False) else ZHUJI_DAYS]); zj_q = True
        queued_juqi = sum(1 for q in s.queue if q[0]=='juqi')
        while s.juqi_brewed < JUQI_SOFTCAP + getattr(s, 'juqi_given', 0) and s.qz >= JUQI_COST + (ZHUJI_QZ if (s.lian and s.guo and not zj_q) else 0):
            s.qz -= JUQI_COST; s.qz_used += JUQI_COST; s.juqi_brewed += 1; s.queue.append(['juqi', JUQI_DAYS])
        if s.lian and s.guo and not zj_q and s.qz >= ZHUJI_QZ:
            s.qz -= ZHUJI_QZ; s.qz_used += ZHUJI_QZ; s.lian -= 1; s.guo -= 1; s.queue.append(['zhuji', 3 if getattr(s,'second_batch',False) else ZHUJI_DAYS])
    def come_home(s, bonus=0):
        before = s.ration
        g = getattr(s, 'grain', 0)          # 水田灵谷 → 仓中干粮，先装袋
        take = min(g, RATION_CAP - s.ration); s.ration += take; s.grain = g - take
        if s.ration < RATION_TOPUP: s.ration = RATION_TOPUP
        s.ration = min(RATION_CAP, s.ration + bonus)
        s.log.append(f"D{s.day} 回家：干粮 {before}→{s.ration}")
        s.secs += T_HOME; s.cnt['home'] += 1
    def buy_rations(s, need):
        g = getattr(s, 'grain', 0); take = min(g, max(0, min(RATION_CAP, need) - s.ration)); s.ration += take; s.grain = g - take
        k = max(0, min(RATION_CAP, need) - s.ration)
        s.lingshi -= k; s.ration += k
        if k: s.log.append(f"D{s.day} 在姑母处买干粮 {k} 日份（−{k} 灵石）")
    def snap(s, tag):
        q = ','.join(f"{n}{d}" for n, d in s.queue) or '空'
        s.log.append(f"  [{tag} D{s.day}] 修为 {s.xw}（余韵 {s.yuyun}）待炼化 {s.wu} 青芝 {s.qz} 炉 {q} 待取 {dict((k,v) for k,v in s.ready.items() if v)} 干粮 {s.ration} 灵石 {s.lingshi}")
    def stay(s, days, plan):
        s.home_ops(plan); s.snap('到家整理后')
        for _ in range(days):
            s.home_ops(plan); s.tick('biguan')
        s.home_ops(plan); s.snap(f'闭关 {days} 日后')
    def trip(s, name, nodes):
        s.secs += T_PACK; s.cnt['pack'] += 1; start = s.day
        for nd in nodes:
            days, wu = nd.get('days', 1), nd.get('wu', 0)
            for _ in range(days): s.tick('road')
            s.add_wu(wu)
            s.secs += {'heavy': T_HEAVY, 'light': T_LIGHT, 'revisit': T_REVISIT}[nd['k']]; s.cnt[nd['k']] += 1
            if 'fx' in nd: nd['fx'](s)
        s.log.append(f"D{start}→D{s.day} {name}：{len(nodes)} 节点，耗 {s.day-start} 日，干粮余 {s.ration}，待炼化感悟 {s.wu}")

def run(br):
    s = Sim(br)
    bal = br in ('均衡', '筑基丹失败', '心魔失败')
    # 第一趟 后山（教学）：4 节点；溪边用避水符；葛老三谢礼 净水符+10 灵石
    def gelaosan(s): s.items['净水符'] = 1; s.lingshi += 10
    def xibian(s): s.items.pop('避水符', None)
    s.trip('第一趟·后山', [
        dict(k='heavy', wu=15, fx=xibian), dict(k='light'),
        dict(k='heavy', wu=15, fx=gelaosan), dict(k='heavy', wu=25)])   # 古松残碑（小机缘）
    s.come_home()
    # 回家 1：灵脉第 5 点二选一（v3 新增的经营取舍）
    import os
    s.extra = os.environ.get('EXTRA') or {'均衡': 'field', '偏闭关': 'field', '偏历练': 'field', '筑基丹失败': 'field', '心魔失败': 'field'}[br]
    if s.extra == 'field': s.fields.append(0)
    if s.extra == 'shuitian' and s.lianzi: s.shuitian = 0
    s.log.append(f"D{s.day} 灵脉第 5 点：{ {'field':'第三块阳田','putuan':'静室蒲团','shuitian':'水田'}[s.extra] }")
    stay1 = {'均衡': 2, '偏闭关': 6, '偏历练': 2, '筑基丹失败': 2, '心魔失败': 2}[br]
    LG = os.environ.get('LAOGUI', 'C'); GREY = os.environ.get('GREY') == '1'
    if LG == 'B':                       # v3.1：风闻提示“揣上一颗丹再去”；批量服丹自动留 1 颗
        s.reserve = 1
        while True:
            s.stay(stay1, {}); stay1 = 1
            if s.ready['juqi'] >= 1: break
        s.log.append(f"D{s.day} 留 1 颗聚气丹给老龟（批量服丹不会吃掉它）")
    else:
        s.stay(stay1, {})
    # 第二趟 寒潭：8 节点，老龟 C（坐三天：本节点共 3 日，感悟 40，换来寒潭莲 + 暗渠路书）
    def laogui(s):
        if LG == 'C': s.lian += 1; s.items['暗渠路书'] = 1
        elif LG == 'B' and s.ready['juqi'] >= 1:
            s.ready['juqi'] -= 1; s.reserve = 0; s.lian += 1; s.lianzi += 1; s.juqi_given = 1
            s.log.append(f"D{s.day} 老龟 B：以聚气丹换得寒潭莲 + 寒潭莲子")
        else: s.log.append(f"D{s.day} 老龟 D：转身走，本趟无寒潭莲")
    def xicai(s):                      # 寒潭野地细采（+1 日）得寒潭莲子
        if LG == 'D':
            s.tick('road'); s.lianzi += 1; s.log.append(f"D{s.day} 寒潭野地细采 +1 日：寒潭莲子 ×1")
    def jiashu(s): s.letter = True; s.add_wu(5)
    s.buy_rations(10)
    s.trip('第二趟·寒潭', [
        dict(k='heavy', wu=15), dict(k='light', fx=xicai), dict(k='heavy', wu=15),
        dict(k='heavy', days=3 if LG == 'C' else 1, wu=40 if LG == 'C' else 0, fx=laogui), dict(k='heavy', wu=15),
        dict(k='light', fx=jiashu), dict(k='light') if GREY else dict(k='heavy', wu=15), dict(k='light')])
    s.come_home(bonus=3 if s.letter else 0)
    # 回家 2：世事打断“瘴雾下河”——第 30 日前不到枯田，山村迁走；下游河段要驱瘴丹或绕 2 日
    if s.extra == 'shuitian' and s.lianzi and s.shuitian is None:
        s.lianzi -= 1; s.shuitian = 0; s.log.append(f"D{s.day} 水田种下寒潭莲子（20 日一熟）")
    stay2 = {'均衡': 3, '偏闭关': 10, '偏历练': 1, '筑基丹失败': 3, '心魔失败': 3}[br]
    if GREY:
        # 灰盒期：世事卡改为“向阳坡的赤阳果要被采光了”，期限 D23；第三趟是 2 日短途
        s.log.append(f"D{s.day} 世事（灰盒）：向阳坡赤阳果 D{GREY_DEADLINE} 前去才有")
        s.stay(stay2, {})
        def xiangyang(s):
            if s.day <= GREY_DEADLINE: s.guo += 1; s.log.append(f"D{s.day} 向阳坡：对峙后得赤阳果")
            else: s.log.append(f"D{s.day} 向阳坡已被采光（超过 D{GREY_DEADLINE}）")
        s.buy_rations(2)
        s.trip('第三趟·向阳坡（灰盒）', [dict(k='revisit'), dict(k='heavy', wu=15, fx=xiangyang)])
        s.come_home()
        if not s.guo:
            s.lingshi -= 20; s.guo += 1; s.log.append(f"D{s.day} 葛老三托人送来赤阳果（−20 灵石）")
    else:
        s.log.append(f"D{s.day} 世事：瘴雾下河（山村 D{VILLAGE_DEADLINE} 迁走；河段需驱瘴丹）")
        s.stay(stay2, {'quzhang': 1})
        run_trip3(s)
    return finish(s, br)

def run_trip3(s):
    # 第三趟 渡口·山村（暗渠可从寒潭直下山村；均衡走渡口：夜渡 B → 河段 → 枯田 A）
    def yedu(s): s.lingshi -= 10; s.items['残符·定风'] = 1
    def heduan(s):
        if s.ready['quzhang']: s.ready['quzhang'] -= 1
        else:
            for _ in range(2): s.tick('road')
            s.log.append(f"D{s.day} 河段无驱瘴丹，绕行 +2 日")
    def kutian(s):
        if s.day <= VILLAGE_DEADLINE:
            s.items.pop('净水符', None); s.guo += 1; s.village = '缓过来'
            s.log.append(f"D{s.day} 枯田 A：净水符给村子，得赤阳果；水路关闭，改走山道")
        else:
            s.village = '迁走'
            s.log.append(f"D{s.day} 山村已迁走（超过 D{VILLAGE_DEADLINE}），改去向阳坡")
            for _ in range(2): s.tick('road')
            s.guo += 1; s.wu += 0
    s.buy_rations(11)
    s.trip('第三趟·渡口·山村', [
        dict(k='heavy', wu=15, fx=yedu), dict(k='heavy', wu=15, fx=heduan),
        dict(k='light'), dict(k='heavy', wu=15), dict(k='heavy', wu=15, fx=kutian),
        dict(k='heavy', days=2, wu=15),          # 山道（净水符已给出，水路关闭）：对峙
        dict(k='light'), dict(k='revisit'), dict(k='revisit')])
    s.come_home()
    if s.lian == 0 and s.shuitian is None and not any(q[0]=='zhuji' for q in s.queue) and not s.ready['zhuji']:
        # 没拿到寒潭莲、也没有水田莲子：再走一趟寒潭，老龟只剩“以丹换莲”（B）
        s.stay(1, {})
        def laogui_b(s):
            s.qz -= JUQI_COST; s.qz_used += JUQI_COST; s.juqi_given = getattr(s,'juqi_given',0) + 1   # 现炼一颗聚气丹交给老龟（按 2 青芝计）
            s.lian += 1; s.log.append(f"D{s.day} 寒潭重访：以聚气丹换得寒潭莲")
        s.trip('第四趟·寒潭重访', [dict(k='revisit'), dict(k='revisit'), dict(k='revisit'), dict(k='heavy', wu=15, fx=laogui_b), dict(k='revisit'), dict(k='revisit')])
        s.come_home()

def finish(s, br):
    # 回家 3：炼完、闭关直到修为满 + 筑基丹出炉
    s.home_ops({}); s.snap('到家整理后')
    guard = 0
    while not (s.xw >= XW_GOAL and s.ready['zhuji']):
        if s.xw >= XW_GOAL and s.wu == 0 and s.queue: s.idle_days += 1
        s.home_ops({}); s.tick('biguan'); guard += 1
        if guard > 200: raise SystemExit(f"{br}: 卡死")
    s.home_ops({}); s.snap('冲关前')
    # 冲关：耗 1 日；心魔失败 → 心境不稳，闭关 3 日（炼化减半）后再冲，筑基丹保留
    s.tick('home'); s.secs += T_XINMO; s.cnt['xinmo'] += 1
    if s.xinmo_fail_left:
        s.log.append(f"D{s.day} 心魔劫未过：筑基丹保留，闭关 3 日后再冲关")
        s.injured = 3
        for _ in range(3): s.tick('biguan')
        s.tick('home'); s.secs += T_XINMO // 2; s.cnt['xinmo'] += 0.5
    s.secs += T_ENDING
    return s

def mins(s, h, l, r, home, pack):
    c = s.cnt
    t = T_OPEN + c['heavy']*h + c['light']*l + c['revisit']*r + c['home']*home + c['pack']*pack + c['xinmo']*T_XINMO + T_ENDING
    return round(t/60, 1)

def report(s):
    tot = sum(s.src.values())
    pct = {k: round(100*v/tot) for k, v in s.src.items()} if tot else {}
    return {
        '分支': s.br, '筑基日': s.day, '修为来源': s.src, '占比%': pct,
        '闭关(基础+炼化)占比%': round(100*(s.src['biguan']+s.src['ganwu'])/tot) if tot else 0,
        '余韵': s.yuyun, '剩余待炼化感悟': s.wu,
        '历练日': s.trip_days, '闭关日': s.biguan_days, '修为满后仍等丹的闭关日': s.idle_days,
        '青芝收获茬数': s.harvests, '青芝产出': s.harvests*FIELD_YIELD + getattr(s,'harvests_gu',0), '青芝消耗': s.qz_used, '青芝剩余': s.qz,
        '聚气丹 炼/服': (s.juqi_brewed, s.juqi_eaten), '干粮剩余': s.ration, '饥乏日': s.hunger,
        '感悟折损(软上限)': getattr(s,'wu_lost',0), '灵石': s.lingshi, '仓中灵谷干粮': getattr(s,'grain',0), '山村': s.village, '实际时长(分钟)': round(s.secs/60, 1),
        '节点计数': s.cnt,
        '快读(重35/轻8/重访3秒)': mins(s, 35, 8, 3, 60, 30),
        '慢读(重75/轻18/重访6秒)': mins(s, 75, 18, 6, 120, 60),
    }

if __name__ == '__main__':
    brs = sys.argv[1:] or ['均衡', '偏闭关', '偏历练', '筑基丹失败', '心魔失败']
    out = []
    for b in brs:
        s = run(b); r = report(s); out.append(r)
        print(f"===== {b} ====="); [print("  " + l) for l in s.log]
        print(json.dumps(r, ensure_ascii=False, indent=1))
    json.dump(out, open(__file__.rsplit('/', 1)[0] + '/results.json', 'w'), ensure_ascii=False, indent=1)
    if os.environ.get('TRACE'): json.dump(s.tr, open(os.environ['TRACE'], 'w'), ensure_ascii=False, indent=0)
