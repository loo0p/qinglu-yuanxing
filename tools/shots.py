# 各界面 360×640 截图（桌面 Chrome 无头 + swiftshader，模拟触控；不是真机）
# 用法：python tools/shots.py <调试版端口> <玩家版端口>
import json, sys, time
from playwright.sync_api import sync_playwright
dbg, rel = int(sys.argv[1]), int(sys.argv[2]); out = 'build/shots'
res = {}
ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required']
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True, args=ARGS)
    def ctx():
        return b.new_context(viewport={'width': 360, 'height': 640}, device_scale_factor=2, has_touch=True, is_mobile=True)
    # 1) 玩家版：加载时间、无调试钩子、标题页、首点之后
    c = ctx(); pg = c.new_page(); errs = []
    pg.on('console', lambda m: errs.append(m.text) if m.type == 'error' else None)
    t0 = time.time(); pg.goto(f'http://127.0.0.1:{rel}/index.html')
    pg.wait_for_function('window.qinglu_state !== undefined', timeout=90000)
    res['release_boot_s'] = round(time.time() - t0, 1); pg.wait_for_timeout(1200)
    res['release_has_dev_hook'] = pg.evaluate('typeof window.qinglu_dev !== "undefined"')
    pg.screenshot(path=f'{out}/v03_title.png')
    pg.touchscreen.tap(180, 404); pg.wait_for_timeout(900)   # 新游戏（无存档时）
    pg.screenshot(path=f'{out}/v03_create.png')
    res['release_after_tap'] = pg.evaluate('window.qinglu_state'); res['release_errors'] = errs[:8]; c.close()
    # 2) 调试版：各场景
    c = ctx(); pg = c.new_page(); errs2 = []
    pg.on('console', lambda m: errs2.append(m.text) if m.type == 'error' else None)
    pg.goto(f'http://127.0.0.1:{dbg}/index.html'); pg.wait_for_function('window.qinglu_dev !== undefined', timeout=90000)
    for sc, name in [('home', 'home'), ('event', 'event_gelaosan'), ('laogui', 'hantan_laogui'), ('depart', 'depart'), ('cult', 'cult'), ('xinmo', 'xinmo'), ('ending', 'ending')]:
        pg.evaluate(f"window.qinglu_dev('{sc}')"); pg.wait_for_timeout(1100)
        pg.screenshot(path=f'{out}/v03_{name}.png'); res[name] = pg.evaluate('window.qinglu_state')
    res['debug_errors'] = errs2[:8]; b.close()
print(json.dumps(res, ensure_ascii=False, indent=1))
