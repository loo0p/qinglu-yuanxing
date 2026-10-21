# 立绘对照：调试版里用 npcsheet:<种子> 摆 12 个随机新人物，几组拼成一张（build/shots/npc_sheet.png）
# 用法：python tools/npc_sheet.py <调试版端口> [种子...]
import sys
from playwright.sync_api import sync_playwright
from PIL import Image
port = int(sys.argv[1]); seeds = [int(x) for x in sys.argv[2:]] or [1, 2, 3]
ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
paths = []
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True, args=ARGS)
    pg = b.new_page(viewport={'width': 360, 'height': 640}, device_scale_factor=2)
    pg.goto(f'http://127.0.0.1:{port}/index.html'); pg.wait_for_function('window.qinglu_dev !== undefined', timeout=90000)
    pg.evaluate("window.qinglu_dev('jianghu')"); pg.wait_for_timeout(800)
    for s in seeds:
        pg.evaluate(f"window.qinglu_dev('npcsheet:{s}')"); pg.wait_for_timeout(3500)
        f = f'build/shots/npc_sheet_{s}.png'; pg.screenshot(path=f); paths.append(f)
    b.close()
ims = [Image.open(f) for f in paths]
out = Image.new('RGB', (sum(i.width for i in ims) + 20 * (len(ims) - 1), ims[0].height), (240, 236, 228)); x = 0
for i in ims:
    out.paste(i, (x, 0)); x += i.width + 20
out.save('build/shots/npc_sheet.png'); print('build/shots/npc_sheet.png', out.size)
