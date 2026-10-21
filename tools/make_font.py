# 候选代码：生成 GB2312 + 常用符号 子集字体（Noto Sans CJK SC, OFL）
import glob
chars=set(chr(c) for c in range(0x20,0x7f))
for b1 in range(0xA1,0xF8):
    for b2 in range(0xA1,0xFF):
        try: chars.add(bytes([b1,b2]).decode('gb2312'))
        except: pass
chars |= set("◎★☆·—…×→←↑↓「」『』《》〈〉、。，！？：；（）【】％＋－／～①②③④⑤⑥⑦⑧⑨⑩■□▲△●○◆◇✓✗")
for f in glob.glob('/workspace/qinglu/data/*.json')+glob.glob('/workspace/qinglu/scripts/*.gd'):
    chars |= set(open(f,encoding='utf-8').read())
open('/tmp/qinglu_chars.txt','w',encoding='utf-8').write(''.join(sorted(c for c in chars if c.isprintable())))
