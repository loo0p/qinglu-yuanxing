# 对照图：每种眼型 睁/半/闭 + 一组随机人物（python 参考渲染，与游戏内 Godot 渲染同源）
# 用法：LIB5_DIR=<lib5 数据目录> python3 contact_sheet.py out.png [font.ttf]
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compose as c, cv2, numpy as np
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1] if len(sys.argv) > 1 else 'contact.png'
F = ImageFont.truetype(sys.argv[2], 18) if len(sys.argv) > 2 else ImageFont.load_default()
tiles = []
for k, eid in enumerate(c.CLOSED):
    m = eid.split('@')[-1] if '@' in eid else eid.split(':')[1]
    sx = m[5]; b = (c.F_BASES if sx == 'f' else c.M_BASES)[k % 5]
    sp = c.choose_spec(9, base=b); sp['feats']['eyes'] = eid; sp['marks'] = []; sp['outer'] = None
    sp['robe'] = 'robe_f1@base_f' if sx == 'f' else 'robe_m1@base_m'
    sp['hair'] = 'hair_f2@base_f' if sx == 'f' else 'hair_m2@base_m'; sp['acc'] = []; sp['beard'] = None
    im = np.hstack([c.render(sp, eye_state=s)[240:350, 310:570] for s in ('open', 'half', 'closed')])
    p = Image.fromarray(cv2.cvtColor(im, cv2.COLOR_BGR2RGB)); d = ImageDraw.Draw(p)
    d.rectangle([0, 0, 250, 20], fill=(255, 255, 255)); d.text((2, 0), f'{eid[5:]} on {b}', font=F, fill=(0, 0, 0)); tiles.append(p)
w, h = tiles[0].size
S = Image.new('RGB', (2 * (w + 6), ((len(tiles) + 1) // 2) * (h + 4)), (245, 242, 236))
for i, t in enumerate(tiles): S.paste(t, ((i % 2) * (w + 6), (i // 2) * (h + 4)))
S.save(out); print(out, S.size)
