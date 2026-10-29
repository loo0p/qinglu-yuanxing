# -*- coding: utf-8 -*-
"""v0.15 qinglu_chron：她按月的日子（对标《某某宗女修修炼手札》的履历密度），每条都挂机制。
由 tools/make_packs.py 在生成前 exec 进来（共用 g / chron / rel / mem / chance / iff / setv / fav / pc）。
- 触发：world.tick 每月按概率发 on:pmonth（A = 她；ctx.sec 闭关中 / ctx.road 在外 / ctx.maj 大境界 0 炼气 1 筑基 2 金丹 3 元婴）
- 同一 family "pm" 每月只出一件；每条都有 cooldown，免得同一类事扎堆
- 每个结果都改点什么：资质（attr）、寿元（life）、修为（pxw）、感悟（wu）、灵石（ling）、伤（pinj）、好感/怨（rel/fav）、得物（pitem）、伏笔（mark/schedule）
- 伏笔→回响：救人、结怨、种树、埋酒、托付，隔五到几十年回来，文里点名当年的事与年份"""

def attr(who, k, d=1): return {"op": "attr", "who": who, "k": k, "d": d}
def life(who, y): return {"op": "life", "who": who, "y": y}
def pxw(n): return {"op": "pxw", "n": n}
def wu(n): return {"op": "wu", "n": n}
def ling(n): return {"op": "ling", "n": n}
def pinj(m): return {"op": "pinj", "days": m}
def pitem(origin, slot=None, grade=0):
    o = {"op": "pitem", "origin": origin, "grade": grade}
    if slot: o["slot"] = slot
    return o
def sched(sid, lo, hi, keep=(), cast=None):
    o = {"op": "schedule", "id": sid, "in": [lo, hi], "keep": list(keep)}
    if cast: o["cast"] = cast
    return o
def xpn(who, f): return {"op": "xp", "who": who, "frac": f}
def ninj(who, m): return {"op": "inj", "who": who, "days": m}

SEC = "ctx.sec == 1"
OUT = "ctx.sec == 0"
HOME = "ctx.sec == 0 and ctx.road == 0"
ROAD = "ctx.road == 1"

# ---------------------------------------------------------------- 语法
g("q_sec_head", "闭关中，", "静室里，", "闭关的这些日子，", "{jie}静室里，", "关中某夜，", "入定时，")
g("q_mai", "手少阳一脉", "任脉", "足厥阴那一段", "丹田下三寸", "督脉第七节", "左臂的少海穴", "心脉旁一条细络")
g("q_zc_a", "一缕灵气在#q_mai#里走岔了", "运到#q_mai#时，灵气忽然一滞", "周天转到#q_mai#，像撞上了一块冰", "#q_mai#里窜起一股燥火")
g("q_zc_ok", "她停功三日，一丝一丝引了回来。", "她没有硬冲，散了功，从头再走一遍。", "她咬牙守住灵台，等那股气自己倒流回去。", "她拿旧主手记里的笨法子，一寸一寸地理顺。")
g("q_zc_bad", "她想硬压下去，喉头一甜，呕出一口血。", "她急了，强行冲关，经脉里像被刀刮过。", "那股气反冲上来，她眼前一黑，栽倒在蒲团边。")
g("q_dw_word", "“守”", "“缓”", "“藏”", "“退”", "“空”", "“拙”", "“慢”", "“舍”", "“静”", "“满”")
g("q_dw_obj_0", "吐纳", "那段引气诀", "每日的周天", "旧主手记里的心法")
g("q_dw_obj_1", "道基", "灵液的流转", "筑基心法的第三重", "丹田里那汪灵液")
g("q_dw_obj_2", "丹火", "金丹的转法", "丹纹的走向", "那枚金丹的重量")
g("q_dw_obj_3", "元婴的呼吸", "元神出窍的门道", "婴儿手里那缕光", "神识的边界")
_DW = ["悟到#q_dw_word#字，于@上通了一窍。", "盯着窗纸上的一点光看了整夜，@忽然顺了。", "想起#q_dw_who#说过的一句闲话，@的关窍竟在这里。",
  "把@从头推了一遍，在第三处停住，又推一遍——原来如此。", "听见檐下滴水，滴到第九十九声，@豁然开朗。"]
for _i in range(4):
    g("q_dw_%d" % _i, *[x.replace("@", "#q_dw_obj_%d#" % _i) for x in _DW])
g("q_dw_who", "师父", "坊市卖茶的老头", "一个过路的和尚", "旧主手记的批注", "小时候娘", "山下说书的")
g("q_xm_in", "心魔来了。", "入定时，四下忽然起了雾。", "梦里又回到那一年。", "关中第七夜，静室里多了一个人影。")
g("q_xm_who", "心魔化作{B}的模样，站在门口冲她笑。", "雾里走出来的是{B}，说的话和当年一字不差。", "那人影是{B}，手里拿着她当年没要的东西。")
g("q_xm_noone", "心魔化作她自己的模样，问她修这个道做什么。", "雾里是十六岁的自己，跪在青庐门口。", "心魔不说话，只把她这些年的寿元一年一年地数给她听。")
g("q_xm_win", "她没有答，只把那段心诀念到第三遍，雾散了。", "她对着那影子坐了一夜。天亮时，影子先走了。", "她笑了一下：“我知道你是谁。”心魔便碎了。")
g("q_xm_lose", "她答了，答完才知道上了当，丹田里翻江倒海。", "她伸手去拉，扑了个空，一口血喷在蒲团上。", "她被缠了三个月，出来时鬓边多了几根白发。")
g("q_tide", "{jie}青庐底下那条灵脉涨了一回潮，", "灵脉今年格外旺，", "静室的地砖下隐隐发热，灵脉翻了个身，", "后山的灵泉涨了三寸，", "一场地动过后，静室里的灵气浓得化不开，", "这一年山里的雾总不散，雾里全是灵气，", "院里那口井的水忽然甜了，地下灵脉改了道，")
g("q_tide_t", "她趁势多引了几个周天。", "她一口气吐纳到天亮，丹田里满满当当。", "她顺着那股潮把滞了很久的一处冲开了。", "她闭门不出，一连吐纳了四十九日。", "她把这口灵气细细炼了，一丝也没浪费。")
g("q_knock", "有人在叩静室的石门，是{B}。", "{B}在门外喊她的名字，喊了三声。", "门缝里塞进来一张字条，是{B}的笔迹。", "{B}浑身是血，靠在青庐的篱笆上。")
g("q_knock_open", "她散了功，开门。", "她叹了口气，出关去见。", "她没让人等第二回，推开了门。")
g("q_knock_shut", "她没开。", "她在门里坐着，一动没动。", "她隔着门说了句“改日”，便又入了定。")
g("q_sy", "掐指一算，寿元还剩{sy}年。", "数了数，这辈子已经用去了七成。", "镜子里，鬓角又白了几根。")
g("q_sy_ok", "她把那张算寿元的纸烧了，接着坐。", "也好，她想，剩下的够用了。", "她笑自己：“怕什么。”")
g("q_sy_bad", "她心里一慌，那一夜怎么也入不了定。", "她起身在静室里走了三百圈。", "她想起那些已经不在的人，坐到了天亮。")
g("q_dream", "梦见{yb}在{bp}，{B}还是当年的样子。", "梦里又见{B}，两人在{bp}说着{yb}没说完的话。", "梦见{yb}与{B}相识那日，醒来记不清说了什么。")
g("q_dream_t", "醒来，她托人给{B}捎了一句问候。", "她想了想，把这事记在了手记上。", "醒来时，心里软了一块。")
# 在外
g("q_tian_0", "侍弄灵田，拔了一上午的草。", "给青芝搭了一道遮阳的竹帘。", "把灵田的渠重新挖了一遍。", "在田埂上捉了一下午的虫。")
g("q_tian_1", "以灵液浇了一遍药圃，土色都变深了。", "把药圃里的杂草连根拔了，顺手布了一道小阵。", "给药圃挪了位置，挪到灵脉正上方。")
g("q_tian_2", "以丹火温了一遍药圃的土。", "把药圃扩了一倍，种上了从坊市换来的灵种。")
g("q_tian_3", "神识一扫，药圃里每一株草的长势都看得清清楚楚。", "随手一拂，药圃里的虫都散了。")
g("q_tian_good", "这一季收成好，挑了几株拿到坊市卖了。", "今年的药长得格外壮，卖了个好价钱。")
g("q_tian_bad", "一场冰雹砸烂了半畦药苗，白忙一季。", "田里闹了虫，半畦青芝被啃光了。", "一只灵鼠偷了药苗，她追了半座山没追上。")
g("q_dan_try", "开炉试炼一炉#q_dan_name#", "照着旧方子炼#q_dan_name#", "改了两处火候，炼了一炉#q_dan_name#")
g("q_dan_name", "养元丹", "回气散", "清心丸", "止血散", "辟谷丹", "培元丹", "定神香")
g("q_dan_ok", "，成丹七颗，颗颗圆润。", "，开炉时满屋异香。", "，成了五颗，有一颗生了丹纹。")
g("q_dan_bad", "，炉子炸了，眉毛燎去半边。", "，炼成一炉焦炭。", "，火候差了一线，药力散了大半。")
g("q_fu", "画了一夜的符，废了三十张，成了四张。", "在符纸上试了一种新的笔势，画废了一叠。", "把一张残符拓下来，照着补全了。", "替山下的猎户画了几张驱兽符。")
g("q_fang_cheat", "在坊市买了一卷“古方”，回来才发现是新近做旧的。", "替一个哭哭啼啼的少年垫了药钱，过后才知那是个惯骗。", "在坊市赌石，切开是块废料。")
g("q_fang_luck", "在坊市旧货摊上淘到一件{it}，摊主当破烂卖的。", "替一个老修士搬了趟家，老修士送了她一件{it}。", "在坊市的角落里捡了个漏：一件{it}，蒙着厚厚的灰。")
g("q_fang_help", "坊市里有人当街欺负卖药的老妪，她上前拦了。", "替一个被扣了货的散修说了句公道话。", "把迷路的孩子送回了坊市外的村子。", "替一个摆摊的老修士赶走了收保护费的地痞。", "垫钱替一个凡人郎中赎回了被扣的药箱。", "坊市失火，她帮着搬了半夜的货。")
g("q_road_beast", "在山道上撞见一头#q_beast#，", "夜宿山洞，洞里窝着一头#q_beast#，", "过溪时，水里窜出一头#q_beast#，")
g("q_beast", "铁背狼", "赤眼山魈", "雷纹豹", "三尾狐", "黑水蛟", "金翅雕", "石甲熊")
g("q_beast_w", "她斩了它，剥下的妖丹换了灵石。", "斗了半个时辰，她赢了，取了妖丹。", "她一剑削去它半只耳朵，它逃了，落下一枚妖丹。")
g("q_beast_l", "她打不过，挨了一爪，翻下山崖才逃掉。", "她被追了三十里，丢了半个行囊。", "她肩上挨了一口，伤口发黑，养了好几个月。")
g("q_beast_avoid", "她屏住气，绕开了。", "她退了三步，没动手，等它自己走了。")
g("q_lun", "与{B}在{bp}论道一夜，", "{B}来青庐坐了一下午，两人说起各自的功法，", "去{bp}寻{B}喝茶，说到修行的事，")
g("q_lun_good", "她得了一句要紧的话。", "{B}说的一处关窍，正是她卡了很久的地方。", "两人各有所得，约了来年再聚。")
g("q_lun_bad", "话不投机，{B}拂袖走了。", "争到后来，谁也没说服谁，不欢而散。")
g("q_dyn", "山下#q_dyn_name#又换了年号。", "听说#q_dyn_name#的皇帝死了，三个皇子打了起来。", "山下闹了饥荒，逃难的人从青庐外的山道上走了半个月。",
  "#q_dyn_name#亡了，新朝的旗子插到了山脚。", "山下的镇子换了名字，她认识的那家面铺关了门。")
g("q_dyn_name", "大梁", "南楚", "北燕", "东陈", "大周", "西蜀")
g("q_dyn_t", "她去山脚看了一眼，回来坐了很久。", "她想起入山那年山下的样子，记不太清了。", "凡人的百年，原来就是这么一晃。")
g("q_sky", "夜里北斗旁多了一颗赤星，三日不散。", "{jie}天上下了一场流星雨，落在西边。", "正午，日边起了一道白虹。", "一夜之间，后山的桃花全开了，又全落了。", "东边的天裂开一道金光，片刻即合。")
g("q_sky_t", "她看了一夜，心里有所感。", "她把天象记在手记里，翻书查了半月。", "后来听说，那夜有大能陨落。")
g("q_xun", "去看{B}。{B}已经老得认不出人了，", "{B}托人带话，说想见她最后一面。她赶去时，", "听说{B}寿元将尽，她去{bp}看了一回。")
g("q_xun_t", "拉着她的手，说起{yb}的事。", "躺在榻上，指了指墙上挂着的东西。", "精神倒好，絮絮叨叨说了一下午。")
g("q_dao", "与道侣{B}去{bp}看了一回日出。", "{B}替她束了一回发，手很笨。", "与{B}在灯下对坐，各自翻各自的书。", "{B}闭关出来，第一句话是问她吃了没有。")
g("q_dao_bad", "与{B}为一件小事拌了嘴，三天没说话。", "{B}说她心里只有修行，她没有辩。")
g("q_jiang_0", "替一个刚入门的小修士指点了引气的法子。", "在山道上教一个放牛娃认了几个字。")
g("q_jiang_1", "坊市里几个炼气小修士围着她请教，她讲了一个时辰。", "替{B}看了看功法，指出两处错。")
g("q_jiang_2", "在{bp}开坛讲了三日道，来听的人坐满了山坡。", "{B}带着弟子来求一句指点，她说了，那弟子当场入定。")
g("q_jiang_3", "神识一动，看了一眼{B}的经脉，提笔改了三处。", "开坛讲道，讲到第七日，满山的草木都朝她这边歪。")
g("q_qi", "把{it}放在膝上温养了一夜。", "拿灵液擦了一遍{it}。", "斗法后{it}缺了一个口，她自己动手补了。", "{it}夜里嗡嗡作响，像在说话。")
g("q_qi_t", "器灵似乎与她亲近了些。", "用起来顺手多了。", "灵光比从前亮了一层。")
g("q_seed", "在青庐后院种了一株#q_tree#苗。", "从{bp}挖回一棵#q_tree#的幼苗，种在院角。")
g("q_tree", "雷击桃", "紫竹", "银杏", "梧桐", "铁木", "灵梨")
g("q_wine", "埋了一坛桂花酒在梨树下，说等件大事再挖。", "把一坛新酿的米酒埋在院角，坛口封了三层泥。")
g("q_save", "在{bp}救下一个被妖兽追着跑的少年，{B}。", "从山涧里拉上来一个重伤昏迷的修士，{B}。", "替被劫修堵在路上的{B}解了围。")
g("q_save_x", "{B}千恩万谢，说日后一定还这个情。", "{B}磕了三个头，一瘸一拐地走了。", "{B}连名字都没敢多说，道了谢就跑了。")
g("q_feud", "在{bp}与{B}争一株#q_herb#，她先下手为强。", "在{bp}撞见{B}独自一人采#q_herb#，她把药连土挖走了。", "{B}和她同时看中一块#q_herb#，她出价高了一截。")
g("q_herb", "百年黄精", "雪莲", "血灵芝", "龙涎草", "紫金藤", "寒铁")
# 回响
g("q_echo_save", "{B}来了。{yago}前在{p0}救下的那个人，如今已是{br}，提着礼登门。", "有人在青庐外叩门，是{B}——{y0}她救过的那个人。", "{B}托人送来一封信，信里只提了{yago}前{p0}的那件事。")
g("q_echo_save_t", "“这份情，我记了{yago}。”", "临走留下一件{it}。", "说当年那一命，如今算还上了。")
g("q_echo_feud", "{B}在坊市巷口拦住了她。{y0}那株{herb}的事，{B}记了{yago}。", "{B}找上门来，开口便提{y0}在{p0}的那株{herb}。", "{yago}没见，{B}已是{br}，一照面就说：“{herb}的账，该算了。”")
g("q_echo_feud_w", "她赢了，{B}恨恨而去。", "交了几手，{B}没讨到便宜，撂下一句狠话走了。")
g("q_echo_feud_l", "她输了，赔了灵石，肩头带着伤回来。", "她没打过，{B}拿走了她的灵石，算是清了账。")
g("q_echo_feud_bow", "她认了当年的错，赔了一份礼。{B}收了，脸色缓了些。", "她把当年的{herb}折成灵石还了，又多添了一成。")
g("q_echo_tree", "{y0}种下的那株{tree}，如今已高过屋檐。", "院角那棵{tree}，是{yago}前种的，今年第一次开花。", "后院的{tree}长成了，枝上落了一只灵雀。")
g("q_echo_tree_t", "她砍下一段老枝，削成了一件{it}。", "树下的灵气比别处浓了一层，她在树下打坐了一夜。", "她在树下坐了很久，想起种树那年的自己。")
g("q_echo_wine", "挖出了{y0}埋的那坛酒，", "想起{yago}前埋在院角的那坛酒，挖了出来，")
g("q_echo_wine_t", "请{B}来喝。两人喝到半夜，说起了许多已经不在的人。", "一个人喝了半坛，剩下半坛又埋了回去。", "酒已经稠得像蜜，她喝了一口，就醉了。")
g("q_tuo", "{B}把一个包袱托给了她：“等我走了，替我交给{k}。”", "{B}拉着她说：“我那个徒弟，日后你照应些。”")
g("q_tuo_echo", "{B}已经走了{yago}。她依当年所托，把那包袱交到了{k}手里。", "{yago}前{B}托的事，她没忘：今年去看了{B}的后人。")
g("q_tuo_echo_t", "那人当着她的面打开包袱，哭了。", "那孩子长得像{B}，看得她一怔。")
# 叩关
g("q_gate", "修为停在关口已经很久了。", "关口像一堵墙，她每日撞一回。", "瓶颈卡得她夜里睡不着。")
g("q_gate_tip", "坊市药铺的掌柜低声透了个信：有人手里有她要的东西。", "一个相熟的散修来信，说哪里有破境的机缘。", "旧主手记的夹页里，有人用小字写了一句破关的法子。")
g("q_gate_force", "她不信邪，引气硬冲了一回，", "她憋着一口气，在子时冲了一回关，")
g("q_gate_force_ok", "关没破，倒把根基又夯实了一层。", "没冲开，可那一撞，让她看清了关口在哪。")
g("q_gate_force_bad", "气血逆行，伤了经脉。", "冲到一半，一口血涌上来。")
# 她的心性变化（随事起伏）
g("q_xin_up", "这些年的事想通了一些。", "心里那根刺，拔出来了。", "她觉得自己比从前静了。")

# v0.15.3 新伏笔与境界专属
g("q_lend", "在{bp}碰见{B}，人瘦了一圈，说是被人坑了。她摸出十几块灵石塞过去，没要借据。", "{B}托人捎话来借灵石，说是要救急。她凑了十几块，让来人带回{bp}。", "{B}在{bp}的客栈里欠了房钱，被掌柜扣着不让走。她替{B}结了账。")
g("q_echo_lend", "{B}来还{y0}借的灵石了。", "{yago}前借出去的那笔灵石，{B}亲自送了回来。", "有人捎来一个钱袋，是{B}——{y0}她在{p0}接济过的那个人。")
g("q_yue", "在{bp}与{B}分手时，两人约下：多年以后，还在这里喝一杯。", "{B}送她到{bp}的渡口，说：“等你我都再进一步，还在这里见。”她应了。")
g("q_echo_yue", "想起{y0}在{bp}的约，她如期去了。", "{yago}前与{B}的约到了期。她赶到{bp}，", "她记着{bp}的那个约，记了{yago}。")
g("q_echo_wound", "{y0}闭关走岔留下的那处暗伤，", "{yago}前经脉走岔落下的旧伤，", "当年那回走岔，在经脉里留了一道暗伤，")
g("q_echo_lend_dead", "{B}已经不在了。{y0}借出去的那笔灵石，她没再提，只当是送了。", "听说{B}故去了。{yago}前那笔灵石，终究没有还上，她也不在意。")
g("q_echo_qi_miss", "想起{y0}温养过的那件{it}，如今不知落在谁手里了。", "她梦见了那件{it}，醒来才想起，它早已不在身边。")
g("q_echo_jiang", "{y0}她随口指点过的{B}，", "{yago}前听她讲过一回道的{B}，")
g("q_echo_qi", "{y0}起温养的{it}，", "那件{it}跟了她{yago}，", "{yago}来每隔几年便温养一回的{it}，")
g("q_sect", "青云宗", "万剑门", "玄霜谷", "落霞宫", "药王谷", "天衍宗")
g("q_gf", "{sect}派人送来拜帖，请她去做客卿供奉。", "{sect}的长老亲自登门，想请她挂个供奉的名头。")
g("q_echo_gf", "{sect}出了事，派人连夜来请她这位挂名{yago}的供奉。", "{y0}应下的{sect}供奉，今年派上了用场：山门被围，来人跪在青庐外。")
g("q_tu", "{B}跪在青庐门外，求她点拨。", "{B}在青庐外守了三日，说要跟她学道。")
g("q_tu_yes", "她把人领进门，留在身边点拨了一年。", "她没说收，也没说不收，只让{B}每日来扫院子，扫着扫着就教上了。")
g("q_tu_no", "她摇头，让{B}去找宗门。", "她说自己还没到能教人的时候，打发{B}走了。")
g("q_echo_tu", "{y0}在青庐扫过一年院子的{B}，", "{yago}前跪在门外的那个{B}，")
g("q_danhuo", "丹田里那颗金丹忽然烧了起来，丹火顺着经脉往外窜，", "金丹转得太急，丹火反扑，", "结丹后积下的火毒一齐发作，")
g("q_danhuo_ok", "她守住灵台，一寸一寸把火压回丹田，金丹上多了一道纹。", "她不慌，引火淬了一遍经脉，反倒更通透了。")
g("q_danhuo_bad", "没压住，烧伤了心脉，折了些寿元。", "丹火烧穿了一处经脉，吐了一口黑血。")
g("q_shenyou", "元神出窍，神游到东海，看了一回日出。", "元婴离体，沿着青庐那条灵脉走了一遍，看清了它从哪座山来。", "神游万里，在一处古战场停了一夜，悟到些杀伐的道理。", "元神出窍，回到她出生的那个镇子，镇子已经没了。")
g("q_yy_old", "翻看旧年的名册，当年一同在坊市摆摊的人，十停里已去了九停。", "坊市换了三回主人，她认识的掌柜，一个也不在了。", "山下的村子又换了一茬人，没人记得青庐住的是谁。")
# v0.15.5 伏笔与境界事
g("q_map", "在{bp}的旧货摊上淘到半张残图，图上的山形她没见过。", "替人收殓时，从死者怀里摸出半张兽皮残图。", "在一处塌了的洞府里捡到半张残图，另一半被人撕走了。")
g("q_echo_map", "{y0}收着的那半张残图，", "压在箱底{yago}的那半张残图，")
g("q_echo_map_ok", "今年在坊市见到了另一半。她凭着这些年的眼力，把两半拼上，找到了图上那处地方。", "她忽然认出了图上的山形——就是{bp}后头那座。去了一趟，没有白去。")
g("q_echo_map_no", "她又拿出来看了一夜，还是看不懂，收了回去。", "她拿去问了几个人，都说是假的。她不信，又收了起来。")
g("q_dan_en", "她伤还没好，{B}路过，二话没说塞了一颗丹药给她。", "{B}听说她受了伤，托人送来一瓶疗伤的丹。")
g("q_echo_en", "{yago}前{B}给过她一颗丹。", "她一直记着{y0}{B}那颗丹。")
g("q_echo_en_t", "今年听说{B}伤重，她带着自己炼的丹赶去，守了半月。", "{B}寿元将尽，她把手里最好的一株灵草送了过去。")
g("q_home", "回了一趟凡间故里。村口那棵老槐还在，认得她的人已经不多了。", "路过出生的那个镇子，在一户人家门口站了一会儿。那家的孩子冲她笑。")
g("q_echo_home", "{y0}回故里时冲她笑的那个孩子，", "{yago}前故里那户人家的孩子，")
g("q_echo_home_t", "今年托人寻来，已是满头白发，带着孙子给她磕了个头。她给那孩子测了灵根。", "前些年已经过世了。她去坟前站了站，留下一包灵米给那家的后人。")
g("q_xm_echo", "{y0}闭关时，心魔化作{B}的样子来过。", "{yago}前那场心魔里的{B}，")
g("q_benming", "开炉温炼{it}，打算把它炼成本命法宝。", "以金丹之火日夜温养{it}，要与它神魂相连。")
g("q_benming_ok", "七七四十九日后，{it}与她心意相通了。", "炼成了。{it}在她丹田里转了一圈，又回到手上。")
g("q_benming_bad", "炼到一半，{it}承不住丹火，裂了一道缝。", "火候差了一分，前功尽弃，还伤了心神。")
g("q_guanjie", "听说{B}要渡劫，她赶去{bp}，在山外看了一夜雷。", "{B}在{bp}渡劫，她远远看着，天雷落了九道。")
g("q_guanjie_t", "看完回来，她闭门三日，把自己的道又理了一遍。", "她记下了每一道雷落下的方位。")
g("q_xuming", "{B}寿元将尽，她以元婴之力替{B}续了一口气。", "她把自己的一缕元气渡给了{B}，{B}的脸色红润了。")
g("q_xuming_t", "她自己也折了几年寿。", "代价是她鬓边多了几根白发。")
def pm(sid, when, weight, cd, outcomes, effects=(), roles=None, doc=""):
    s = {"id": sid, "trigger": "on:pmonth", "family": "pm", "when": when, "weight": weight, "cooldown": cd,
         "effects": list(effects), "outcomes": outcomes}
    if roles: s["roles"] = roles
    if doc: s["doc"] = doc
    return s
def oc(oid, weight, *effects, when=None, first=False):
    o = {"id": oid, "weight": weight, "effects": list(effects)}
    if when: o["when"] = when
    if first: o["first"] = True
    return o

KNOWN = "g.known(SELF) and SELF.alive and not g.busy(SELF)"

CHRON = [
    # ============ 闭关中
    pm("sec_zouchai", SEC, 1.0, 30, [
        oc("ok", "0.5 + 0.12 * g.at(A, 'xin')", chron("A", "#q_sec_head##q_zc_a#。#q_zc_ok#"), attr("A", "xin", 1), wu(2)),
        oc("bad", "1.2 - 0.08 * g.at(A, 'xin')", chron("A", "#q_sec_head##q_zc_a#。#q_zc_bad#"), pinj(3), pxw(-15),
           chance(0.5, sched("echo_wound", 72, 240, keep=["y0", "m0"])))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")], doc="经脉走岔：心性高的稳住（心性+1、感悟+2），低的受伤折修为（三成留下暗伤，十到三十年后再犯 / 化开）"),
    pm("sec_dunwu", SEC, "0.6 + 0.1 * g.at(A, 'wu')", 24, [
        oc("wu", 1.0, chron("A", "#q_sec_head##q_dw_{maj}#"), wu(4), pxw("5 + 10 * ctx.maj")),
        oc("attr", "0.08 * g.at(A, 'wu')", chron("A", "#q_sec_head##q_dw_{maj}#"), attr("A", "wu", 1), pxw("3 + 7 * ctx.maj"))],
       effects=[setv("maj", "min(3, ctx.maj)")], doc="顿悟：悟性越高越常有；按大境界悟的东西不同"),
    pm("sec_xinmo", SEC + " and ctx.maj >= 1", 0.7, 48, [
        oc("win", "0.4 + 0.12 * g.at(A, 'xin')", iff("B != null", chron("A", "#q_xm_in##q_xm_who##q_xm_win#"), els=[chron("A", "#q_xm_in##q_xm_noone##q_xm_win#")]), attr("A", "xin", 1)),
        oc("lose", "1.0 - 0.06 * g.at(A, 'xin')", iff("B != null", chron("A", "#q_xm_in##q_xm_who##q_xm_lose#"), chance(0.5, sched("echo_xm", 120, 360, keep=["y0", "m0"], cast={"B": "B"})),
           els=[chron("A", "#q_xm_in##q_xm_noone##q_xm_lose#")]),
           pinj(4), pxw(-20), attr("A", "xin", -1))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")],
       roles=[{"name": "B", "optional": True, "where": "g.known(SELF) and (g.gr(g.player(), SELF) >= 10 or g.gr(SELF, g.player()) >= 15 or g.pf(SELF) >= 40)"}],
       doc="心魔：化作结怨或挂念的人；心性定胜负"),
    pm("sec_tide", SEC, 0.8, 36, [oc("ok", 1.0, chron("A", "#q_tide##q_tide_t#"), pxw("6 + 12 * ctx.maj"))], doc="灵脉涨潮，修为+"),
    pm("sec_knock", SEC, 0.9, 40, [
        oc("open", "0.4 + 0.15 * g.pt('善') + 0.05 * g.at(A, 'xin')", chron("A", "#q_sec_head##q_knock##q_knock_open#"), rel("B", "P", f=12), pxw(-10),
           mem("B", "P", "{pn}为我破了关", 12, "恩"), chance(0.4, pitem("{B}为谢她破关相助所赠。"), els=[ling(8)])),
        oc("shut", "0.4 + 0.15 * g.pt('避')", chron("A", "#q_sec_head##q_knock##q_knock_shut#"), rel("B", "P", f=-8), mem("B", "P", "我去叩门，{pn}没开", -8), pxw(8))],
       roles=[{"name": "B", "where": KNOWN + " and g.pf(SELF) >= 10"}], doc="故人叩门：开与不开，看她这些年的性子（善/避）"),
    pm("sec_shouyuan", SEC + " and g.lf(A) > 0.5", 0.6, 120, [
        oc("ok", "0.3 + 0.1 * g.at(A, 'xin')", chron("A", "#q_sec_head##q_sy##q_sy_ok#", sy="=g.sy_left()"), attr("A", "xin", 1)),
        oc("bad", 0.6, chron("A", "#q_sec_head##q_sy##q_sy_bad#", sy="=g.sy_left()"), pxw(-8), attr("A", "xin", -1))], doc="寿元之感"),
    pm("sec_dream", SEC, 0.7, 36, [
        oc("ok", 1.0, chron("A", "#q_sec_head##q_dream##q_dream_t#", yb="=g.yago(int(g.met_m(B)))", bp="=B.place"), rel("P", "B", f=5), rel("B", "P", f=4))],
       roles=[{"name": "B", "where": "g.known(SELF) and SELF.alive and g.pf(SELF) >= 5 and g.now_m() - g.met_m(SELF) >= 60"}], doc="梦回旧事：想起多年前认识的人，托话问候"),
    # ============ 在青庐
    pm("tian", HOME, 1.0, 14, [
        oc("good", "0.6 + 0.08 * g.at(A, 'yun')", chron("A", "#q_tian_{maj}##q_tian_good#"), ling("6 + 4 * ctx.maj")),
        oc("bad", 0.4, chron("A", "#q_tian_{maj}##q_tian_bad#"), ling(-3), attr("A", "xin", 1))], effects=[setv("maj", "min(3, ctx.maj)")], doc="种药"),
    pm("dan", HOME + " and ctx.maj >= 1", 0.8, 18, [
        oc("ok", "0.5 + 0.08 * g.at(A, 'wu')", chron("A", "#q_dan_try##q_dan_ok#"), ling("8 + 5 * ctx.maj"), wu(2)),
        oc("bad", 0.5, chron("A", "#q_dan_try##q_dan_bad#"), pinj(1), ling(-4))], doc="炼丹"),
    pm("fu", HOME, 0.6, 20, [oc("ok", 1.0, chron("A", "#q_fu#"), wu(2), ling(3))], doc="画符"),
    pm("sky", OUT, 0.35, 60, [oc("ok", 1.0, chron("A", "#q_sky##q_sky_t#"), chance("0.04 * g.at(A, 'yun')", attr("A", "yun", 1), els=[wu(3)]))], doc="天象异变"),
    pm("dyn", OUT + " and g.age(A) > 40", 0.35, 120, [oc("ok", 1.0, chron("A", "#q_dyn##q_dyn_t#"), attr("A", "xin", 1))], doc="世俗王朝更替（她看在眼里，心性+1）"),
    pm("seed", HOME, 0.4, 9999, [oc("ok", 1.0, setv("tree", "'#q_tree#'"), chron("A", "在青庐后院种了一株{tree}苗。"), {"op": "mark", "key": "tree"}, attr("A", "xin", 1),
        sched("echo_tree", 240, 480, keep=["tree", "y0"]))], effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")], doc="伏笔：种树（二三十年后成材）"),
    pm("wine", HOME, 0.3, 9999, [oc("ok", 1.0, chron("A", "#q_wine#"), ling(-2), sched("echo_wine", 120, 300, keep=["y0", "m0"]))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")], doc="伏笔：埋酒"),
    pm("dao", OUT + " and g.partner(A) != null", 1.0, 18, [
        oc("sweet", 1.0, chron("A", "#q_dao#", bp="=B.place"), rel("B", "P", f=5), rel("P", "B", f=5), attr("A", "xin", 1)),
        oc("fight", "0.2 + 0.1 * int(g.trt(B, '多疑'))", chron("A", "#q_dao_bad#"), rel("B", "P", f=-4), rel("P", "B", f=-3))],
       roles=[{"name": "B", "fixed": "g.partner(A)"}], doc="道侣长线"),
    pm("qi", OUT + " and g.eqn('fabao') != ''", 0.6, 30, [oc("ok", 1.0, chron("A", "#q_qi##q_qi_t#"), pxw("6 + 4 * ctx.maj"), wu(1),
           chance(0.5, sched("echo_qi", 72, 200, keep=["y0", "m0", "it"])))],
       effects=[setv("it", "g.eqn('fabao')"), setv("y0", "g.cy()"), setv("m0", "g.now_m()")], doc="温养法宝（器物锚点）"),
    pm("jiang", OUT + " and ctx.maj >= 1", "0.3 + 0.3 * ctx.maj", 30, [
        oc("ok", 1.0, chron("A", "#q_jiang_{maj}#", bp="=B.place"), {"op": "xp", "who": "B", "frac": 0.2}, rel("B", "P", f=8), mem("B", "P", "得{pn}指点", 6, "教"), attr("A", "mei", 1),
           chance(0.7, sched("echo_jiang", 96, 240, keep=["y0", "m0"], cast={"B": "B"})))],
       effects=[setv("maj", "min(3, ctx.maj)"), setv("y0", "g.cy()"), setv("m0", "g.now_m()")], roles=[{"name": "B", "where": KNOWN + " and g.lv(SELF) + 3 <= g.plv()"}], doc="指点晚辈（金丹后开坛讲道）"),
    pm("lun", OUT, 0.9, 16, [
        oc("good", "0.6 + 0.05 * g.at(A, 'wu') + 0.05 * g.at(A, 'mei')", chron("A", "#q_lun##q_lun_good#", bp="=B.place"), wu(3), rel("B", "P", f=6), rel("P", "B", f=4), {"op": "xp", "who": "B", "frac": 0.1}),
        oc("bad", "0.25 + 0.2 * int(g.trt(B, '傲气'))", chron("A", "#q_lun##q_lun_bad#", bp="=B.place"), rel("B", "P", f=-5), attr("A", "xin", 1))],
       roles=[{"name": "B", "where": KNOWN + " and g.pf(SELF) >= 0 and abs(g.lv(SELF) - g.plv()) <= 4"}], doc="访友论道"),
    pm("xun", OUT, 1.6, 24, [
        oc("item", "0.5 + 0.3 * int(g.gear_n(B) > 0)", chron("A", "#q_xun##q_xun_t#", yb="=g.yago(int(g.met_m(B)))", bp="=B.place"), {"op": "give_item", "a": "B", "b": "P", "h": "{B}寿尽前留给{pn}。"},
           rel("B", "P", f=6), attr("A", "xin", 1)),
        oc("tuo", 0.5, setv("k", "g.kid(B) if g.kids(B) > 0 else '后人'"), chron("A", "#q_xun##q_tuo#", bp="=B.place"), rel("B", "P", f=10), mem("B", "P", "托付了{pn}一件事", 10, "托"),
           sched("echo_tuo", 60, 180, keep=["k", "m0"], cast={"B": "B"})),
        oc("plain", 0.4, chron("A", "#q_xun##q_xun_t#", yb="=g.yago(int(g.met_m(B)))", bp="=B.place"), rel("B", "P", f=6), attr("A", "xin", 1))],
       effects=[setv("m0", "g.now_m()")], roles=[{"name": "B", "where": "g.known(SELF) and SELF.alive and g.pf(SELF) >= 10 and g.lf(SELF) > 0.85"}], doc="寿元将尽的故人：留物 / 托付（伏笔）"),
    # ============ 在外 / 坊市
    pm("fang", OUT, 0.9, 20, [
        oc("cheat", "0.6 - 0.04 * g.at(A, 'wu')", chron("A", "#q_fang_cheat#"), ling("-6 - 2 * ctx.maj"), {"op": "ptag", "k": "利", "d": 1}),
        oc("luck", "0.15 + 0.05 * g.at(A, 'yun')", pitem("{pn}在坊市旧货摊上淘得。"), chron("A", "#q_fang_luck#")),
        oc("help", "0.3 + 0.1 * g.pt('善')", chron("A", "#q_fang_help#"), {"op": "ptag", "k": "善", "d": 1}, attr("A", "mei", 1), ling(-2))], doc="坊市风波"),
    pm("beast", ROAD, 1.4, 10, [
        oc("w", "0.5 + 0.1 * g.at(A, 'gen') + 0.1 * ctx.maj", chron("A", "#q_road_beast##q_beast_w#"), ling("5 + 5 * ctx.maj"), pxw(5)),
        oc("l", "0.6 - 0.04 * g.at(A, 'gen')", chron("A", "#q_road_beast##q_beast_l#"), pinj(3), ling(-3)),
        oc("avoid", "0.15 + 0.15 * g.pt('避')", chron("A", "#q_road_beast##q_beast_avoid#"), attr("A", "xin", 1))], doc="山道妖兽（根骨定胜负）"),
    pm("save", OUT, 0.7, 60, [
        oc("ok", 1.0, chron("A", "#q_save##q_save_x#", bp="=g.near()"), {"op": "pmeet", "b": "B"}, rel("B", "P", f=25), mem("B", "P", "{pn}在{p0}救过我一命", 20, "救"),
           {"op": "ptag", "k": "善", "d": 1}, sched("echo_save", 60, 240, keep=["y0", "m0", "p0"], cast={"B": "B"}))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()"), setv("p0", "g.near()")],
       roles=[{"name": "B", "where": "SELF.alive and not g.known(SELF) and g.lv(SELF) < g.plv() and not g.busy(SELF)"}], doc="伏笔：救人（五到二十年后来还情）"),
    pm("feud", OUT, 0.6, 72, [
        oc("ok", 1.0, chron("A", "#q_feud#", bp="=g.near()"), {"op": "pmeet", "b": "B"}, rel("B", "P", gg=20), mem("B", "P", "{pn}在{p0}夺了我的{herb}", -15, "夺"),
           wu(4), ling(6), {"op": "ptag", "k": "利", "d": 1}, sched("echo_feud", 60, 200, keep=["y0", "m0", "p0", "herb"], cast={"B": "B"}))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()"), setv("p0", "g.near()"), setv("herb", "'#q_herb#'")],
       roles=[{"name": "B", "where": "SELF.alive and not g.bonded(SELF, g.player()) and not g.busy(SELF) and g.maj(SELF) <= ctx.maj and g.lv(SELF) <= g.plv() + 1"}],
       doc="伏笔：结怨（只跟境界相当或更低的人争；五到十几年后对方回来算账）"),
    # ============ 叩关
    pm("gate", OUT + " and g.gate()", 2.0, 8, [
        oc("tip", 0.5, chron("A", "#q_gate##q_gate_tip#"), wu(3), pxw(10)),
        oc("force_ok", "0.2 + 0.05 * g.at(A, 'gen')", chron("A", "#q_gate##q_gate_force##q_gate_force_ok#"), attr("A", "gen", 1)),
        oc("force_bad", "0.4 - 0.03 * g.at(A, 'xin')", chron("A", "#q_gate##q_gate_force##q_gate_force_bad#"), pinj(3), life("A", -1)),
        oc("calm", "0.2 + 0.05 * g.at(A, 'xin')", chron("A", "#q_gate#她不急，每日只把根基再磨一遍。"), attr("A", "xin", 1))], doc="叩关/瓶颈"),
]
# ---------------------------------------------------------------- v0.15.3：更多伏笔（借、约、供奉、收徒）与金丹 / 元婴专属的事
CHRON += [
    pm("lend", OUT + " and g.ls() >= 20", 0.5, 120, [
        oc("ok", 1.0, chron("A", "#q_lend#", bp="=B.place"), ling(-12), rel("B", "P", f=8), mem("B", "P", "{pn}在我落魄时借过我灵石", 10, "恩"),
           sched("echo_lend", 96, 300, keep=["y0", "m0"], cast={"B": "B"}))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")], roles=[{"name": "B", "where": KNOWN + " and g.pf(SELF) >= 10 and g.lv(SELF) <= g.plv() and not g.bonded(SELF, g.player())"}],
       doc="伏笔：借灵石给落魄的熟人（八到二十五年后还）"),
    pm("yue", OUT, 0.5, 180, [
        oc("ok", 1.0, chron("A", "#q_yue#", bp="=B.place"), rel("B", "P", f=6), rel("P", "B", f=6), mem("B", "P", "与{pn}约在{bp}再见", 8, "约", bp="=B.place"),
           sched("echo_yue", 120, 360, keep=["y0", "m0", "bp"], cast={"B": "B"}))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")] + [setv("bp", "B.place")], roles=[{"name": "B", "where": KNOWN + " and g.pf(SELF) >= 25"}],
       doc="伏笔：与故人约期（十到三十年后赴约，人在不在另说）"),
    pm("gongfeng", OUT + " and ctx.maj >= 2", 0.5, 9999, [
        oc("yes", "0.5 + 0.1 * g.at(A, 'mei')", chron("A", "#q_gf#应下了，领了一块客卿玉牌。"), ling(60), {"op": "ptag", "k": "利", "d": 1},
           sched("echo_gf", 72, 240, keep=["y0", "m0", "sect"])),
        oc("no", "0.4 + 0.15 * g.pt('避')", chron("A", "#q_gf#她把拜帖原样退了回去。"), attr("A", "xin", 1))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")] + [setv("sect", "'#q_sect#'")], doc="金丹后：宗门请她做供奉（应下的，十到三十年后宗门有难来请）"),
    pm("shoutu", OUT + " and ctx.maj >= 2", 0.5, 240, [
        oc("yes", "0.5 + 0.2 * g.pt('善')", chron("A", "#q_tu##q_tu_yes#"), rel("B", "P", f=20), mem("B", "P", "{pn}收留点拨之恩", 18, "教"), {"op": "xp", "who": "B", "frac": 0.3},
           attr("A", "mei", 1), sched("echo_tu", 72, 200, keep=["y0", "m0"], cast={"B": "B"})),
        oc("no", 0.5, chron("A", "#q_tu##q_tu_no#"), rel("B", "P", f=-4), attr("A", "xin", 1))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")], roles=[{"name": "B", "where": KNOWN + " and g.lv(SELF) + 4 <= g.plv() and g.pf(SELF) >= 15"}],
       doc="金丹后：有人在青庐外跪求指点（收下的，十到二十五年后回来）"),
    pm("sec_danhuo", SEC + " and ctx.maj == 2", 0.5, 96, [
        oc("ok", "0.5 + 0.1 * g.at(A, 'xin')", chron("A", "#q_sec_head##q_danhuo##q_danhuo_ok#"), wu(4), pxw(30)),
        oc("bad", "0.7 - 0.05 * g.at(A, 'xin')", chron("A", "#q_sec_head##q_danhuo##q_danhuo_bad#"), pinj(4), pxw(-30), life("A", -1))],
       doc="金丹：丹火反噬（心性定）"),
    pm("sec_shenyou", SEC + " and ctx.maj >= 3", 0.9, 36, [
        oc("ok", 1.0, chron("A", "#q_sec_head##q_shenyou#"), wu(5), pxw(40)),
        oc("lost", "0.3 - 0.02 * g.at(A, 'xin')", chron("A", "#q_sec_head#元神出窍，神游到半途，被一阵罡风吹散了方向，三日才回到肉身。"), pinj(3), attr("A", "xin", 1))],
       doc="元婴：元神出窍神游"),
    pm("yuanying_old", OUT + " and ctx.maj >= 3", 0.6, 120, [
        oc("ok", 1.0, chron("A", "#q_yy_old#"), attr("A", "xin", 1), wu(3))], doc="元婴：故人凋零"),
]
# ---------------------------------------------------------------- v0.15.5：更多伏笔（残图、丹恩、故里、心魔旧人）与金丹 / 元婴专属
CHRON += [
    pm("map", OUT + " and ctx.maj <= 1", "0.3 + 0.05 * g.at(A, 'yun')", 9999, [
        oc("ok", 1.0, chron("A", "#q_map#", bp="=g.near()"), {"op": "mark", "key": "map"}, wu(1), sched("echo_map", 120, 360, keep=["y0", "m0", "bp"]))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()"), setv("bp", "g.near()")], doc="伏笔：半张残图（十到三十年后，悟性够才拼得上）"),
    pm("dan_en", OUT + " and g.pinjd()", 1.0, 240, [
        oc("ok", 1.0, chron("A", "#q_dan_en#"), {"op": "pinj", "days": -2}, rel("P", "B", f=12), mem("P", "B", "{B}在我受伤时送过丹", 12, "恩"),
           sched("echo_en", 96, 300, keep=["y0", "m0"], cast={"B": "B"}))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")], roles=[{"name": "B", "where": KNOWN + " and g.lv(SELF) > g.plv() and g.pf(SELF) >= 10"}],
       doc="伏笔：受伤时得人送丹（八到二十五年后她去还）"),
    pm("home", OUT + " and ctx.maj >= 1", 0.3, 9999, [oc("ok", 1.0, chron("A", "#q_home#"), attr("A", "xin", 1), sched("echo_home", 360, 600, keep=["y0", "m0"]))],
       effects=[setv("y0", "g.cy()"), setv("m0", "g.now_m()")], doc="伏笔：回凡间故里（三五十年后，那孩子已老）"),
    pm("benming", HOME + " and ctx.maj >= 2 and g.eqn('fabao') != ''", 0.6, 9999, [
        oc("ok", "0.5 + 0.08 * g.at(A, 'wu')", chron("A", "#q_benming##q_benming_ok#"), pxw(40), wu(4), {"op": "mark", "key": "benming"}),
        oc("bad", 0.4, chron("A", "#q_benming##q_benming_bad#"), pinj(3), pxw(-20), attr("A", "xin", 1))],
       effects=[setv("it", "g.eqn('fabao')")], doc="金丹：炼本命法宝（器物锚点；悟性定成败）"),
    pm("guanjie", OUT + " and ctx.maj >= 2", 0.5, 120, [
        oc("ok", 1.0, chron("A", "#q_guanjie##q_guanjie_t#", bp="=B.place"), wu(5), pxw(20), rel("P", "B", f=4))],
       roles=[{"name": "B", "where": "g.known(SELF) and SELF.alive and g.maj(SELF) >= 2 and g.lv(SELF) >= g.plv()"}], doc="金丹：观人渡劫"),
    pm("xuming", OUT + " and ctx.maj >= 3", 1.0, 240, [
        oc("ok", 1.0, chron("A", "#q_xuming##q_xuming_t#"), life("B", 10), life("A", -3), rel("B", "P", f=20), mem("B", "P", "{pn}替我续了命", 20, "恩"))],
       roles=[{"name": "B", "where": KNOWN + " and g.lf(SELF) > 0.9 and g.pf(SELF) >= 30"}], doc="元婴：替将尽的故人续命（她折寿）"),
]
# ---------------------------------------------------------------- 回响（chain）
CHRON += [
    {"id": "echo_save", "trigger": "chain", "in": ["B"], "when": "B.alive", "doc": "救人的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))"), setv("br", "g.realm(B)"), setv("it", "''")],
     "outcomes": [
        oc("item", "0.5 + 0.3 * int(g.gear_n(B) > 0)", {"op": "give_item", "a": "B", "b": "P", "h": "{B}为报{y0}救命之恩所赠。"},
           chron("P", "#q_echo_save#“这份情，我记了{yago}。”"), iff("ctx.it != ''", {"op": "pchron", "text": "{B}留下一件{it}，说是当年的谢礼。"}), rel("P", "B", f=10)),
        oc("ling", 0.6, chron("P", "#q_echo_save##q_echo_save_t#"), ling("10 + 3 * g.maj(B) * 5"), rel("P", "B", f=10), attr("P", "xin", 1))]},
    {"id": "echo_feud", "trigger": "chain", "in": ["B"], "when": "B.alive and g.gr(B, g.player()) >= 10", "doc": "结怨的回响（境界高出她一个大境界：她只能低头赔礼）",
     "effects": [setv("yago", "g.yago(int(ctx.m0))"), setv("br", "g.realm(B)")],
     "outcomes": [
        oc("bow", 1.0, chron("P", "#q_echo_feud##q_echo_feud_bow#"), ling(-15), rel("B", "P", gg=-15), attr("P", "xin", 1), when="g.maj(B) > g.maj(g.player()) or g.pt('善') >= 3", first=True),
        oc("w", 1.0, chron("P", "#q_echo_feud##q_echo_feud_w#"), ninj("B", 6), rel("B", "P", gg=10), wu(3), when="g.plv() + se.roll(0, 4) >= g.lv(B) + se.roll(0, 4)", first=True),
        oc("l", 1.0, chron("P", "#q_echo_feud##q_echo_feud_l#"), pinj(3), ling(-12), rel("B", "P", gg=-10), first=True)]},
    {"id": "echo_tree", "trigger": "chain", "doc": "种树的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))"), setv("it", "''")],
     "outcomes": [oc("wood", 0.5, pitem("{pn}用{y0}亲手种的{tree}削成。", "fabao", 1), chron("P", "#q_echo_tree#她砍下一段老枝，削成了一件{it}。")),
                  oc("sit", 0.5, chron("P", "#q_echo_tree##q_echo_tree_t#"), pxw(20), attr("P", "xin", 1))]},
    {"id": "echo_wine", "trigger": "chain", "doc": "埋酒的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))")],
     "roles": [{"name": "B", "optional": True, "where": "g.known(SELF) and SELF.alive and g.pf(SELF) >= 25"}],
     "outcomes": [oc("friend", "2.0 * int(B != null)", chron("P", "#q_echo_wine#请{B}来喝。两人喝到半夜，说起了许多已经不在的人。"), rel("B", "P", f=10), rel("P", "B", f=6), attr("P", "xin", 1)),
                  oc("alone", 1.0, chron("P", "#q_echo_wine#一个人喝了半坛，剩下半坛又埋了回去。"), attr("P", "xin", 1), wu(2))]},
    {"id": "echo_tuo", "trigger": "chain", "in": ["B"], "dead_ok": ["B"], "doc": "托付的回响（故人已逝）",
     "effects": [setv("yago", "g.yago(int(ctx.m0))")],
     "outcomes": [oc("ok", 1.0, iff("not B.alive", chron("P", "#q_tuo_echo##q_tuo_echo_t#"), attr("P", "xin", 1), {"op": "ptag", "k": "善", "d": 1},
                                    els=[chron("P", "{B}的身子竟又撑了{yago}，托的事还没到时候。她去看了一回。"), rel("B", "P", f=6)]))]},
]
CHRON += [
    {"id": "echo_lend", "trigger": "chain", "in": ["B"], "dead_ok": ["B"], "doc": "借灵石的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))"), setv("br", "g.realm(B)"), setv("p0", "B.place")],
     "outcomes": [
        oc("rich", 1.0, chron("P", "#q_echo_lend#{B}如今已是{br}，还的是当年的三倍。"), ling(36), rel("P", "B", f=8), when="B.alive and g.maj(B) >= 1", first=True),
        oc("even", 1.0, chron("P", "#q_echo_lend#一块不少，还多了一包茶叶。"), ling(14), rel("P", "B", f=6), when="B.alive", first=True),
        oc("dead", 1.0, chron("P", "#q_echo_lend_dead#"), attr("P", "xin", 1), first=True)]},
    {"id": "echo_yue", "trigger": "chain", "in": ["B"], "dead_ok": ["B"], "doc": "约期的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))"), setv("br", "g.realm(B)")],
     "outcomes": [
        oc("met", 1.0, chron("P", "#q_echo_yue#{B}已经等在那里了，如今是{br}。两人喝了一夜，各自说了这些年的事。"), rel("P", "B", f=10), rel("B", "P", f=10), wu(3), attr("P", "xin", 1), when="B.alive", first=True),
        oc("gone", 1.0, chron("P", "#q_echo_yue#等了三日，{B}没有来。后来才听说，{B}早已不在了。"), attr("P", "xin", 1), first=True)]},
    {"id": "echo_wound", "trigger": "chain", "doc": "暗伤的回响（根骨定化开还是复发）",
     "effects": [setv("yago", "g.yago(int(ctx.m0))")],
     "outcomes": [
        oc("heal", "0.2 + 0.08 * g.at(g.player(), 'gen')", chron("P", "#q_echo_wound#这回被她一口气化开了，经脉反倒比从前宽了一分。"), attr("P", "gen", 1), pxw(15)),
        oc("flare", "0.8 - 0.05 * g.at(g.player(), 'gen')", chron("P", "#q_echo_wound#今年又犯了，疼了一个月。"), pinj(2), attr("P", "xin", 1))]},
    {"id": "echo_jiang", "trigger": "chain", "in": ["B"], "when": "B.alive", "doc": "指点晚辈的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))"), setv("br", "g.realm(B)")],
     "outcomes": [
        oc("over", 1.0, chron("P", "#q_echo_jiang#如今已是{br}，来青庐坐了半日，反过来替她解了一处惑。"), wu(5), rel("P", "B", f=8), when="g.lv(B) >= g.plv()", first=True),
        oc("gift", 1.0, chron("P", "#q_echo_jiang#如今已是{br}，托人送来一份谢礼，说那一回少走了十年弯路。"), ling("8 + 6 * g.maj(B)"), rel("P", "B", f=6), first=True)]},
    {"id": "echo_qi", "trigger": "chain", "doc": "温养法宝的回响（器物还在不在身上）",
     "effects": [setv("yago", "g.yago(int(ctx.m0))")],
     "outcomes": [
        oc("wake", 1.0, chron("P", "#q_echo_qi#今年夜里自己亮了一回——器灵醒了。"), attr("P", "yun", 1), pxw(20), when="g.eqn('fabao') == ctx.it", first=True),
        oc("miss", 1.0, chron("P", "#q_echo_qi_miss#"), attr("P", "xin", 1), first=True)]},
    {"id": "echo_gf", "trigger": "chain", "doc": "供奉的回响：宗门有难",
     "effects": [setv("yago", "g.yago(int(ctx.m0))")],
     "outcomes": [
        oc("go", "0.6 + 0.1 * g.pt('善')", chron("P", "#q_echo_gf#她去了，守了七日山门，带着伤回来。"), pinj(3), ling(40), {"op": "ptag", "k": "善", "d": 1}),
        oc("no", "0.3 + 0.15 * g.pt('避')", chron("P", "#q_echo_gf#她把玉牌还了回去，没有去。"), {"op": "ptag", "k": "避", "d": 1}, ling(-20))]},
    {"id": "echo_tu", "trigger": "chain", "in": ["B"], "when": "B.alive", "doc": "收徒的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))"), setv("br", "g.realm(B)")],
     "outcomes": [
        oc("back", 1.0, chron("P", "#q_echo_tu#如今已是{br}，回来给她磕了个头，留下一件东西。"), {"op": "give_item", "a": "B", "b": "P", "h": "{B}回青庐谢师时所赠。"}, rel("P", "B", f=10), when="g.gear_n(B) > 0", first=True),
        oc("visit", 1.0, chron("P", "#q_echo_tu#如今已是{br}，回来替她把药圃翻了一遍土。"), ling(10), rel("P", "B", f=8), attr("P", "xin", 1), first=True)]},
]
CHRON += [
    {"id": "echo_map", "trigger": "chain", "doc": "残图的回响（悟性定）",
     "effects": [setv("yago", "g.yago(int(ctx.m0))")],
     "outcomes": [
        oc("ok", "0.2 + 0.08 * g.at(g.player(), 'wu')", chron("P", "#q_echo_map##q_echo_map_ok#"), pitem("{pn}凭{y0}收的半张残图寻得。"), wu(3)),
        oc("no", 0.6, chron("P", "#q_echo_map##q_echo_map_no#"), attr("P", "xin", 1))]},
    {"id": "echo_en", "trigger": "chain", "in": ["B"], "when": "B.alive", "doc": "丹恩的回响：她去还",
     "effects": [setv("yago", "g.yago(int(ctx.m0))")],
     "outcomes": [oc("ok", 1.0, chron("P", "#q_echo_en##q_echo_en_t#"), ling(-15), life("B", 3), rel("B", "P", f=15), rel("P", "B", f=5), {"op": "ptag", "k": "善", "d": 1})]},
    {"id": "echo_home", "trigger": "chain", "doc": "故里的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))")],
     "outcomes": [oc("ok", 1.0, chron("P", "#q_echo_home##q_echo_home_t#"), attr("P", "xin", 1), ling(-3))]},
    {"id": "echo_xm", "trigger": "chain", "in": ["B"], "dead_ok": ["B"], "doc": "心魔旧人的回响",
     "effects": [setv("yago", "g.yago(int(ctx.m0))"), setv("br", "g.realm(B)")],
     "outcomes": [
        oc("meet", 1.0, chron("P", "#q_xm_echo#今年真在坊市遇上了，{B}已是{br}。两人站着说了几句，那口气就散了。"), rel("P", "B", f=8, gg=-10), attr("P", "xin", 1), when="B.alive", first=True),
        oc("gone", 1.0, chron("P", "#q_xm_echo#如今人已不在。她在灯下坐了一夜，心里那块石头放下了。"), attr("P", "xin", 2), first=True)]},
]
# v0.15.3 修：回响（chain）里写 chron("P", …) 的，P 不在 cast 里 → 引擎找不到人，整条没写进履历（效果照扣）。
# 给每条回响补一个固定角色 P = 她。
for _s in CHRON:
    if _s.get("trigger") == "chain" and not any(r.get("name") == "P" for r in _s.get("roles", [])):
        _s["roles"] = [{"name": "P", "fixed": "g.player()"}] + _s.get("roles", [])
# ---------------------------------------------------------------- NPC：资质随经历起落（他们的生平也挂机制）
g("n_ku", "在{p}的瀑布下站了一个月桩。", "每日负石上山，一年没断。", "在{p}跟一头熊较了半年的力气。")
g("n_du", "把一部经读到第九遍，读出了前人没注的一句。", "在{p}的藏经阁里抄了半年的书。", "替师门整理残卷，看出一处缺漏。")
g("n_xin_d", "为一件小事动了真火，几个月没静下心来。", "听了一句闲话，记在心里，夜里翻来覆去。", "眼红同门破境，打坐时总走神。")
g("n_xin_u", "在{p}看了一夜的雪，回来后性子沉了许多。", "替一个凡人送终，回来后对什么都淡了些。", "与人赌气输了，反倒笑了，心里松了。")
g("n_yun", "在{p}躲雨时，屋檐下捡到一块灵玉。", "被一只灵雀引着走了半日，找到一眼小泉。", "下山时摔了一跤，正摔在一株百年黄精旁边。")
g("n_mei", "在{p}替人解了围，名声传开了。", "在{p}的诗会上作了一首诗，被人传抄。")
CHRON += [
    {"id": "n_attr", "trigger": "actor", "weight": 0.7, "when": "not g.busy(A)", "actor_cooldown": 36, "doc": "NPC 资质起落",
     "outcomes": [
        oc("ku", "0.5 + 0.5 * int(g.trt(A, '嗜战'))", chron("A", "#n_ku#"), attr("A", "gen", 1)),
        oc("du", "0.5 + 0.5 * int(g.trt(A, '好奇'))", chron("A", "#n_du#"), attr("A", "wu", 1)),
        oc("xd", "0.3 + 0.5 * int(g.trt(A, '多疑')) + 0.4 * int(g.trt(A, '记仇'))", chron("A", "#n_xin_d#"), attr("A", "xin", -1)),
        oc("xu", "0.3 + 0.5 * int(g.trt(A, '淡泊'))", chron("A", "#n_xin_u#"), attr("A", "xin", 1)),
        oc("yun", 0.3, chron("A", "#n_yun#"), attr("A", "yun", 1), xpn("A", 0.1)),
        oc("mei", "0.2 + 0.4 * int(g.trt(A, '侠义'))", chron("A", "#n_mei#"), attr("A", "mei", 1))]},
    {"id": "n_old_life", "trigger": "actor", "weight": "2.0 * int(g.lf(A) > 0.8)", "actor_cooldown": 120, "when": "g.lv(A) >= 3", "doc": "老修士续命 / 认命",
     "outcomes": [oc("xu", "0.3 + 0.05 * g.at(A, 'yun')", chron("A", "寻到一株续命的草，吃了，多活了几年。"), life("A", 5)),
                  oc("ren", 0.7, chron("A", "开始把身后事一件件安排好。"), attr("A", "xin", 1))]},
]

# ---------------------------------------------------------------- 旧包里“纯文字”的结果补上机制（v0.15 审计）
def _patch(storylists):
    by = {}
    for lst in storylists:
        for s in lst:
            by[s["id"]] = s
    def add(sid, oid, *ops):
        s = by[sid]
        if oid is None:
            s["effects"] = s.get("effects", []) + list(ops)
            return
        for o in s.get("outcomes", []):
            if o.get("id") == oid:
                o["effects"] = o.get("effects", []) + list(ops)
                return
        for c in s.get("choices", []):
            if c.get("id") == oid.split("/")[0]:
                for o in c.get("outcomes", []):
                    if o.get("id") == oid.split("/")[1]:
                        o["effects"] = o.get("effects", []) + list(ops)
                        return
        raise KeyError(sid + "/" + oid)
    add("youli", "plain", chance(0.5, xpn("A", 0.05), els=[chance("0.04 * g.at(A, 'yun')", attr("A", "yun", 1), els=[xpn("A", 0.03)])]))
    add("like", None, chance(0.25, attr("A", "xin", 1), els=[xpn("A", 0.03)]))
    add("sectday", None, xpn("A", 0.04))
    add("xia", None, chance(0.3, attr("A", "mei", 1), els=[xpn("A", 0.03)]))
    add("bad", None, chance(0.4, attr("A", "xin", -1), els=[xpn("A", 0.04)]))
    add("kid_month", None, attr("A", "xin", 1))
    add("kid_day", None, chance(0.3, attr("A", "xin", 1), els=[xpn("A", 0.02)]))
    add("old", None, attr("A", "gen", -1))
    add("close_out", "meh", xpn("A", 0.15))
    add("dabi_x", "top", xpn("X", 0.1))
    add("dabi_x", "mid", xpn("X", 0.05))
    add("mijing_x", "none", xpn("X", 0.05))
    add("xunqi", "none", xpn("A", 0.04))
    add("mourn_partner", "plain", attr("B", "xin", -1))
    add("mourn_partner", "xinmo", attr("B", "xin", -1))
    add("吊唁", "no/ok", fav(-2, "她来了，却没进门", -2))
    # 破境 / 走火 / 飞升 / 新人：境界、伤在 world.tick 里先改了（效果先挂起，挂到这一条上）
    for sid in ("break_big", "break_small", "break_fail", "ascend", "newcomer"):
        by[sid]["host_fx"] = True
    # Gemini v7 P1：筑基不渡雷劫；雷劫只在结丹（三九小劫）与元婴（六九雷劫）
    bb = by["break_big"]
    bb["effects"] = [setv("bm", "g.maj(A)") if e.get("op") == "x" else e for e in bb["effects"]]
    bb["effects"].insert(0, setv("bm", "min(4, g.maj(A))"))
    for e in bb["effects"]:
        if e.get("op") == "chron" and "#d_break_big#" in e.get("text", ""):
            e["text"] = e["text"].replace("#d_break_big#", "#d_break_big_{bm}#")
    bf = by["break_fail"]
    bf["effects"].insert(0, setv("bm", "min(4, g.maj(A) + 1)"))
    for e in bf["effects"]:
        if e.get("op") == "chron" and "#d_break_fail#" in e.get("text", ""):
            e["text"] = e["text"].replace("#d_break_fail#", "#d_break_fail_{bm}#")
    # 争宝：差一个大境界以上，弱的一方不是“没争过”，是被威压逼退；强抢的伤得重
    zb = by["meet_zhengbao"]
    zb["weight"] = "(%s) * (1.0 - 0.6 * int(abs(g.maj(A) - g.maj(B)) >= 1))" % zb["weight"]
    zb["outcomes"].insert(0, {"id": "weiya_a", "first": True, "when": "g.maj(A) - g.maj(B) >= 1", "effects": [
        chron("A", "#v_weiya_w#", o="B"), chron("B", "#v_weiya_l#", o="A"), rel("B", "A", gg=6), attr("B", "xin", 1)]})
    zb["outcomes"].insert(1, {"id": "weiya_b", "first": True, "when": "g.maj(B) - g.maj(A) >= 1", "effects": [
        chron("B", "#v_weiya_w#", o="A"), chron("A", "#v_weiya_l#", o="B"), rel("A", "B", gg=6), attr("A", "xin", 1)]})

g("v_weiya_w", "在{p}看中一样东西，{o}也在。袖袍一拂，东西便到了手，{o}没敢出声。", "在{p}与{o}同时看中一株灵草，只看了{o}一眼，{o}便退开了。")
g("v_weiya_l", "在{p}遇上{o}，那股威压压得喘不过气，只得低头退开，眼看东西归了对方。", "在{p}与{o}撞上，境界差得太远，没敢动手，退了。")
g("d_break_big_1", "灵气化液，百脉俱通，入{r}。", "道基初成，入{r}。那日{p}的泉水涨了三寸。", "在{p}引气化液，周身灵气倒卷，入{r}。", "闭关多日，道基铸成，入{r}。")
g("d_break_big_2", "渡过三九小劫，丹成，入{r}。", "雷劫劈了二十七道，金丹成，入{r}。劫云散时，天边挂了一道虹。", "在{p}结丹，入{r}。周身灵气倒卷，惊起一山的鸟。")
g("d_break_big_3", "渡六九雷劫，碎丹成婴，入{r}。", "劫云压了三日，元婴成，入{r}。", "在{p}碎丹成婴，入{r}。同门来贺，摆了一桌素酒。")
g("d_break_big_4", "渡九九天劫，入{r}。", "入{r}。那日{p}方圆百里的灵气都朝一处涌。")
g("d_break_big_0", "破境，入{r}。")
g("d_break_fail_1", "冲击筑基不成，灵气没能化液，经脉受损。", "冲关时心神一乱，道基没铸成，咳了半盆血。", "冲击筑基不成，闭门养伤。")
g("d_break_fail_2", "冲击金丹不成，丹胚碎了，伤了根基。", "三九小劫劈到第二十道时没撑住，金丹没成。", "结丹不成，闭门养伤。")
g("d_break_fail_3", "碎丹成婴时功亏一篑，元气大伤。", "六九雷劫劈落第四十道时没撑住，元婴没成。", "冲击元婴不成，闭门养伤。")
g("d_break_fail_4", "冲击化神不成，神识受损。", "天劫劈到一半，没能撑住。")
g("d_break_fail_0", "冲关不成，闭门养伤。")
