# 候选代码·灰盒：各界面 360×640 截图 + 刷新恢复检查（桌面 Chrome 无头，模拟触控；不是真机）
import json
from playwright.sync_api import sync_playwright
port = int(open('/tmp/qinglu_port').read()); out = '/workspace/qinglu/build/shots'
res = {}
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True, args=['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
    ctx = b.new_context(viewport={'width':360,'height':640}, device_scale_factor=2, has_touch=True, is_mobile=True)
    pg = ctx.new_page(); errs = []
    pg.on('console', lambda m: errs.append(m.text) if m.type == 'error' else None)
    pg.goto(f'http://127.0.0.1:{port}/index.html'); pg.wait_for_function('window.qinglu_dev !== undefined', timeout=60000)
    for sc in ['laogui', 'depart', 'home', 'cult']:
        pg.evaluate(f"window.qinglu_dev('{sc}')"); pg.wait_for_timeout(800)
        pg.screenshot(path=f'{out}/{sc}.png')
    res['before_reload'] = pg.evaluate("window.qinglu_state")
    # 刷新恢复：停在老龟事件卡上刷新
    pg.evaluate("window.qinglu_dev('laogui')"); pg.wait_for_timeout(800)
    res['laogui_state'] = pg.evaluate("window.qinglu_state")
    pg.reload(); pg.wait_for_function('window.qinglu_dev !== undefined', timeout=60000); pg.wait_for_timeout(800)
    pg.screenshot(path=f'{out}/reload_title.png')
    res['after_reload_title'] = pg.evaluate("window.qinglu_state")
    pg.touchscreen.tap(180, 134); pg.wait_for_timeout(800)   # “继续”按钮
    pg.screenshot(path=f'{out}/reload_continue.png')
    res['after_continue'] = pg.evaluate("window.qinglu_state")
    res['errors'] = errs[:10]
    b.close()
print(json.dumps(res, ensure_ascii=False, indent=1))
