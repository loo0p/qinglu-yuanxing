# 青庐远行

一个竖屏的修仙文字小品：山脚下的青庐、一位姑母、两条山路，和一个想筑基的姑娘。
经营青庐的田与丹炉，背上行囊去后山、去寒潭，在路上做几件会被人记住的选择，最后回到静室，过心魔劫，筑基。

- 引擎：Godot 4.7.2（GL Compatibility），导出 H5，竖屏 360×640，优先手机浏览器
- 当前版本：**v0.5 试玩版**（场景化界面，标题与建角也场景化；一局约 40 游戏日、30–60 分钟）
- 在线试玩：<https://loo0p.github.io/qinglu-yuanxing/>
- 推送到 `main` 后由 GitHub Actions 自动测试并发布到 GitHub Pages

> 说明：目前只在桌面 Chrome 无头模式（模拟触控、360×640）里验证过，**还没有在真机上测过**。欢迎反馈。

## 目录

| 路径 | 内容 |
|---|---|
| `scripts/game_state.gd` | 规则层：纯逻辑、无 UI（时间推进、田与丹炉、历练状态机、心魔劫、结局）。测试直接 preload 它 |
| `scripts/main.gd` | 界面层（场景优先）：整幅插画舞台 + 热点/路线图路标 + 顶栏 HUD + 底部抽屉 + 视觉小说式对话框；动效、音频也在这里 |
| `scripts/save_store.gd` | 存档：`user://`（Web 端 IndexedDB）+ localStorage 镜像，rev 版本号防多标签页互相覆盖，写入先写临时文件再改名，保留 .bak |
| `data/events.json` | 全部事件文本与选项（重事件、轻节点、老龟的各个变体） |
| `data/routes.json` | 后山 / 寒潭 两条路线的拓扑、风闻 |
| `data/xinmo.json` | 心魔劫题库 |
| `assets/img/` | 水墨淡彩背景、立绘、图标（webp，原样打包，运行时解码） |
| `assets/audio/` | 音频槽位：`manifest.json` 列出 BGM（title/home/travel_houshan/hantan/xinmo/ending）与音效（tap/page/pickup/success/fail/breakthrough），填文件名即生效，空=静默。目前全部为空 |
| `art_src/` | 美术原图（未压缩），`tools/make_assets.py` 由此生成 `assets/img/` |
| `fonts/` | 霞鹜文楷 + 马善政毛笔楷书 的子集（只含游戏用到的字） |
| `export/templates/` | 瘦身版 Web 导出模板（自编译，见下） |
| `tests/` | 无头规则测试 `run_tests.gd`、UI 冒烟 `ui_smoke.gd`、基线 fixtures |
| `tools/` | 测试/导出脚本、资源生成脚本、本地服务、截图脚本 |
| `docs/design/` | 策划案 v3.2（md + docx）、用户原始需求、数值模拟器 `sim/` |

## 跑测试、导出

```sh
# 需要 Godot 4.7.2；路径用 GODOT 环境变量指定
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 sh tools/run_tests.sh
```

它会依次：导入资源 → 规则测试（111 项断言，含 20 局无卡死矩阵与基线对比）→ UI 冒烟（按按钮文字一路点到筑基）→ 导出
`build/web/`（玩家版，release，用瘦身模板）和 `build/web_debug/`（调试版，带 `window.qinglu_dev()` 调试钩子，需要官方 debug 模板）。

本地试玩：`python3 tools/serve.py 8000 build/web`，浏览器打开 `http://127.0.0.1:8000/`。

截图（需要 Playwright + Chrome）：先分别在两个端口起调试版和玩家版，再 `python tools/shots.py <调试端口> <玩家端口>`，输出到 `build/shots/`。

### 体积

- 官方 Web 模板的 wasm 约 39 MB；`export/templates/web_nothreads_release_slim.zip` 是自编译的瘦身模板（单线程、去掉 3D、正则、SVG、网络等用不到的模块，`optimize=size_extra`），wasm 约 19.5 MB，gzip 后约 5.7 MB。重新编译：`sh tools/build_web_template.sh`。
- 图片是 webp，用 `importer="keep"` 原样打包、运行时解码；字体只保留用到的字。音频只支持 .ogg（瘦身模板去掉了 mp3 解码）。
- **改了文案后要重跑 `python3 tools/make_font.py <WenKai.ttf> <MaShanZheng.ttf>`**，否则新字会缺字形。

### 发布

`.github/workflows/pages.yml`：推送到 `main` → 下载固定版本 Godot 4.7.2 → 跑测试与冒烟 → 导出 → 部署到 GitHub Pages。
单线程导出，不需要 COOP/COEP 头；导出文件全部用相对路径，放在 `/<仓库名>/` 子路径下也能用。
首次使用需要在仓库 Settings → Pages 里把 Source 设成 “GitHub Actions”。

## 约定（给人，也给 AI 代理）

见 [AGENTS.md](AGENTS.md)。

## 许可与致谢

代码许可尚未指定（由仓库所有者决定）。字体、美术、音频的来源与许可见 [CREDITS.md](CREDITS.md)。
