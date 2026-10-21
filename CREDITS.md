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
