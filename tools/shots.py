# 各界面截图（桌面 Chrome 无头 + swiftshader，模拟触控；不是真机）
# 用法：python tools/shots.py <调试版端口> <玩家版端口> [前缀]
import json, sys, time
from playwright.sync_api import sync_playwright
dbg, rel = int(sys.argv[1]), int(sys.argv[2]); pre = sys.argv[3] if len(sys.argv) > 3 else 'v04'
out = 'build/shots'
ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
SCENES = [('title', 'title'), ('create', 'create'), ('home', 'home'), ('sheet_furnace', 'furnace'), ('depart', 'depart'), ('choose', 'map'),
          ('event', 'event_beat1'), ('reveal', 'event_choices'), ('laogui', 'hantan_laogui'), ('reveal', 'hantan_laogui_choices'),
          ('result', 'result'), ('cult', 'cult'), ('xinmo', 'xinmo'), ('ending', 'ending'),
          ('create_rnd', 'create_portrait'), ('story', 'story'), ('reveal', 'story_choices'), ('jianghu', 'jianghu'), ('person', 'person'),
          ('story:表白', 'bg_chasi'), ('story:偶遇', 'bg_shandao'), ('story:坊市传闻', 'bg_fangshi'), ('story:夜雨', 'bg_yeyu'), ('story:秘境', 'bg_dongfu'), ('story:宗门大比', 'bg_leitai'), ('story:暗恋不舍', 'anlian'), ('life', 'life'),
          ('story:宗门招徒', 'zongmen'), ('story:秘境请柬', 'qingjian'), ('story:拍卖会', 'paimai'), ('story:劫修伏击', 'jiexiu'), ('story:师弟惹祸', 'shidi'),
          ('story:天材地宝', 'tiancai'), ('story:对手突破', 'tupo'), ('story:旧债上门', 'jiuzhai'), ('story:节令', 'jieling'), ('guide', 'guide_home'), ('guide_depart', 'guide_depart'), ('settings', 'settings'), ('title', 'title_after'),
          ('story:两难', 'liangnan'), ('reveal', 'liangnan_choices'), ('story:暗涌', 'anyong'), ('story:坊市认物', 'renwu'), ('reveal', 'renwu_choices'),
          ('story:借庐', 'jielu'), ('story:点化', 'dianhua'), ('story:白首', 'baishou'), ('story:重逢', 'chongfeng'), ('story:灵田', 'light_home'), ('extra', 'extra'),
          ('ag:截道@路', 'ag_jiedao_road'), ('reveal', 'ag_jiedao_road_choices'), ('ag:撞见@路', 'ag_zhuangjian_road'), ('ag:示好', 'ag_shihao'), ('ag:求援', 'ag_qiuyuan'), ('ag:流言', 'ag_liuyan'), ('ag:挑战@路', 'ag_tiaozhan_road'), ('xinshi', 'xinshi'),
          ('ag:求药', 'ag_qiuyao'), ('ag:赔罪', 'ag_peizui'), ('ag:托付', 'ag_tuofu'), ('ag:问道@路', 'ag_wendao_road'),
          ('md:风声', 'md_fengsheng'), ('reveal', 'md_fengsheng_choices'), ('md:风声@路', 'md_fengsheng_road'), ('md:插手:夺宝', 'md_chashou_duobao'), ('reveal', 'md_chashou_choices'), ('mdpick', 'md_chashou_result'), ('mdnews', 'md_news'),
          ('map', 'world_warm'), ('map', 'world_map'), ('map_place', 'world_place'), ('roam', 'world_roam'), ('meet', 'world_meet'), ('reveal', 'world_meet_choices'),
          ('equip', 'v14_equip'), ('item', 'v14_item'), ('shop', 'v14_shop'), ('auc', 'v14_auc'), ('seclude', 'v14_seclude'), ('chron', 'v14_chron')]
# 可选第 4 个参数：只截名字里含这些词的场景（逗号分隔），例如 liangnan,jianghu
if len(sys.argv) > 4:
    keep = sys.argv[4].split(',')
    SCENES = [x for x in SCENES if any(k in x[1] for k in keep)]
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
