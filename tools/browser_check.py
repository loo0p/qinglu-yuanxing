# 候选代码·灰盒：桌面 Chrome（无头）360×640 视口截图与刷新恢复检查。只算“DevTools 视口布局”，不是真机测试。
import sys, time, json, os
from playwright.sync_api import sync_playwright
port = int(open('/tmp/qinglu_port').read())
out = '/workspace/qinglu/build/shots'
steps = json.loads(sys.argv[1]) if len(sys.argv) > 1 else []
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True,
        args=['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
    ctx = b.new_context(viewport={'width': 360, 'height': 640}, device_scale_factor=2, has_touch=True, is_mobile=True,
        user_agent='Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Mobile Safari/537.36')
    pg = ctx.new_page()
    logs = []
    pg.on('console', lambda m: logs.append(m.type + ': ' + m.text))
    pg.goto(f'http://127.0.0.1:{port}/index.html')
    pg.wait_for_timeout(12000)
    for st in steps:
        if st[0] == 'shot': pg.screenshot(path=f'{out}/{st[1]}.png')
        elif st[0] == 'tap': pg.touchscreen.tap(st[1], st[2]); pg.wait_for_timeout(st[3] if len(st) > 3 else 600)
        elif st[0] == 'click': pg.mouse.click(st[1], st[2]); pg.wait_for_timeout(st[3] if len(st) > 3 else 600)
        elif st[0] == 'reload': pg.reload(); pg.wait_for_timeout(12000)
        elif st[0] == 'wait': pg.wait_for_timeout(st[1])
    print('\n'.join(l for l in logs if 'error' in l.lower())[:3000])
    b.close()
