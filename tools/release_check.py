# 玩家版（release 导出）点一遍：标题 → 新游戏 → 院子 → 后山游历（碰上奇遇就选）→ 回家 → 生平 → 行囊 → 江湖 → 静室闭关一年
# 只用玩家版也有的只读钩子 window.qinglu_btns（屏上按钮文字与位置）与 window.qinglu_state；不用调试钩子。
# 桌面 Chrome 无头（swiftshader，模拟触控），不是真机。
# 用法：python3 tools/release_check.py <URL> <截图前缀> [宽 高]
import json, sys, time
from playwright.sync_api import sync_playwright
url, pre = sys.argv[1], sys.argv[2]
W, H = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (390, 844)
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
    t0 = time.time()
    pg.goto(url)
    pg.wait_for_function('window.qinglu_btns !== undefined && window.qinglu_state !== undefined', timeout=120000)
    res['boot_s'] = round(time.time() - t0, 1)
    res['has_dev_hook'] = pg.evaluate('typeof window.qinglu_dev !== "undefined"')
    pg.wait_for_timeout(1500)
    def btns():
        d = json.loads(pg.evaluate('window.qinglu_btns()'))
        sx = pg.evaluate('window.innerWidth') / d['w']; sy = pg.evaluate('window.innerHeight') / d['h']
        return [(t.replace('● ', ''), x * sx, y * sy) for t, x, y in d['b']]
    def state():
        return json.loads(pg.evaluate('window.qinglu_state'))
    def tap(prefix, wait=900):
        for t, x, y in btns():
            if t.startswith(prefix) and 0 <= y <= H:
                pg.touchscreen.tap(x, y); pg.wait_for_timeout(wait); return True
        return False
    def clear_dialogs(n=12):
        # 对话点完（▼ / 继续 / 知道了 / 记下了），事件有选项就点第一个
        for _ in range(n):
            st = state()
            if st.get('modal', '') == '' and st.get('loc') != 'trip':
                return
            names = [t for t, _, _ in btns()]
            for k in ['记下了', '知道了', '继续', '▼', '推开静室的门', '进屋']:
                if any(t.startswith(k) for t in names):
                    tap(k); break
            else:
                cand = [t for t in names if t and t not in NAV and len(t) >= 2]
                if not cand: return
                tap(cand[0])
    def step(name, ok):
        pg.screenshot(path=f'{out}/{pre}_{W}x{H}_{name}.png')
        res['steps'].append([name, bool(ok), state().get('tab'), state().get('loc'), state().get('day')])
    step('title', True)
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
    ok = tap('回青庐', 1500); clear_dialogs()
    step('back_home', ok)
    for tb in ['生平', '行囊', '江湖', '青庐']:
        clear_dialogs()
        step('tab_' + {'生平': 'life', '行囊': 'pack', '江湖': 'jianghu', '青庐': 'home2'}[tb], tap(tb, 1200))
    clear_dialogs()
    ok = tap('静室', 1200) and tap('一年', 2500)
    step('seclude', ok)
    clear_dialogs()
    step('after', True)
    b.close()
print(json.dumps(res, ensure_ascii=False, indent=1))
