# 各界面截图（桌面 Chrome 无头 + swiftshader，模拟触控；不是真机）
# 用法：python tools/shots.py <调试版端口> <玩家版端口> [前缀]
import json, sys, time
from playwright.sync_api import sync_playwright
dbg, rel = int(sys.argv[1]), int(sys.argv[2]); pre = sys.argv[3] if len(sys.argv) > 3 else 'v04'
out = 'build/shots'
ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
SCENES = [('title', 'title'), ('home', 'home'), ('sheet_furnace', 'furnace'), ('depart', 'depart'), ('choose', 'map'),
          ('event', 'event_beat1'), ('reveal', 'event_choices'), ('laogui', 'hantan_laogui'), ('reveal', 'hantan_laogui_choices'),
          ('result', 'result'), ('cult', 'cult'), ('xinmo', 'xinmo'), ('ending', 'ending')]
res = {}
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True, args=ARGS)
    for (w, h) in [(360, 640), (390, 844)]:
        c = b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=2, has_touch=True, is_mobile=True)
        pg = c.new_page(); errs = []
        pg.on('console', lambda m: errs.append(m.text) if m.type == 'error' else None)
        pg.goto(f'http://127.0.0.1:{dbg}/index.html'); pg.wait_for_function('window.qinglu_dev !== undefined', timeout=90000)
        pg.wait_for_timeout(800)
        for sc, name in SCENES:
            pg.evaluate(f"window.qinglu_dev('{sc}')"); pg.wait_for_timeout(1300 if sc != 'ending' else 700)
            pg.screenshot(path=f'{out}/{pre}_{w}x{h}_{name}.png')
        res[f'{w}x{h}_errors'] = errs[:5]; c.close()
    c = b.new_context(viewport={'width': 360, 'height': 640}, device_scale_factor=2, has_touch=True, is_mobile=True)
    pg = c.new_page(); t0 = time.time(); pg.goto(f'http://127.0.0.1:{rel}/index.html')
    pg.wait_for_function('window.qinglu_state !== undefined', timeout=90000)
    res['release_boot_s'] = round(time.time() - t0, 1); res['release_has_dev_hook'] = pg.evaluate('typeof window.qinglu_dev !== "undefined"')
    b.close()
print(json.dumps(res, ensure_ascii=False, indent=1))
