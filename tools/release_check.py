# 玩家版（release 导出）点一遍：标题 → 新游戏 → 院子 → 后山游历（碰上奇遇就选）→ 回家 → 生平 → 行囊 → 江湖 → 静室闭关一年
# 只用玩家版也有的只读钩子 window.qinglu_btns（屏上按钮文字与位置）与 window.qinglu_state；不用调试钩子。
# 桌面 Chrome 无头（swiftshader，模拟触控），不是真机。
# 用法：python3 tools/release_check.py <URL> <截图前缀> [宽 高] [旧档.json]
# 新游戏这一趟走完，再开一个干净页签读 tests/fixtures/save_zhuji_v016.json（tools/make_zhuji_save.gd 生成的筑基档）：
# 静室里点服丹闭关开关、青庐营建卡片 → 门下 → 指点后辈、行囊里看穿道袍带外袍的立绘、去坊市点差事榜接一单代炼、货郎以物易物。
# 给了旧档（{"rev":..,"state":{..}}，如 tests/fixtures/save_v2_live_v0121_day36.json）就改走“读旧档”：
# 开页前写进 localStorage → 标题页点「继续」→ 查读进来的日子没变、存回去是 v3、旧档没被清空 → 各页签 → 闭关十年。
import json, os, sys, time
from playwright.sync_api import sync_playwright
url, pre = sys.argv[1], sys.argv[2]
W, H = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (390, 844)
OLD = json.load(open(sys.argv[5])) if len(sys.argv) > 5 else None
out = 'build/shots'
ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
NAV = {'青庐', '历练', '行囊', '江湖', '生平'}
res = {'steps': [], 'errors': []}
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True, args=ARGS)
    c = b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=2, has_touch=True, is_mobile=True)
    pg = c.new_page()
    pg.on('console', lambda m: res['errors'].append(m.text) if m.type == 'error' else None)
    pg.on('pageerror', lambda e: res['errors'].append('pageerror: ' + str(e)))
    if OLD is not None:
        c.add_init_script('if(!sessionStorage.getItem("qc_seeded")){localStorage.setItem("qinglu_v6_slot1",%s);sessionStorage.setItem("qc_seeded","1");}' % json.dumps(json.dumps(OLD, ensure_ascii=False)))
    t0 = time.time()
    pg.goto(url)
    pg.wait_for_function('window.qinglu_btns !== undefined && window.qinglu_state !== undefined', timeout=120000)
    res['boot_s'] = round(time.time() - t0, 1)
    res['has_dev_hook'] = pg.evaluate('typeof window.qinglu_dev !== "undefined"')
    pg.wait_for_timeout(1500)
    def btns():
        d = json.loads(pg.evaluate('(window.qinglu_btns(), window.qinglu_btns_out)'))
        sx = pg.evaluate('window.innerWidth') / d['w']; sy = pg.evaluate('window.innerHeight') / d['h']
        return [(t.replace('● ', ''), x * sx, y * sy) for t, x, y in d['b']]
    def labels():
        return json.loads(pg.evaluate('(window.qinglu_btns(), window.qinglu_btns_out)')).get('l', [])
    def state():
        return json.loads(pg.evaluate('window.qinglu_state'))
    def tap(prefix, wait=900):
        for t, x, y in btns():
            if t.startswith(prefix) and 0 <= y <= H:
                pg.touchscreen.tap(x, y); pg.wait_for_timeout(wait); return True
        return False
    def tap_scroll(prefix, wait=1000, tries=8):
        # 小屏上行囊页要翻：只点露在底栏之上的按钮；在上面看不到就往上翻，在下面就往下翻
        for _ in range(tries):
            ys = [(t, x, y) for t, x, y in btns() if t.startswith(prefix)]
            for t, x, y in ys:
                if 100 <= y <= H - 90:   # 顶栏下、底栏上
                    pg.touchscreen.tap(x, y); pg.wait_for_timeout(wait); return True
            up = bool(ys) and all(y < 100 for _, _, y in ys)
            pg.mouse.move(W / 2, H / 2); pg.mouse.wheel(0, -220 if up else 220); pg.wait_for_timeout(500)
        return False
    def clear_dialogs(n=12):
        # 对话点完（▼ / 继续 / 知道了 / 记下了），事件有选项就点第一个
        for _ in range(n):
            st = state()
            names = [t for t, _, _ in btns()]
            hit = [k for k in ['记下了', '知道了', '继续', '▼', '推开静室的门', '进屋'] if any(t.startswith(k) for t in names)]
            if hit:
                res.setdefault('log', []).append(hit[0]); tap(hit[0]); continue
            if st.get('modal', '') == '' and st.get('loc') != 'trip' and any(t in NAV for t in names):
                return
            if st.get('modal', '') == '' and st.get('loc') == 'roam':
                return  # 游历页（没有底栏）：没有对话/事件挡着就交回给调用者，别乱点“去别处”  # 底栏露出来了 = 没有挡着的面板（灵脉/选择面板 modal 也可能是空的）
            cand = [t for t in names if t and t not in NAV and len(t) >= 2 and t not in ('设置', '♪')]
            if not cand: return
            res.setdefault('log', []).append(cand[0]); tap(cand[0])
    def step(name, ok):
        pg.screenshot(path=f'{out}/{pre}_{W}x{H}_{name}.png')
        res['steps'].append([name, bool(ok), state().get('tab'), state().get('loc'), state().get('day')])
    def ls_save():
        t = pg.evaluate('localStorage.getItem("qinglu_v6_slot1")')
        return json.loads(t) if t else None
    step('title', True)
    if OLD is not None:
        names = [t for t, _, _ in btns()]
        res['title_btns'] = names
        step('continue', tap('继续', 2500))
        clear_dialogs()
        st = state(); sv = ls_save() or {}
        res['old'] = {'v': OLD['state'].get('v'), 'day': OLD['state'].get('day'), 'rev': OLD.get('rev')}
        res['loaded'] = {'screen': st.get('screen'), 'day': st.get('day'), 'saved_v': sv.get('state', {}).get('v'), 'saved_rev': sv.get('rev'), 'saved_day': sv.get('state', {}).get('day')}
        step('loaded', st.get('screen') == 'game' and st.get('day') == OLD['state'].get('day'))
        for tb in ['生平', '行囊', '江湖', '历练', '青庐']:
            clear_dialogs()
            step('old_tab_' + {'生平': 'life', '行囊': 'pack', '江湖': 'jianghu', '历练': 'map', '青庐': 'home'}[tb], tap(tb, 1200))
            if tb == '生平':   # 旧档读进来，她自己的履历（带效果小字）
                step('old_lvli', tap('她在江湖里的生平', 1500))
                tap('回江湖', 1200) or tap('生平', 1200)
        clear_dialogs()
        ok = tap('静室', 1200) and tap('十年', 6000)
        step('old_seclude10', ok)
        clear_dialogs()
        st = state(); sv = ls_save() or {}
        res['after_seclude'] = {'day': st.get('day'), 'saved_v': sv.get('state', {}).get('v'), 'saved_day': sv.get('state', {}).get('day')}
        step('old_after', True)
        clear_dialogs()
        tap('生平', 1500)
        step('old_after_lvli', tap('她在江湖里的生平', 1500))
        b.close()
        print(json.dumps(res, ensure_ascii=False, indent=1)); sys.exit(0)
    step('create', tap('新游戏', 1500))
    ok = tap('出发', 1800)
    step('opening', ok)
    clear_dialogs()
    step('home', state().get('screen') == 'game')
    ok = tap('历练') and tap('后山') and tap('去后山游历', 1500)
    step('roam', ok)
    for i in range(12):
        clear_dialogs()
        if state().get('loc') == 'trip': break
        if state().get('loc') != 'roam': break
        tap(['山涧', '松林', '断崖'][i % 3], 1200)
    step('roam_event', state().get('loc') in ('trip', 'roam'))
    clear_dialogs(20)
    ok = False
    for _ in range(8):   # 游历里事一件接一件，清完再点回青庐，直到真的到家
        clear_dialogs(20)
        if state().get('loc') == 'home':
            ok = True; break
        tap('回青庐', 1500)
    step('back_home', ok)
    for tb in ['生平', '行囊', '江湖', '青庐']:
        clear_dialogs()
        step('tab_' + {'生平': 'life', '行囊': 'pack', '江湖': 'jianghu', '青庐': 'home2'}[tb], tap(tb, 1200))
        if tb == '生平':   # 开局不久她自己的履历
            step('early_lvli', tap('她在江湖里的生平', 1500))
            tap('回江湖', 1200) or tap('生平', 1200)
    # v0.14：坊市器物铺买一件 → 回家 → 行囊里装上 → 点装备槽卸下（只走玩家版按钮）
    gear = {}
    clear_dialogs()
    ok = tap('历练') and tap('坊市') and (tap('去坊市游历', 1500) or tap('去坊市', 1500))
    for _ in range(6):
        clear_dialogs()
        if state().get('loc') == 'roam': break
    gear['at_fangshi'] = state().get('loc') == 'roam'
    gear['shop_open'] = tap('器物铺', 1200)
    step('v14_shop', gear['shop_open'])
    # v0.15.2：托售一栏总在（没有货也写“眼下没有”）
    gear['consign_hdr'] = [t for t in labels() if t.startswith('托售')][:1]
    if not gear['consign_hdr']:
        for _ in range(4):
            pg.mouse.move(W / 2, H / 2); pg.mouse.wheel(0, 300); pg.wait_for_timeout(400)
            gear['consign_hdr'] = [t for t in labels() if t.startswith('托售')][:1]
            if gear['consign_hdr']: break
    step('v152_consign', bool(gear['consign_hdr']))
    goods = [t for t, _, _ in btns() if t.endswith(' 灵石') and ' · ' in t]
    goods.sort(key=lambda t: ('×' in t, int(t.split(' · ')[-1].split()[0]) if t.split(' · ')[-1].split()[0].isdigit() else 999))   # 先买能装上的、便宜的
    gear['goods'] = goods[:6]
    bought = None
    for gd in goods:
        if tap(gd, 1000):
            names = [t for t, _, _ in btns()]
            if any(t.startswith('买下') for t in names):
                lb = state().get('lingshi')
                tap('买下', 1200)
                if state().get('lingshi') != lb:
                    bought = gd.split(' · ')[0]; break
            tap('回铺子', 800)
    gear['bought'] = bought
    step('v14_bought', bought is not None)
    tap('收起', 800)
    # v0.15.2：药铺抽屉（卖青芝 / 卖丹 / 主药保底）和差事榜（代炼、客卿、悬赏）
    clear_dialogs(3)
    gear['yao_open'] = tap('药铺', 1200) or tap_scroll('药铺', 1200, 4)
    yb = [t for t, _, _ in btns()] + labels()
    gear['yao_qz'] = any('青芝' in t for t in yb)
    gear['yao_sell'] = any(t.startswith('卖') for t, _, _ in btns()) or any('卖' in t for t in labels())
    step('v152_yao', gear['yao_open'] and state().get('sheet') == 'yao' and gear['yao_qz'])
    tap('收起', 800)
    clear_dialogs(3)
    gear['jobs_open'] = tap('差事榜', 1200) or tap_scroll('差事榜', 1200, 4)
    jb = [t for t, _, _ in btns()] + labels()
    gear['jobs_cards'] = [k for k in ('代炼', '客卿', '悬赏') if any(k in t for t in jb)]
    step('v152_jobs', gear['jobs_open'] and state().get('sheet') == 'jobs' and len(gear['jobs_cards']) == 3)
    tap('收起', 800)
    for _ in range(8):
        clear_dialogs(20)
        if state().get('loc') == 'home': break
        tap('回青庐', 1500)
    clear_dialogs()
    tap('行囊', 1200)
    step('v14_pack', True)
    if bought:
        hit = [t for t, _, _ in btns() if t.startswith(bought)]
        gear['bag_btn'] = hit[:1]
        if hit and tap_scroll(hit[0], 1000):
            step('v14_item', True)
            gear['equipped'] = tap('装上', 1200)
            tap('收起', 800)
            clear_dialogs(3)
            slot = [t for t, _, _ in btns() if bought in t and '\n' in t]
            gear['slot_btn'] = slot[:1]
            step('v14_equipped', bool(slot))
            if slot and tap_scroll(slot[0], 1000):
                gear['unequipped'] = tap('卸下', 1200)
                tap('收起', 800)
                clear_dialogs(3)
                step('v14_unequipped', gear['unequipped'])
    res['gear'] = gear
    clear_dialogs()
    tap('青庐', 1200)
    # v0.15.2：静室里有聚灵阵一行、服丹闭关开关（有丹就点开再点回）
    room = {'open': tap('静室', 1200)}
    room['arr'] = [t for t in labels() if '聚灵阵' in t][:1] + [t for t, _, _ in btns() if '聚灵阵' in t][:1]
    fd = [t for t, _, _ in btns() if t.startswith('服丹闭关：')]
    room['fudan'] = fd[:1]
    if fd:
        tap(fd[0], 900)
        room['fudan_flip'] = [t for t, _, _ in btns() if t.startswith('服丹闭关：')][:1]
        if room['fudan_flip']: tap(room['fudan_flip'][0], 900)
    else:
        room['fudan_label'] = [t for t in labels() if t.startswith('服丹')][:1]
    res['room'] = room
    step('v152_room', room['open'] and bool(room['arr']))
    ok = tap('十年', 6000)   # 长闭关（十年；修为满会提前出关）
    step('seclude', ok)
    clear_dialogs()
    step('after', True)
    # 几十年后：静室闭关十年 × 3，再看生平（履历按“青庐 N 年”记）和院子顶栏
    for _ in range(3):
        clear_dialogs()
        if tap('静室', 1200) or True:
            tap('十年', 4000)
        clear_dialogs()
    # v0.14.1：修为满了（卡在关口）时静室的样子；再一月一月坐到三月 / 九月，去坊市看拍卖会
    clear_dialogs()
    tap('青庐', 1200)
    tap('静室', 1200)
    names = [t for t, _, _ in btns()]
    res['gate'] = {'day0': state().get('day')}
    step('gate_seclude', True)
    for _ in range(8):
        d = int(state().get('day') or 0)
        if (max(d, 1) - 1) % 12 + 1 in (2, 8): break   # 去坊市路上要走一个月，到了正好三月 / 九月
        clear_dialogs()
        tap('青庐', 900); tap('静室', 1000)
        tap('一月', 2500)
        clear_dialogs()
    clear_dialogs()
    ok = tap('历练') and tap('坊市') and (tap('去坊市游历', 1500) or tap('去坊市', 1500))
    for _ in range(6):
        clear_dialogs()
        if state().get('loc') == 'roam': break
    res['gate']['month'] = (max(int(state().get('day') or 0), 1) - 1) % 12 + 1
    res['gate']['auc'] = tap('拍卖会', 1200) or tap_scroll('拍卖会', 1200, 4)   # 游历页没有底栏，按钮可以贴底
    step('v14_auc', res['gate']['auc'])
    tap('收起', 800)
    for _ in range(8):
        clear_dialogs(20)
        if state().get('loc') == 'home': break
        tap('回青庐', 1500)
    step('decades_home', tap('青庐', 1200))
    step('decades_life', tap('生平', 1500))
    step('decades_lvli', tap('她在江湖里的生平', 1500))   # 闭关以后她自己的履历
    ZJ = 'tests/fixtures/save_zhuji_v016.json'
    if OLD is None and os.path.exists(ZJ):
        zsave = json.load(open(ZJ))
        zj = {}
        c2 = b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=2, has_touch=True, is_mobile=True)
        c2.add_init_script('if(!sessionStorage.getItem("qc_seeded")){localStorage.setItem("qinglu_v6_slot1",%s);sessionStorage.setItem("qc_seeded","1");}' % json.dumps(json.dumps(zsave, ensure_ascii=False)))
        pg = c2.new_page()
        pg.on('console', lambda m: res['errors'].append(m.text) if m.type == 'error' else None)
        pg.on('pageerror', lambda e: res['errors'].append('pageerror: ' + str(e)))
        pg.goto(url)
        pg.wait_for_function('window.qinglu_btns !== undefined && window.qinglu_state !== undefined', timeout=120000)
        pg.wait_for_timeout(1500)
        step('zj_continue', tap('继续', 2500))
        clear_dialogs()
        st = state()
        zj['loaded'] = {'day': st.get('day'), 'lingshi': st.get('lingshi')}
        step('zj_loaded', st.get('screen') == 'game' and st.get('day') == zsave['state']['day'])
        # 静室：服丹闭关开关点开、再点回
        tap('青庐', 1200)
        zj['room'] = tap('静室', 1200)
        fd = [t for t, _, _ in btns() if t.startswith('服丹闭关：')]
        zj['fudan0'] = fd[:1]
        if fd:
            tap_scroll(fd[0], 900, 6)
            zj['fudan1'] = [t for t, _, _ in btns() if t.startswith('服丹闭关：')][:1]
        step('zj_fudan', bool(fd) and bool(zj.get('fudan1')) and zj['fudan1'][0] != fd[0])
        if zj.get('fudan1'):
            tap_scroll(zj['fudan1'][0], 900, 6)
        # 静室下面的青庐营建：灵圃 / 客舍 / 指点后辈 / 收徒
        zj['estate'] = [t for t in labels() if t.startswith('青庐：')][:1]
        for _ in range(4):   # 营建卡片在静室最底下，冲关按钮压着：先翻到底
            pg.mouse.move(W / 2, H / 2); pg.mouse.wheel(0, 400); pg.wait_for_timeout(400)
        zj['men_open'] = tap_scroll('指点后辈', 1200, 8)
        step('zj_estate', bool(zj['estate']) and zj['men_open'] and state().get('sheet') == 'men')
        d0 = int(state().get('day') or 0)
        tb = [t for t, _, _ in btns() if t.startswith('指点')]
        zj['teach_btn'] = tb[:1]
        if tb:
            tap(tb[0], 2500)
        clear_dialogs(20)
        zj['teach_day'] = [d0, state().get('day')]
        step('zj_taught', bool(tb) and int(state().get('day') or 0) == d0 + 1)
        tap('收起', 800)
        clear_dialogs()
        # 行囊：法衣槽是道袍，立绘带外袍
        tap('行囊', 1200)
        zj['robe'] = [t for t, _, _ in btns() if t.startswith('法衣') and '道袍' in t][:1]
        step('zj_robe', bool(zj['robe']))
        # 坊市：差事榜接一单代炼；药铺里的货郎
        clear_dialogs()
        ok = tap('历练') and tap('坊市') and (tap('去坊市游历', 1500) or tap('去坊市', 1500))
        for _ in range(6):
            clear_dialogs()
            if state().get('loc') == 'roam': break
        zj['jobs_open'] = tap('差事榜', 1200) or tap_scroll('差事榜', 1200, 4)
        ls0 = int(state().get('lingshi') or 0)
        zj['comm'] = tap('接一单代炼', 1200) or tap_scroll('接一单代炼', 1200, 4)
        zj['comm_ls'] = [ls0, state().get('lingshi')]
        step('zj_jobs', zj['jobs_open'] and state().get('sheet') == 'jobs' and zj['comm'] and int(state().get('lingshi') or 0) < ls0)
        tap('收起', 800)
        clear_dialogs(3)
        zj['yao_open'] = tap('药铺', 1200) or tap_scroll('药铺', 1200, 4)
        zj['barter_hdr'] = [t for t in labels() if t.startswith('货郎')][:1]
        for _ in range(4):   # 货郎的货单在药铺最底下：翻到底
            pg.mouse.move(W / 2, H / 2); pg.mouse.wheel(0, 400); pg.wait_for_timeout(400)
        ls1 = int(state().get('lingshi') or 0)
        bt = [t for t, _, _ in btns() if ' 换 ' in t and '（' not in t]   # 能换的（筑基档里三样都备了料）
        zj['barter'] = bt[:3]
        zj['bartered'] = tap_scroll(bt[0], 1200, 4) if bt else False
        zj['barter_after'] = [t for t, _, _ in btns() if ' 换 ' in t][:3]
        step('zj_barter', zj['yao_open'] and bool(zj['barter_hdr']) and zj['bartered'] and int(state().get('lingshi') or 0) == ls1)
        tap('收起', 800)
        res['zhuji'] = zj
    b.close()
print(json.dumps(res, ensure_ascii=False, indent=1))
