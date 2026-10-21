# 候选代码·灰盒：两个标签页同开一个存档，第二个写入时应发现冲突并停写（桌面 Chrome 无头）
import json
from playwright.sync_api import sync_playwright
port = int(open('/tmp/qinglu_port').read()); out = '/workspace/qinglu/build/shots'
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True, args=['--use-angle=swiftshader','--enable-unsafe-swiftshader'])
    ctx = b.new_context(viewport={'width':360,'height':640}, has_touch=True)
    a = ctx.new_page(); a.goto(f'http://127.0.0.1:{port}/'); a.wait_for_function('window.qinglu_dev !== undefined', timeout=60000)
    a.evaluate("window.qinglu_dev('home')"); a.wait_for_timeout(500)
    c = ctx.new_page(); c.goto(f'http://127.0.0.1:{port}/'); c.wait_for_function('window.qinglu_dev !== undefined', timeout=60000); c.wait_for_timeout(500)
    c.touchscreen.tap(180, 134); c.wait_for_timeout(600)          # B：继续
    a.bring_to_front(); a.evaluate("window.qinglu_dev('cult')"); a.wait_for_timeout(600)   # A：点“按目标排程”（存档 rev+1）
    c.bring_to_front(); c.touchscreen.tap(180, 345); c.wait_for_timeout(600)   # B：再操作 → 应发现 A 写过更新的档
    c.screenshot(path=f'{out}/twotab_B.png')
    print('A', a.evaluate('window.qinglu_state')); print('B', c.evaluate('window.qinglu_state'))
    b.close()
