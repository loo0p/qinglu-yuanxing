# 素材来源与许可

## 字体（均为 SIL Open Font License 1.1，许可全文在 `fonts/`）
- **霞鹜文楷 LXGW WenKai** v1.530 — https://github.com/lxgw/LxgwWenKai — 正文。按游戏用字做了子集（仅供本游戏网页内使用，非可安装桌面字体）。许可：`fonts/OFL-LXGWWenKai.txt`
- **马善政毛笔楷书 Ma Shan Zheng** — https://github.com/google/fonts/tree/main/ofl/mashanzheng — 标题。子集。许可：`fonts/OFL-MaShanZheng.txt`

## 美术
- `art_src/` 与 `assets/img/` 里的标题图、场景背景（青庐、后山、寒潭、静室/心魔、结局）、青庐庭院、后山/寒潭路线图、立绘（主角三种神情、姑母、老龟、葛老三）、行路小人、物品图标：为本项目用 AI 图像生成工具生成，再由 `tools/make_assets.py` 缩放压缩；纸纹由脚本程序生成。未使用第三方图片素材。

## 音频
- 目前没有音频文件（v0.3 的程序合成音效已撤下）。`assets/audio/manifest.json` 预留了槽位；放入的每个文件都要在这里写明来源与许可。

## 引擎
- Godot Engine 4.7.2（MIT） — https://godotengine.org 。`export/templates/` 中的 Web 模板由 Godot 4.7.2-stable 源码自行编译（参数见 `tools/build_web_template.sh`）。

## 计划采用 / 借鉴（设计 v4 阶段，尚未引入任何代码或数据）
- Dialogue Manager 4 — Nathan Hoad — MIT — https://github.com/nathanhoad/godot_dialogue_manager
- GDTracery — Althar93 — Apache-2.0 — https://github.com/Althar93/GDTracery
- random_chinese_fantasy_names 词库 — hythl0day — MIT — https://github.com/hythl0day/random_chinese_fantasy_names
- Chinese-Names-Corpus 字频 — wainshine — Apache-2.0 — https://github.com/wainshine/Chinese-Names-Corpus
- 仅借思路：RimWorld AI Storyteller（公开 wiki）；Space Station 14 StationEvents（MIT）https://github.com/space-wizards/space-station-14 ；Generative Agents（Apache-2.0）https://github.com/joonspk-research/generative_agents ；heavenly-tribulation（MIT）https://github.com/hetu-script/heavenly-tribulation ；Anime2.5DRig（MIT）https://github.com/852wa/Anime2.5DRig ；See-through（Apache-2.0）https://github.com/shitagaki-lab/see-through ；DiceBear（MIT）https://github.com/dicebear/dicebear

## 音乐与音效
- Music and sound effects generated with ElevenLabs (elevenlabs.io) by the project owner's account.（2026-10-21；6 首配乐 + 6 个音效，详见制作清单；商业发行前需确认所用 ElevenLabs 套餐允许商用。）

## v0.6 立绘（lib5，`addons/portrait5/` + `portrait5/`）
- 立绘部件（头、五官开/半/闭眼、发髻与簪钗、衣袍、外氅、胡须、花钿/疤痕/魔纹）：为本项目用 AI 图像生成工具在同一底图上逐项改画生成，再由本项目脚本（yunxiu/portrait/lib5：配准、差分抠图、频率分离贴片、烘焙）拆成分层贴图。未使用第三方图片素材。
- PuppetStudio（MIT，Wabsa Khadim）：`addons/portrait5/pose_solver.gd` 原样拷入（呼吸与弹簧滞后），眨眼调度照其 runtime/avatar.gd；许可证全文见 `addons/portrait5/third_party/PuppetStudio_LICENSE`。
- 早期原型（yunxiu/portrait/godot_rig，未并入本仓库）参考过 facesjs（Apache-2.0）与 DiceBear Lorelei（CC0）；lib5 运行时不含它们的代码或美术。

## v0.6 江湖（说书人）
- `scripts/world.gd` 由本项目的叙事原型 `docs/design/sim/story_sim.py`（design-v4）移植，自写，无第三方代码。

- 江湖事件背景（茶肆/山道/坊市/夜雨/洞府/擂台，art_src/bg_*.jpg → web_portrait/bg/）：AI 生成，以 bg_houshan 为风格参考，v0.6.5

## v0.9 人物自主（`scripts/agency.gd`）
- **godot-utility-ai** — Pennycook — MIT — https://github.com/Pennycook/godot-utility-ai 。响应曲线（二值/线性/指数/逻辑斯蒂）、考量相乘聚合、按分数加权随机选择，改写成静态函数放在 `scripts/vendor/utility_ai_curves.gd`（随机数改为注入游戏自己的种子 RNG，保证存读档后可复现）。许可证全文：`addons/utility_ai/LICENSE`。
- 只借思路、未拷代码：Comme il Faut / Prom Week（McCoy 等，社会意愿 volition = 由性格与关系算出的“想对某人做某事”的分数）；Talk of the Town（Ryan 等，人物记忆随时间淡忘、流言传播）；Versu（Evans & Short，社会惯例/动作库由人物按欲望选择）；Tracery（Kate Compton，Apache-2.0，变体语法）——文本变体用本项目已有的 `world.pv()` 去重实现，没有引入 Tracery/GDTracery 代码（其全局随机数会破坏可复现）。

## v0.11 世界图
- `art_src/map_world.jpg` / `web_portrait/bg/map_world.webp`（山外世界水墨地图）：为本项目用 AI 图像生成工具生成，由 `tools/make_assets.py` 压缩。未使用第三方图片素材。地点解锁与游历为本项目自写代码，未引入第三方代码。
