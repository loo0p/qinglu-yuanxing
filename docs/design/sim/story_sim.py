#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《青庐远行》v4 叙事原型：程序生成角色 + 世界自转(WorldTick) + 说书人(Storyteller) + 事件模板 + 生平(Chronicle)。
纯标准库。用法：python3 story_sim.py [--seed N] [--days 100] [--npcs 20] [--runs 8] [--quiet]
目的：证明故事能自己长出来、且不重复。不是游戏代码，数据结构与 design-v4.md 一一对应，便于移植到 GDScript。"""
import random, argparse, collections, json, math

# ---------------------------------------------------------------- 词库
SURN = list("苏林沈温叶顾陆白谢秦楚萧柳江宋云姜陈裴韩唐许程孟方傅")+["慕容","上官","司徒","欧阳"]
F_GIV = list("青禾晚照知微小满清霜若雪凝烟婉宁素心月华听雨念初芷兰灵犀暮雪锦瑟")
M_GIV = list("长风子衡怀瑾承远墨白景行云起少游临川慎之明远寒山逸尘砚秋")
SECTS = {"青云宗":"正","玄霜谷":"正","落霞宫":"正","万剑门":"正","药王谷":"正","散修":"中","血煞门":"魔","阴骨教":"魔"}
PLACES = ["青庐","后山","寒潭","坊市","青云宗","玄霜谷","落霞宫","万剑门","药王谷","血煞门","古战场","云梦泽"]
SECT_HOME = {"青云宗":"青云宗","玄霜谷":"玄霜谷","落霞宫":"落霞宫","万剑门":"万剑门","药王谷":"药王谷","散修":"坊市","血煞门":"血煞门","阴骨教":"古战场"}
REALMS = ["炼气"]*9+["筑基"]*3+["金丹"]*3+["元婴"]*3+["化神"]
def realm_name(lv):
    if lv<9: return "炼气%s层"%"一二三四五六七八九"[lv]
    if lv>=18: return "化神"
    return REALMS[lv]+["初期","中期","后期"][(lv-9)%3]
LIFESPAN = lambda lv: 100 if lv<9 else 200 if lv<12 else 500 if lv<15 else 1000
# 性格：名字 -> (选项倾向, 喜欢的性格, 厌恶的性格)
TRAITS = {
 "温柔":({"kind":2,"brave":0},["温柔","侠义","痴情"],["嗜战","阴狠"]),
 "傲气":({"proud":2},["傲气","嗜战"],["怯懦","圆滑"]),
 "多疑":({"careful":2},["多疑","淡泊"],["圆滑","贪财"]),
 "贪财":({"greedy":2},["贪财","圆滑"],["淡泊","侠义"]),
 "侠义":({"brave":2,"kind":1},["侠义","温柔"],["阴狠","贪财"]),
 "痴情":({"kind":1,"love":2},["痴情","温柔"],["薄情"]),
 "记仇":({"proud":1,"revenge":2},["记仇"],["圆滑"]),
 "淡泊":({"careful":1},["淡泊","温柔"],["贪财","嗜战"]),
 "嗜战":({"brave":2,"proud":1},["嗜战","傲气"],["怯懦","淡泊"]),
 "好奇":({"curious":2},["好奇"],["多疑"]),
 "怯懦":({"careful":2},["温柔"],["嗜战","傲气"]),
 "圆滑":({"greedy":1},["圆滑"],["傲气","记仇"]),
 "阴狠":({"greedy":1,"revenge":1},["阴狠"],["侠义","温柔"]),
 "薄情":({"proud":1},["淡泊"],["痴情"]),
}
LIKES = ["桂花糕","古琴","好剑","丹方","灵茶","旧书","梅花","烈酒","星图","木簪"]
CLASH = [set(x) for x in (("温柔","阴狠"),("痴情","薄情"),("怯懦","嗜战"),("淡泊","贪财"),("侠义","阴狠"),("温柔","嗜战"),("怯懦","傲气"))]
GOALS = ["求长生","寻道侣","振兴师门","寻亲","炼一炉九转丹","收个好徒弟","报仇","游遍云梦泽"]


VAR={
 "论道":["在{p}与{o}论道半夜。","与{o}在{p}煮茶谈剑，相见恨晚。","在{p}得{o}指点，解了一处功法上的疑难。","与{o}在{p}对弈一局，输了半子。","和{o}在{p}比了一回剑，点到为止。","在{p}替{o}挡了一场雨，两人聊到天明。"],
 "争宝_w":["在{p}与{o}争一株灵草，得手。","从{o}手里抢下一枚兽丹。","在{p}比{o}先一步拓下残碑。","在{p}的拍卖会上压了{o}一头，拍走一卷残图。","赶在{o}之前收服了{p}的一只灵狐。"],
 "争宝_l":["在{p}看中的灵草被{o}夺去。","到手的兽丹被{o}截了。","在{p}晚了{o}一步，残碑被拓走了。","在{p}的拍卖会上叫价输给了{o}。","眼看要收服的灵狐，被{o}抢了先。"],
 "斗法_w":["在{p}与{o}斗法，胜。","一剑挑落了{o}的发冠。","在{p}把{o}逼退三十里。","在{p}以一道符破了{o}的护体灵光。","三十招后，{o}的剑断在{p}。"],
 "斗法_l":["在{p}败于{o}手下，重伤。","被{o}一掌震伤心脉。","在{p}输给{o}，养了半月伤。","在{p}被{o}的飞剑穿了肩。","与{o}斗法落败，本命法器裂了一道缝。"],
}
def V_(w,k,**kw): return w.rng.choice(VAR[k]).format(**kw)

class Rel:
    __slots__=("favor","grudge","tags","met")
    def __init__(s): s.favor=0; s.grudge=0; s.tags=set(); s.met=0

class Char:
    _n=0
    def __init__(s, rng, sex=None, sect=None, lv=None, player=False):
        Char._n+=1; s.id=Char._n; s.player=player
        s.sex = sex or rng.choice("女女男")   # 女修小说：女修略多
        s.name = rng.choice(SURN)+"".join(rng.sample(F_GIV if s.sex=="女" else M_GIV, rng.choice([1,2])))
        s.sect = sect or rng.choice(list(SECTS))
        s.lv = lv if lv is not None else min(17, int(rng.expovariate(1/4.5)))
        s.xp = 0; s.age = rng.randint(16, 30) + s.lv*6
        while True:
            s.traits = rng.sample(list(TRAITS), 2)
            if set(s.traits) not in CLASH: break
        s.likes = rng.sample(LIKES, 2); s.dislikes = rng.sample([x for x in LIKES if x not in s.likes], 1)
        s.goal = rng.choice(GOALS); s.goal_target=None
        s.place = SECT_HOME[s.sect] if rng.random()<.6 else rng.choice(PLACES[1:])
        s.alive=True; s.ascended=False; s.injured=0; s.rel={}; s.mem=[]; s.log=[]
        s.seed = rng.randrange(1<<30)  # 立绘种子
    def R(s, o):
        if o.id not in s.rel: s.rel[o.id]=Rel()
        return s.rel[o.id]
    @property
    def realm(s): return realm_name(s.lv)
    @property
    def side(s): return SECTS[s.sect]
    def tag(s, t): return t in s.traits
    def partner(s, w):
        for i,r in s.rel.items():
            if "道侣" in r.tags and w.C[i].alive: return w.C[i]
    def opinion(s, o):
        """好感 + 性格相合 + 记忆权重 - 仇怨"""
        r=s.R(o); v=r.favor-r.grudge*1.2
        for t in o.traits:
            for mine in s.traits:
                if t in TRAITS[mine][1]: v+=6
                if t in TRAITS[mine][2]: v-=8
        v+=sum(m[3] for m in s.mem if m[1]==o.id)
        if s.side!=o.side and "中" not in (s.side,o.side): v-=10
        return v
    def remember(s, w, o, text, weight):
        s.mem.append([w.day, o.id if o else 0, text, weight])
        if len(s.mem)>24: s.mem.sort(key=lambda m: abs(m[3]) - (w.day-m[0])*0.05); s.mem.pop(0)
    def __repr__(s): return s.name

# ---------------------------------------------------------------- 世界
class World:
    def __init__(s, seed, n_npc):
        s.rng=random.Random(seed); s.day=0; s.C={}; s.news=[]; s.queue=[]; s.fired=collections.Counter()
        s.last_fired={}; s.pair_cd={}; s.hist=collections.Counter(); s.tension=10; s.since_major=0; s.player_events=[]; s.flags=collections.Counter()
        s.P=Char(s.rng, sex="女", sect="散修", lv=0, player=True); s.P.place="青庐"; s.P.goal="求长生"
        s.add(s.P)
        for _ in range(n_npc): s.add(Char(s.rng))
        # 世界初始关系：同门相熟、少量旧怨与道侣、师徒
        npcs=s.npcs()
        for a in npcs:
            for b in npcs:
                if a is b: continue
                if a.sect==b.sect and a.sect!="散修": a.R(b).favor+=s.rng.randint(5,25); a.R(b).met=1
            if a.goal=="报仇":
                t=s.rng.choice([x for x in npcs if x is not a]); a.goal_target=t.id; a.R(t).grudge=60
                a.remember(s,t,"%s害过我的亲人"%t.name,-30)
        s.chron(s.P,"自姑母家出来，住进后山脚下的青庐。")
    def add(s,c): s.C[c.id]=c
    def npcs(s, alive=True): return [c for c in s.C.values() if not c.player and (c.alive or not alive)]
    def at(s, place, alive=True): return [c for c in s.npcs() if c.place==place]
    def chron(s, c, text): c.log.append((s.day, text))
    def both(s, a, b, ta, tb=None): s.chron(a, ta); s.chron(b, tb or ta)
    def rumor(s, text, who=()): s.news.append((s.day, text, tuple(c.id for c in who)))
    def schedule(s, delay, tid, roles, **ctx): s.queue.append((s.day+delay, tid, roles, ctx))
    def known(s, c): return c.id in s.P.rel and s.P.rel[c.id].met

    # ---------- WorldTick：所有人每天都过日子，玩家看不见也照常
    def tick(s):
        s.day+=1; rng=s.rng
        for c in list(s.npcs()):
            c.age += 1/360
            if c.injured: c.injured-=1
            # 修炼
            gain = rng.uniform(.6,1.4) * (0.4 if c.injured else 1)
            c.xp += gain
            need = 8*(1.35**c.lv)
            if c.xp>=need:
                c.xp=0
                big = c.lv in (8,11,14,17)
                if big and rng.random()<0.45:  # 大境界失败
                    c.injured=20; s.chron(c,"冲击%s失败，经脉受损。"%REALMS[c.lv+1])
                    if rng.random()<.15: s.die(c,"冲关走火入魔，身死道消")
                    continue
                c.lv+=1
                if big: s.chron(c,"破境，入%s。"%c.realm); s.rumor("%s（%s）突破至%s。"%(c.name,c.sect,c.realm),[c])
            if c.age>LIFESPAN(c.lv) and rng.random()<.02: s.die(c,"寿元耗尽，坐化"); continue
            if c.lv>=18 and rng.random()<.01: s.ascend(c); continue
            # 游历
            if rng.random()<.06:
                c.place = SECT_HOME[c.sect] if rng.random()<.4 else rng.choice(PLACES[1:])
        # 同地相遇 -> 世界事件
        byp=collections.defaultdict(list)
        for c in s.npcs(): byp[c.place].append(c)
        for place,cs in byp.items():
            if len(cs)>=2 and rng.random()<min(.5,.12*len(cs)):
                a,b=rng.sample(cs,2); key=(min(a.id,b.id),max(a.id,b.id))
                if s.day-s.pair_cd.get(key,-99)>=20:
                    s.pair_cd[key]=s.day; s.world_event(a,b,place)
        for c in s.npcs():
            if rng.random()<.012: s.solo(c)
        if rng.random()<.04 and len(s.npcs())<30: s.newcomer()

    def solo(s, c):
        """NPC 个人目标推进：不需要别人在场，生平也有自己的线。"""
        rng=s.rng; g=c.goal; s.flags["solo:"+g]+=1
        T_={"求长生":["在%s闭了一回死关。","寻到半部长生诀，读到天亮。","在%s的古洞里找到一具坐化的骸骨，拜了三拜。","数了数自己的寿元，又多坐了一个周天。"],
            "寻道侣":["在%s的灯会上站了一夜，没等到人。","托媒的信又退了回来。","在%s替人写了一封情书，自己的那封没寄。","给不知是谁的人刻了一支木簪。"],
            "振兴师门":["替%s跑了三处坊市，换回一车灵材。","把师门塌了的偏殿重新立了起来。","替%s收了两个新弟子。","为%s的护山大阵补了一角。"],
            "寻亲":["在%s打听到一点亲人的消息，又断了。","梦见幼时的门槛。","在%s的旧户籍册里找到一个相近的名字。","托人往北边送了一封不知寄给谁的信。"],
            "炼一炉九转丹":["丹炉又炸了，眉毛燎去半边。","炼出一炉三转丹，离九转还远。","在%s寻到一味主药。","把丹方抄了第三遍，改了两处火候。"],
            "收个好徒弟":["在%s看了十几个孩子的根骨，摇头。","捡了个孩子，养了三天又送回去了。","在%s听说有个放牛娃能引气入体，赶去时人已被收走。","把自己的入门剑擦了又擦。"],
            "报仇":["磨了一夜剑。","在%s打听仇人的下落。","把仇人的名字写在符纸上，烧了。","在%s练了一整日的杀招。"],
            "游遍云梦泽":["到了%s，记下一页游记。","在泽边看了一夜的萤火。","在%s的渡口等了三天的船。","游记写满了第二本。"]}
        t=rng.choice(T_[g]); s.chron(c, t%(c.place if g!="振兴师门" else c.sect) if "%s" in t else t)
        if g=="炼一炉九转丹" and rng.random()<.08: s.chron(c,"九转丹成。"); c.lv=min(18,c.lv+2); s.rumor("%s炼成了九转丹。"%c.name,[c]); c.goal="求长生"
        if g=="寻道侣" and c.partner(s): c.goal="求长生"
    def die(s, c, how):
        c.alive=False; s.chron(c, how+"。")
        s.rumor("%s%s。"%(c.name,how),[c])
        for o in s.C.values():
            if o.alive and c.id in o.rel:
                r=o.rel[c.id]
                if "道侣" in r.tags or r.favor>40:
                    o.remember(s,c,"%s死了"%c.name,-10); s.chron(o,"听闻%s%s，三日不语。"%(c.name,how))
                    if not o.player and "记仇" in o.traits or "痴情" in o.traits: o.goal="报仇"
    def ascend(s,c):
        c.alive=False; c.ascended=True; s.chron(c,"渡劫成功，白日飞升。"); s.rumor("天现异象：%s渡劫飞升。"%c.name,[c])
    def newcomer(s):
        c=Char(s.rng, lv=s.rng.randint(0,3)); s.add(c); s.chron(c,"初入仙途，拜入%s。"%c.sect if c.sect!="散修" else "初入仙途，做了散修。")

    def world_event(s, a, b, place):
        rng=s.rng; oa=a.opinion(b); ob=b.opinion(a); ra,rb=a.R(b),b.R(a); ra.met=rb.met=1
        pool=[]
        pool.append(("论道", 3+max(0,(oa+ob)/20)))
        pool.append(("争宝", 1.5+(a.tag("贪财")+b.tag("贪财"))*2+(place in("古战场","云梦泽"))*2))
        if oa<-20 or ob<-20 or a.side!=b.side and "中" not in(a.side,b.side): pool.append(("斗法", 2+max(0,-(oa+ob)/15)))
        if (a.sex!=b.sex) and oa>28 and ob>28 and not a.partner(s) and not b.partner(s): pool.append(("结为道侣", 6))
        if abs(a.lv-b.lv)>=5 and oa>25 and ob>25 and not any("师" in t for t in ra.tags): pool.append(("收徒", 4))
        if a.sex==b.sex and oa>40 and ob>40 and "结义" not in ra.tags: pool.append(("结义", 2))
        if a.partner(s) is b and (a.tag("薄情") or a.tag("阴狠")) and rng.random()<.3: pool.append(("背弃", 3))
        if a.goal=="报仇" and a.goal_target==b.id: pool.append(("复仇", 12))
        if a.sex!=b.sex and a.sect==b.sect and ra.favor>20 and rb.favor>20 and not a.partner(s) and not b.partner(s) and "寻道侣" in (a.goal,b.goal): pool.append(("结为道侣", 5))
        k=rng.choices([p[0] for p in pool],[p[1] for p in pool])[0]; s.flags["w:"+k]+=1
        if k=="论道":
            d=rng.randint(6,15); ra.favor+=d; rb.favor+=d
            s.chron(a,V_(s,"论道",p=place,o=b.name)); s.chron(b,V_(s,"论道",p=place,o=a.name))
        elif k=="争宝":
            win,lose=(a,b) if a.lv+rng.random()*4>b.lv+rng.random()*4 else (b,a)
            win.R(lose).grudge+=5; lose.R(win).grudge+=20; lose.remember(s,win,"%s抢了我在%s看中的灵物"%(win.name,place),-15)
            s.chron(win,V_(s,"争宝_w",p=place,o=lose.name)); s.chron(lose,V_(s,"争宝_l",p=place,o=win.name))
        elif k=="斗法":
            win,lose=(a,b) if a.lv+rng.random()*5>b.lv+rng.random()*5 else (b,a)
            lose.R(win).grudge+=30; lose.injured=15
            s.chron(win,V_(s,"斗法_w",p=place,o=lose.name)); s.chron(lose,V_(s,"斗法_l",p=place,o=win.name)); lose.place=SECT_HOME[lose.sect]
            if win.lv-lose.lv>=3 and (win.tag("阴狠") or win.side=="魔") and rng.random()<.5:
                s.die(lose,"死于%s之手"%win.name)
            else: lose.remember(s,win,"%s伤我"%win.name,-25)
        elif k=="结为道侣":
            ra.tags.add("道侣"); rb.tags.add("道侣"); s.both(a,b,"与%s结为道侣。"%b.name,"与%s结为道侣。"%a.name)
            s.rumor("%s与%s结为道侣，在%s摆了三桌素席。"%(a.name,b.name,place),[a,b])
        elif k=="收徒":
            m,d=(a,b) if a.lv>b.lv else (b,a); m.R(d).tags.add("徒"); d.R(m).tags.add("师")
            s.chron(m,"收%s为徒。"%d.name); s.chron(d,"拜%s为师。"%m.name)
            if d.sect!=m.sect and m.sect!="散修": d.sect=m.sect
        elif k=="结义":
            ra.tags.add("结义"); rb.tags.add("结义"); s.both(a,b,"与%s义结金兰。"%b.name,"与%s义结金兰。"%a.name)
        elif k=="背弃":
            ra.tags.discard("道侣"); rb.tags.discard("道侣"); rb.grudge+=60; b.remember(s,a,"%s负我"%a.name,-40)
            s.chron(a,"弃了道侣%s，独自远走。"%b.name); s.chron(b,"被%s所负。"%a.name)
            s.rumor("听说%s负了%s。"%(a.name,b.name),[a,b])
            if b.tag("记仇") or b.tag("痴情"): b.goal="报仇"; b.goal_target=a.id
        elif k=="复仇":
            if a.lv+rng.random()*4>b.lv+rng.random()*3:
                s.chron(a,"在%s寻到%s，了结旧仇。"%(place,b.name)); s.die(b,"被%s寻仇所杀"%a.name); a.goal=rng.choice(GOALS[:6])
            else:
                a.injured=25; s.chron(a,"寻%s报仇不成，负伤遁走。"%b.name); b.R(a).grudge+=30

    # ---------- 说书人：每日决定要不要给玩家一件事、什么强度
    def storyteller(s):
        rng=s.rng; s.since_major+=1
        # 先处理到期的连锁事件（后果持续）
        due=[q for q in s.queue if q[0]<=s.day]
        for q in due:
            s.queue.remove(q); roles={k:s.C[v] for k,v in q[2].items()}
            if all(c.alive for k,c in roles.items() if k!="P"):
                T[q[1]].run(s, roles, q[3]); s.log_fire(q[1]); return
        p_event = 0.35 + s.since_major*0.012
        if rng.random()>p_event: s.tension=max(0,s.tension-2); return
        # 强度：张力低→大事概率高；刚出过大事→给喘息
        want = 2 if (s.since_major>14 and rng.random()<.5) else (0 if s.tension>60 else rng.choice([0,1,1]))
        cands=[]
        for t in T.values():
            if t.chain_only or abs(t.tier-want)>1 or s.fired[t.id]>=t.max_n or s.day<t.min_day or (t.id in s.last_fired and s.day-s.last_fired[t.id]<t.cooldown): continue
            roles=t.bind(s)
            if roles is None: continue
            w=t.weight(s,roles)*(1.0 if t.tier==want else .25)
            last=s.last_fired.get(t.id)
            if last is not None: w*=1-math.exp(-(s.day-last)/12)  # 新鲜度
            if w>0: cands.append((t,roles,w))
        if not cands: return
        t,roles,_=rng.choices(cands,[c[2] for c in cands])[0]
        t.run(s,roles,{}); s.log_fire(t.id)
    def log_fire(s,tid):
        t=T[tid]; s.fired[tid]+=1; s.last_fired[tid]=s.day; s.player_events.append(tid)
        s.tension=min(100,max(0,s.tension+t.tension))
        if t.tier>=2: s.since_major=0

    # ---------- 玩家决策（模拟玩家：按性格倾向选）
    def choose(s, opts):
        bias=collections.Counter()
        for t in s.P.traits: bias.update(TRAITS[t][0])
        tot=sum(s.hist.values()) or 1
        # 人设一致：性格倾向 ×1.5 + 过往选择习惯（同类标签选得越多越倾向）
        ws=[1+1.5*sum(bias[x] for x in o[1])+4*sum(s.hist[x] for x in o[1])/tot for o in opts]
        ch=s.rng.choices(opts,ws)[0]; s.hist.update(ch[1]); return ch

# ---------------------------------------------------------------- 事件模板
T={}
_RECENT=collections.defaultdict(collections.deque)
def pv(w, key, opts):
    """从变体里挑一句，避开该 key 最近用过的一半变体（GDTracery 接入后由语法表取代）"""
    dq=_RECENT[(id(w),key)]; cand=[i for i in range(len(opts)) if i not in dq] or list(range(len(opts)))
    i=w.rng.choice(cand); dq.append(i)
    while len(dq)>len(opts)//2: dq.popleft()
    return opts[i]
class Tpl:
    def __init__(s, id, tier, tension, bind, run, weight=lambda w,r:1, chain_only=False, doc="", max_n=99, min_day=0, cooldown=0):
        s.max_n,s.min_day,s.cooldown=max_n,min_day,cooldown; s.id,s.tier,s.tension,s.bind,s.run,s.weight,s.chain_only,s.doc=id,tier,tension,bind,run,weight,chain_only,doc
        T[id]=s
def pick(w, f, key=None):
    cs=[c for c in w.npcs() if f(c)]
    if not cs: return None
    return w.rng.choices(cs,[key(c) for c in cs])[0] if key else w.rng.choice(cs)
def meet(w,c,text):
    r=w.P.R(c); first=not r.met; r.met=1; c.R(w.P).met=1
    if first: w.chron(w.P,"初识%s——%s，%s，%s、%s。"%(c.name,c.sect if c.sect=="散修" else c.sect+"修士",c.realm,*c.traits))
    return first
def fav(w,c,d,mem=None,wt=0):
    c.R(w.P).favor+=d; w.P.R(c).favor+=d//2
    if mem: c.remember(w,w.P,mem,wt)
def P(w,text): w.chron(w.P,text)
def opt(label,tags,fn): return (label,tags,fn)

# 1 偶遇：在当前地点遇见陌生人（玩家每局遇见谁由此决定）
def _run(w,r,c):
    n=r["B"]; meet(w,n,"")
    lines={"温柔":"她把伞往你这边偏了偏","傲气":"对方只抬了抬眼","好奇":"对方先问你从哪儿来","贪财":"对方的目光在你的储物袋上停了一停"}
    lines.update({"多疑":"对方的手一直没离开剑柄","淡泊":"对方让到路边，等你先过","嗜战":"对方上下打量你，像在掂量能接几招","侠义":"对方提醒你前面有段塌方","阴狠":"对方笑了笑，笑意没到眼里","痴情":"对方在等一个没来的人","怯懦":"对方先往后退了半步","圆滑":"对方先报了自家师门，又夸你的剑穗"})
    hint=next((lines[t] for t in n.traits if t in lines),"对方点了点头")
    where=pv(w,"偶遇地",["山道上","溪边石桥上","坊市口","雨后的竹林里","去寒潭的小路上","茶棚檐下"])
    ch=w.choose([opt("结伴走一程",["kind","curious"],1),opt("拱手别过",["careful"],0)])
    if ch[2]: fav(w,n,8,"同行过一段山路",5); P(w,"%s遇见%s，%s。%s"%(where,n.name,hint,pv(w,"偶遇同行",["结伴走了一程。","同行到岔路口才分开。","一起避了场雨，说了些各自的来处。","你分了半块干粮，对方回了一句谢。"]))); w.chron(n,"山道上遇见%s，同行一程。"%w.P.name)
    else: P(w,"%s遇见%s，%s。%s"%(where,n.name,hint,pv(w,"偶遇别",["各自赶路。","你拱了拱手，没多停。","彼此点头，擦肩而过。"])))
Tpl("偶遇",0,2,lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:not w.known(c))),_run,
    lambda w,r:3, doc="条件：存在未结识NPC。选择：结伴(+好感,记忆)/别过。作用：玩家社交圈的入口。")

# 2 求助→连锁「报恩」或「恩将仇报」
def _run(w,r,c):
    n=r["B"]; meet(w,n,"")
    ch=w.choose([opt("渡一口灵气给她/他",["kind","brave"],"help"),opt("留下伤药就走",["careful"],"half"),opt("搜走储物袋",["greedy"],"rob")])
    if ch[2]=="help":
        w.P.injured=3; fav(w,n,25,"重伤时%s救了我"%w.P.name,30); k=w.rng.randrange(3); P(w,["在寒潭边救下重伤的%s，耗了三日修为。","%s倒在青庐柴门外，你守了一夜，渡了三日修为。","山涧里捞起昏迷的%s，背回青庐养伤。"][k]%n.name)
        w.chron(n,"重伤倒在寒潭边，被%s所救。"%w.P.name); w.schedule(w.rng.randint(8,25),"报恩",{"B":n.id},where=["寒潭边","柴门外","山涧里"][k])
    elif ch[2]=="half": fav(w,n,8,"%s留过一瓶药"%w.P.name,8); P(w,"给%s留了一瓶伤药。"%n.name)
    else:
        fav(w,n,-50,"%s趁我重伤劫了我"%w.P.name,-45); n.R(w.P).grudge+=60; P(w,"搜走了%s的储物袋，得灵石若干。没回头。"%n.name)
        w.chron(n,"重伤时被%s劫了储物袋。"%w.P.name); w.schedule(w.rng.randint(15,40),"仇人上门",{"B":n.id})
Tpl("求助",1,8,lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:c.injured>0 and not any(m[1]==w.P.id for m in c.mem)) or pick(w,lambda c:not any(m[1]==w.P.id for m in c.mem))),_run,
    lambda w,r:2+(r["B"].injured>0)*3, doc="条件：有受伤NPC优先。三选一，分别排程『报恩』或『仇人上门』。")

def _run(w,r,c):
    n=r["B"]; gift=w.rng.choice(n.likes)
    P(w,"%s找到青庐，放下一份%s。%s"%(n.name,gift,pv(w,"报恩语",["『那日%s的事，我记着。』","没多说，只道一句『欠你的』。","说是路过，坐了半日才走。","『那条命是你捡回来的。』"]).replace("%s",c.get("where","寒潭边")))); fav(w,n,10); w.chron(n,"去青庐还了%s的人情。"%w.P.name)
    if n.R(w.P).favor>50 and n.sex!=w.P.sex and not n.partner(w): w.schedule(w.rng.randint(10,20),"表白",{"B":n.id})
Tpl("报恩",1,-6,None,_run,chain_only=True,doc="连锁：求助(救)后8-25日。好感够高且异性单身→排程『表白』。")

def _run(w,r,c):
    n=r["B"]
    ch=w.choose([opt("迎战",["brave","proud"],"f"),opt("赔礼",["kind","careful"],"s"),opt("从后窗走",["careful"],"r")])
    if ch[2]=="f":
        if w.P.lv+w.rng.random()*5>n.lv+w.rng.random()*4: P(w,"%s寻上青庐，被你在院里打退。"%n.name); n.injured=10; n.R(w.P).grudge+=20; w.chron(n,"寻%s报仇，败退。"%w.P.name)
        else: w.P.injured=12; P(w,"%s寻上青庐，你败了，丹炉被砸。"%n.name); w.chron(n,"砸了%s的丹炉。"%w.P.name); n.R(w.P).grudge-=30
    elif ch[2]=="s": n.R(w.P).grudge-=25; P(w,"%s寻上门，你把那袋灵石原样奉还，又添了一成。"%n.name)
    else: P(w,"%s寻上门时，你已从后窗走了。青庐空了三天。"%n.name); w.schedule(20,"仇人上门",{"B":n.id})
Tpl("仇人上门",2,25,None,_run,chain_only=True,doc="连锁：劫掠/结仇后。逃走会再次排程自己。")

# 5 表白
def _run(w,r,c):
    n=r["B"]; meet(w,n,"")
    ch=w.choose([opt("应下",["love","kind"],1),opt("婉拒",["careful","proud"],0)])
    if ch[2]: n.R(w.P).tags.add("道侣"); w.P.R(n).tags.add("道侣"); P(w,"%s在桂树下问你愿不愿意同修。你说好。"%n.name); w.chron(n,"与%s结为道侣。"%w.P.name); w.rumor("%s与%s结为道侣。"%(w.P.name,n.name),[n])
    else: fav(w,n,-10,"%s拒了我"%w.P.name,-5); P(w,"%s问你愿不愿意同修。你说，道还长。"%n.name)
Tpl("表白",2,-10,lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:w.known(c) and c.sex!=w.P.sex and c.R(w.P).favor>45 and not c.partner(w) and not w.P.partner(w))),_run,
    lambda w,r:4, doc="条件：认识、异性、好感>45、双方单身。")

# 6 旧友死讯（世界离屏发生的事浮到玩家面前）
def _run(w,r,c):
    n=r["B"]; w.flags["mourned:%d"%n.id]=1; how=n.log[-1][1].rstrip("。")
    ch=w.choose([opt("去收殓",["kind","love"],1),opt("遥遥一拜",["careful"],0)])
    P(w,"听说%s——%s。"%(n.name,how)+("你赶去，替他/她立了块无字碑。" if ch[2] else "你朝那方向拜了三拜。"))
    killer=next((x for x in w.npcs() if ("死于%s"%x.name) in how or ("被%s"%x.name) in how),None)
    if killer and ch[2]: w.P.R(killer).grudge+=40; w.P.remember(w,killer,"%s杀了%s"%(killer.name,n.name),-30); w.schedule(w.rng.randint(5,15),"寻凶",{"B":killer.id})
Tpl("旧友死讯",2,10,lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:True) and next((c for c in w.npcs(False) if not c.alive and not c.ascended and w.known(c) and w.P.R(c).favor>5 and not w.flags["mourned:%d"%c.id]),None)),_run,
    lambda w,r:6, doc="条件：认识且有好感的NPC已在离屏死去。若有凶手→排程『寻凶』。")

def _run(w,r,c):
    n=r["B"]; P(w,"打听到%s在%s。"%(n.name,n.place))
    ch=w.choose([opt("去讨个说法",["brave","revenge"],1),opt("先修到能赢再说",["careful"],0)])
    if ch[2]:
        if w.P.lv+w.rng.random()*6>n.lv+w.rng.random()*4: P(w,"与%s在%s一战，斩之。"%(n.name,n.place)); w.die(n,"被%s所斩"%w.P.name)
        else: w.P.injured=15; P(w,"与%s一战，败，伤了根基。"%n.name); n.R(w.P).grudge+=20
    else: P(w,"把%s的名字刻在丹炉底下。"%n.name); w.schedule(40,"寻凶",{"B":n.id})
Tpl("寻凶",2,20,None,_run,chain_only=True,doc="连锁：旧友死讯(收殓)后。可推迟，推迟会再排程。")

# 8 传闻：把世界新闻透给玩家，并可能引出事件
def _run(w,r,c):
    news=[x for x in w.news if x[0]>w.day-15 and x[2] and any(w.known(w.C[i]) for i in x[2])] or w.news[-5:]
    d,t,_=w.rng.choice(news); P(w,pv(w,"传闻",["坊市茶摊上听人说：%s","说书先生今天讲的是：%s","药铺伙计压低声音告诉你：%s","过路的散修提了一句：%s"])%t)
Tpl("坊市传闻",0,0,lambda w:{} if w.news else None,_run,lambda w,r:2.5,cooldown=10,doc="把近15日世界新闻(优先玩家认识的人)说给玩家。让离屏世界可见。")

# 9 赠礼：投其所好
def _run(w,r,c):
    n=r["B"]; g=w.rng.choice(LIKES)
    if g in n.likes: fav(w,n,15,"%s记得我喜欢%s"%(w.P.name,g),12); P(w,pv(w,"赠中",["托人给%s捎去%s。回信只有两个字：『正好。』","给%s送了%s，对方当场就收进了袖里。","%s收到%s，回了你一封很长的信。"])%(n.name,g))
    elif g in n.dislikes: fav(w,n,-6); P(w,pv(w,"赠厌",["给%s送了%s。东西被原样退回。","%s看了一眼你送的%s，没说话。"])%(n.name,g))
    else: fav(w,n,4); P(w,pv(w,"赠平",["给%s送了%s。","托人给%s捎了%s，听说收下了。","顺手给%s带了%s。"])%(n.name,g))
Tpl("赠礼",0,-3,lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:w.known(c) and w.P.R(c).favor>10)),_run,doc="喜好命中/厌恶命中/中性三档。")

# 10 夺宝挑衅
def _run(w,r,c):
    n=r["B"]; meet(w,n,"")
    ch=w.choose([opt("让给他",["careful","kind"],0),opt("各凭本事",["brave","proud","greedy"],1)])
    if ch[2]:
        if w.P.lv+w.rng.random()*5>n.lv+w.rng.random()*5: P(w,pv(w,"朱果胜",["与%s争一枚朱果，你先摘到了。","%s的手慢了半寸，朱果落在你掌心。","和%s绕着朱果树斗了三合，你摘了果子就走。"])%n.name); n.R(w.P).grudge+=20; n.remember(w,w.P,"%s抢了我的朱果"%w.P.name,-15)
        else: w.P.injured=6; P(w,pv(w,"朱果败",["与%s争朱果，挨了一掌。","朱果被%s摘走，你肩上青了一块。","和%s争果子，被一道剑气削了半截袖子。"])%n.name)
    else: fav(w,n,5); P(w,pv(w,"朱果让",["把朱果让给了%s。","你退了一步，朱果归了%s。","%s道了声承让，你笑了笑。"])%n.name)
Tpl("朱果之争",1,8,lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:c.place in("后山","寒潭","古战场"))),_run,lambda w,r:1+r["B"].tag("贪财")*2,doc="地点相关。贪财NPC权重高。")

# 11 两方相争，玩家站队
def _run(w,r,c):
    a,b=r["A"],r["B"]; w.flags["side:%d:%d"%(min(a.id,b.id),max(a.id,b.id))]=1
    ch=w.choose([opt("帮%s"%a.name,["brave"],a),opt("帮%s"%b.name,["kind"],b),opt("不掺和",["careful"],None)])
    pre=pv(w,"站队起",["撞见%s与%s对峙","%s和%s在坊市后巷拔了剑","听见林子里%s在骂%s","%s堵住了%s的去路"])%(a.name,b.name)
    if ch[2] is None: P(w,pre+pv(w,"站队避",["，你绕路走了。","，你只当没看见。","，你在远处站了一会儿，走了。"])); return
    x=ch[2]; y=b if x is a else a; fav(w,x,15,"%s帮过我"%w.P.name,15); y.R(w.P).grudge+=25; y.remember(w,w.P,"%s帮%s对付我"%(w.P.name,x.name),-20)
    P(w,pre+pv(w,"站队选",["，你站到了%s身边。","，你替%s挡了一剑。","，你开口替%s说了句话。"])%x.name)
def _b(w):
    for a in w.npcs():
        for i,r in a.rel.items():
            b=w.C[i]
            if not b.player and b.alive and r.grudge>=30 and (w.known(a) or w.known(b)) and not w.flags["side:%d:%d"%(min(a.id,b.id),max(a.id,b.id))]: return {"A":a,"B":b}
Tpl("站队",1,10,_b,_run,lambda w,r:3,doc="条件：有一对仇怨≥30的NPC且玩家认识其一。选边会同时结交与结仇。")

# 12 拜师邀请
def _run(w,r,c):
    m=r["B"]; meet(w,m,"")
    ch=w.choose([opt("拜师",["kind","curious"],1),opt("谢过",["proud"],0)])
    if ch[2]: m.R(w.P).tags.add("徒"); w.P.R(m).tags.add("师"); P(w,pv(w,"拜师",["%s说你根骨尚可，收你为记名弟子。","%s看了你练剑，丢下一句『明日卯时来』。","%s替你理顺了一处经脉，你跪下磕了头。"])%m.name); w.chron(m,"收%s为记名弟子。"%w.P.name); w.schedule(w.rng.randint(15,30),"师父考验",{"B":m.id})
    else: P(w,"%s想收你为徒，你谢过了。"%m.name)
Tpl("拜师",1,-4,lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:c.lv>=w.P.lv+6 and c.side!="魔" and c.R(w.P).favor>=0)) if not any("师" in r.tags for r in w.P.rel.values()) else None,_run,doc="条件：玩家无师、NPC高6级以上非魔道。")
def _run(w,r,c):
    m=r["B"]
    if w.rng.random()<.5+w.P.lv*.05: w.P.xp+=20; P(w,"%s命你在寒潭坐满七日。你坐满了，师父多看了你一眼。"%m.name); fav(w,m,10)
    else: P(w,"%s命你在寒潭坐满七日。第五日你起身走了。"%m.name); fav(w,m,-8)
Tpl("师父考验",1,0,None,_run,chain_only=True,doc="连锁：拜师后。")

# 14 道侣遇险（玩家道侣）
def _run(w,r,c):
    n=r["B"]; ch=w.choose([opt("去寻",["love","brave"],1),opt("等消息",["careful"],0)])
    if ch[2]: w.P.injured=8; fav(w,n,20,"%s来寻我"%w.P.name,25); P(w,"%s在云梦泽失了消息。你寻了九天，在一处浅滩找到人。"%n.name)
    elif w.rng.random()<.4: w.die(n,"在云梦泽失踪，再没回来")
    else: P(w,"%s在云梦泽失了消息，半月后自己回来了，没提路上的事。"%n.name); fav(w,n,-15,"我出事时%s没来"%w.P.name,-20)
Tpl("道侣遇险",2,20,lambda w:(lambda p:{"B":p} if p else None)(w.P.partner(w)),_run,lambda w,r:3,doc="条件：玩家有道侣。不去寻可能永失。")

# 15 道侣争执（性格冲突）
def _run(w,r,c):
    n=r["B"]; op=n.opinion(w.P)
    if op<30: P(w,"与%s为一件小事争了半夜，谁也没服谁。"%n.name); fav(w,n,-10)
    else: P(w,"与%s拌了两句嘴，第二天灶上多了一碗粥。"%n.name); fav(w,n,3)
Tpl("道侣口角",0,3,lambda w:(lambda p:{"B":p} if p else None)(w.P.partner(w)),_run,doc="条件：有道侣。结果由性格相性决定。")

# 16 心魔：张力高时
def _run(w,r,c):
    bad=[m for m in w.P.mem if m[3]<0] or [[0,0,"那盏灯",0]]
    m=w.rng.choice(bad); ch=w.choose([opt("直视它",["brave"],1),opt("闭目诵经",["careful"],0)])
    P(w,pv(w,"心魔起",["闭关时心魔起，幻出的是：%s。","夜半入定，眼前又是%s。","灯影里浮出旧事——%s。"])%m[2]+("你看着它散了。" if ch[2] and w.rng.random()<.6 else "出关后三日不想说话。"))
Tpl("心魔",1,-15,lambda w:{} if w.tension>45 else None,_run,lambda w,r:4,doc="条件：张力>45。内容取玩家的负面记忆——让往事回来。")

# 17 魔修袭镇（全局大事件，拉入多人）
def _run(w,r,c):
    m=r["M"]; helpers=[x for x in w.npcs() if x.side=="正" and x.R(w.P).favor>20][:2]
    ch=w.choose([opt("护着镇口",["brave","kind"],1),opt("带姑母进山躲",["careful","love"],0)])
    if ch[2]:
        P(w,"%s带人血洗山下小镇。你守在镇口%s。"%(m.name,"，"+"、".join(h.name for h in helpers)+"闻讯赶来" if helpers else ""))
        for h in helpers: fav(w,h,10,"一起守过镇子",15); w.chron(h,"与%s同守小镇。"%w.P.name)
        m.R(w.P).grudge+=30; w.P.injured=10
    else: P(w,"%s血洗小镇那夜，你背着姑母进了后山。"%m.name); w.P.remember(w,m,"小镇那夜的火光",-20)
    w.rumor("%s血洗了后山下的小镇。"%m.name,[m])
Tpl("魔修袭镇",2,30,lambda w:(lambda b:{"M":b} if b else None)(pick(w,lambda c:c.side=="魔" and c.lv>=w.P.lv+2)),_run,lambda w,r:2,doc="大事件。友好正道NPC会来援手。",max_n=1,min_day=20)

# 18 秘境开启
def _run(w,r,c):
    party=w.rng.sample([x for x in w.npcs() if x.lv<12] or w.npcs(),min(3,len(w.npcs())))
    for x in party: x.place="古战场"
    P(w,pv(w,"秘境",["古战场秘境开了。同行的有%s。","云梦泽深处的秘境浮出水面，你和%s先后进去。","一道残阵在后山裂开，你和%s结伴探了进去。"])%"、".join(x.name for x in party))
    for x in party: meet(w,x,"")
    if w.rng.random()<.5:
        a=w.rng.choice(party); P(w,"出秘境时，%s在背后推了你一把。"%a.name); a.R(w.P).grudge+=10; w.P.remember(w,a,"秘境里%s推我"%a.name,-20); w.P.R(a).grudge+=30
    else: b=w.rng.choice(party); fav(w,b,12,"秘境里一起逃出来",15); P(w,"秘境塌时，%s拉了你一把。"%b.name)
    w.P.xp+=15
Tpl("秘境",2,15,lambda w:{} if len(w.npcs())>=3 else None,_run,lambda w,r:1.5,doc="大事件：一次结识多人，随机产生恩或怨。",max_n=3)

# 19-30 小事件（日常，给喘息和质感）
def simple(id, text, cond=lambda w:{}, eff=None, tension=-2, doc="", cooldown=6):
    def _r(w,r,c):
        P(w,text(w,r) if callable(text) else text)
        if eff: eff(w,r)
    Tpl(id,0,tension,cond,_r,doc=doc,cooldown=cooldown)
simple("姑母来信",lambda w,r:pv(w,"姑母",["姑母来信，说镇上的桂花开了，问你吃饭没有。","姑母托人捎来一罐腌菜，罐底压着十个铜板。","姑母来信，只写了『冷了加衣』四个字。","姑母说隔壁王婶的孙子会走路了，又问你何时回。","姑母的信被雨打湿了一半，剩下那半是叮嘱。"]),doc="家书。青庐生活感。")
simple("夜雨",lambda w,r:pv(w,"夜雨",["夜雨敲窗。你想起%s。","灯花爆了一下。你没来由地想起%s。","山里起雾，像那年和%s走过的那段路。","听见檐下风铃响，以为是%s来了。","梦见%s站在桂树下，醒来记不清说了什么。"])%w.rng.choice([w.C[i].name for i,x in w.P.rel.items() if x.met] or ["姑母"]),doc="把玩家认识的人随机拎回来。")
simple("灵田",lambda w,r:pv(w,"灵田",["灵田里冒了一株不认识的苗。","鸟啄了半垄灵米。","今年的灵米结得密。","夜里下了霜，你给灵田盖了草帘。","田埂边的野兔又来了，你没赶它。","引水的竹管裂了，修了一下午。"]),eff=lambda w,r:setattr(w.P,"xp",w.P.xp+2),doc="家园。")
simple("访客",lambda w,r:pv(w,"访客",["%s路过青庐，讨了一碗茶。","%s顺路来看你，带了半袋新茶。","%s在柴门外喊了你一声，进来坐了坐。","%s来借丹炉，还的时候擦得锃亮。"])%r["B"].name+{"好奇":"问了很多你炉子的事。","淡泊":"喝完就走了。","傲气":"嫌你的茶淡。","温柔":"走前替你把晾的衣裳收了。","贪财":"眼睛在你的灵田上转了好几圈。"}.get(r["B"].traits[0],"坐了一刻。"),
       cond=lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:w.known(c) and c.R(w.P).favor>0)),eff=lambda w,r:fav(w,r["B"],5),doc="熟人上门，+好感。")
simple("坊市欺客",lambda w,r:pv(w,"欺客",["%s卖你一株灵草，回来才发现是染了色的。","在%s的摊上买了张符，一用就碎了。","%s称灵米的秤，少了三两。","%s卖的“百年参”，根须是粘上去的。"])%r["B"].name,cond=lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:c.tag("贪财") or c.tag("圆滑"))),
       eff=lambda w,r:(w.P.R(r["B"]).__setattr__("grudge",w.P.R(r["B"]).grudge+10),meet(w,r["B"],"")),tension=4,doc="贪财/圆滑NPC限定。")
simple("师门书信",lambda w,r:pv(w,"师信",["%s从%s来信，说师门近来不太平。","%s捎信来：%s要开山门大比，问你去不去。","%s的信里只问你修到哪了，末尾提了一句%s的长老病了。"])%(r["B"].name,r["B"].sect),cond=lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:"师" in w.P.R(c).tags)),tension=4,doc="有师父时。")
simple("义结金兰",lambda w,r:pv(w,"金兰",["与%s在桂树下撮土为香，义结金兰。","%s拉你在山神庙里磕了三个头，从此以姐妹相称。","和%s喝光一坛酒，约定此后有难同当。"])%r["B"].name,cond=lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:w.known(c) and c.sex==w.P.sex and c.opinion(w.P)>45 and "结义" not in w.P.R(c).tags)),
       eff=lambda w,r:(w.P.R(r["B"]).tags.add("结义"),r["B"].R(w.P).tags.add("结义"),w.chron(r["B"],"与%s义结金兰。"%w.P.name)),tension=-6,doc="同性、opinion>45。")
simple("飞升异象",lambda w,r:pv(w,"飞升",["夜里天边亮了一道光，听说是有人飞升了。你在院里站了很久。","山那边雷云聚了三日，散时满天霞光。有人飞升了。"]),cond=lambda w:{} if any(c.ascended and c.log[-1][0]>w.day-5 for c in w.npcs(False)) else None,doc="世界有人飞升后5日内。")
simple("闭关小成",lambda w,r:pv(w,"闭关",["闭关七日，丹田里那团气凝实了些。","在寒潭边坐了一夜，周天走得比往常顺。","炉火守了三天，炼出一枚像样的回气丹。","读通了功法里卡了半月的一句。","打坐到天亮，灵气在指尖绕了一圈才散。"]),eff=lambda w,r:setattr(w.P,"xp",w.P.xp+6),doc="修炼节奏点。")
simple("旧物",lambda w,r:pv(w,"旧物",["整理行囊时翻出一件旧物，是%s当初给的。","窗台上那只纸鹤，是%s折的。","那把伞还靠在门后，是%s借的，一直没还。","灶边那只缺口的碗，%s来时用过。"])%r["B"].name,cond=lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:w.known(c) and w.P.R(c).favor>20)),doc="记忆回响。")
simple("宗门大比",lambda w,r:pv(w,"大比",["%s在大比中夺魁，名声传到了坊市。","听说%s在宗门大比上一剑败了三人。","坊市都在押%s能不能进大比前三。"])%r["B"].name,cooldown=25,cond=lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:c.sect!="散修" and c.lv>=6,key=lambda c:1+w.known(c)*4)),tension=1,doc="世界大事，偏向熟人。")
simple("劫修拦路",lambda w,r:pv(w,"劫修",["去坊市的路上被%s拦下，交了买路钱。","%s在山口横剑拦路，你留下半袋灵石才过去。","夜路上被%s截住，丢了一瓶回气丹。"])%r["B"].name,cond=lambda w:(lambda b:{"B":b} if b else None)(pick(w,lambda c:c.side=="魔" or c.tag("阴狠"))),
       eff=lambda w,r:(w.P.R(r["B"]).__setattr__("grudge",w.P.R(r["B"]).grudge+15),meet(w,r["B"],"")),tension=8,doc="魔道/阴狠NPC。")

# ---------------------------------------------------------------- 玩家自身成长（简化）
def player_tick(w):
    p=w.P; p.xp+=w.rng.uniform(.8,1.5)*(.4 if p.injured else 1)
    if p.injured: p.injured-=1
    if p.xp>=8*(1.35**p.lv): p.xp=0; p.lv+=1; (p.lv in (9,12)) and P(w,"破境，入%s。"%p.realm)

def run(seed, days, n, quiet=False):
    Char._n=0; w=World(seed,n)
    for _ in range(days):
        w.tick(); player_tick(w); w.storyteller()
    return w

def metrics(w):
    ev=w.player_events; n=len(ev); c=collections.Counter(ev)
    tri=[tuple(ev[i:i+3]) for i in range(n-2)]
    lines=[t for d,t in w.P.log]
    def skel(t): # 去掉人名后的句子骨架，用于衡量“句子是否重复”
        for x in w.C.values(): t=t.replace(x.name,"某")
        return t
    sk=[skel(t) for t in lines]
    met=sum(1 for r in w.P.rel.values() if r.met)
    deep=sum(1 for i,r in w.P.rel.items() if r.met and (abs(r.favor)>=20 or r.grudge>=20 or r.tags))
    return dict(玩家事件数=n, 用到模板数=len(c), 模板总数=len(T), 最常见模板占比=round(c.most_common(1)[0][1]/max(1,n),3),
        三连序列去重率=round(len(set(tri))/max(1,len(tri)),3), 生平句骨架去重率=round(len(set(sk))/max(1,len(sk)),3),
        连锁事件数=sum(c[k] for k in T if T[k].chain_only), 结识NPC=met, 深交或结仇=deep,
        世界死亡=sum(1 for x in w.npcs(False) if not x.alive and not x.ascended), 飞升=sum(1 for x in w.npcs(False) if x.ascended),
        世界道侣对=sum(1 for x in w.C.values() for r in x.rel.values() if "道侣" in r.tags)//2,
        人设一致度=round(max(w.hist.values())/max(1,sum(w.hist.values())),3) if w.hist else 0, 劫掠与救助比="%d:%d"%(sum(1 for d,t in w.P.log if '储物袋' in t),sum(1 for d,t in w.P.log if '救下' in t or '捞起' in t or '守了一夜' in t)), 传闻次数=c['坊市传闻'], 世界事件={k:v for k,v in w.flags.most_common() if k.startswith(("w:","solo:"))}, 玩家境界=w.P.realm), set(c), ev

def portrait_line(c, w):
    rels=[]
    for i,r in sorted(c.rel.items(), key=lambda kv:-abs(kv[1].favor)-kv[1].grudge-len(kv[1].tags)*30)[:4]:
        o=w.C[i]; tag="/".join(sorted(r.tags)) or ("仇" if r.grudge>=30 else "好友" if r.favor>=30 else "相识")
        rels.append("%s(%s,好感%d,怨%d)"%(o.name,tag,r.favor,r.grudge))
    return "%s｜%s %s｜%s｜性格:%s｜喜:%s 厌:%s｜志:%s｜%s\n   关系: %s"%(c.name,c.sex,c.sect,c.realm,"、".join(c.traits),"、".join(c.likes),c.dislikes[0],c.goal,
        "存" if c.alive else ("飞升" if c.ascended else "殁"), "；".join(rels) or "—")

if __name__=="__main__":
    ap=argparse.ArgumentParser(); ap.add_argument("--seed",type=int,default=7); ap.add_argument("--days",type=int,default=100)
    ap.add_argument("--npcs",type=int,default=20); ap.add_argument("--runs",type=int,default=8); ap.add_argument("--quiet",action="store_true")
    a=ap.parse_args()
    w=run(a.seed,a.days,a.npcs)
    if not a.quiet:
        print("="*20,"样例：种子%d，%d日，初始NPC %d"%(a.seed,a.days,a.npcs),"="*20)
        print("\n【主角】"+portrait_line(w.P,w)); print("\n【主角生平】")
        for d,t in w.P.log: print("  第%3d日  %s"%(d,t))
        notable=sorted([c for c in w.npcs(False)], key=lambda c:-len(c.log))[:3]
        for c in notable:
            print("\n【NPC生平】"+portrait_line(c,w))
            for d,t in c.log[-10:]: print("  第%3d日  %s"%(d,t))
            if c.mem: print("   记忆: "+"；".join("%s(%+d)"%(m[2],m[3]) for m in sorted(c.mem,key=lambda m:-abs(m[3]))[:3]))
        print("\n【世界传闻·最近8条】")
        for d,t,_ in w.news[-8:]: print("  第%3d日  %s"%(d,t))
    m,s0,ev0=metrics(w)
    print("\n【本局指标】"+json.dumps(m,ensure_ascii=False))
    # 多种子对比：不同局是否走出不同故事
    sets=[];seqs=[];rows=[]
    for sd in range(a.seed, a.seed+a.runs):
        wx=run(sd,a.days,a.npcs); mx,sx,ex=metrics(wx); sets.append(sx); seqs.append(ex); rows.append(mx)
    jac=[len(sets[i]&sets[j])/len(sets[i]|sets[j]) for i in range(len(sets)) for j in range(i+1,len(sets))]
    first10=[tuple(s[:10]) for s in seqs]
    def avg(k): return round(sum(r[k] for r in rows)/len(rows),3)
    print("【%d局汇总】"%a.runs+json.dumps(dict(平均玩家事件=avg("玩家事件数"),平均用到模板=avg("用到模板数"),平均最常见占比=avg("最常见模板占比"),
        平均三连去重率=avg("三连序列去重率"),平均生平句骨架去重率=avg("生平句骨架去重率"),平均连锁=avg("连锁事件数"),平均结识=avg("结识NPC"),平均深交或结仇=avg("深交或结仇"),
        平均世界死亡=avg("世界死亡"),平均世界道侣对=avg("世界道侣对"),平均传闻次数=avg("传闻次数"),平均人设一致度=avg("人设一致度"),模板集合Jaccard均值=round(sum(jac)/len(jac),3),前10事件序列各不相同=len(set(first10))==len(first10)),ensure_ascii=False))
