# 立绘管线（lib5，原位重绘部件）

只放脚本，不放图。原始底图和重绘图（几百 MB）不进仓库；按下面的文件名准备好 `src/` 就能整套重建。

## 原理
每个部件都是对一张固定的光头人台图做图像编辑得到的（“只改 X”，其余不动）。
- 用 SIFT + RANSAC 对齐回人台（`reg.py`），按差分/解混抠出部件（`extract.py`）。线条、淡彩、光照和人台完全一致。
- 五官（眼、眉、鼻、口）不抠，按每张头的锚点（`anchors.py` 模板匹配）分频粘贴：目标皮肤的低频 + 来源墨线的高频，放在羽化椭圆里（`compose.py`）。
- 发型靠颅顶和额宽换算在不同头之间迁移。发层在眼区只留从外面垂进来的发丝（`eye_guard`）。
- 眨眼：每种眼型有睁 / 半闭（`eyesH_*`）/ 闭（`eyesC_*`、`eyes_closed@*`、`fx_m2c`）三帧。
- `bake.py` 把所有组合预先烘成半分辨率贴图和 `lib5.json`。游戏端 `addons/portrait5/` 只负责叠图和摇骰。

## 目录约定（$LIB5_DIR）
```
src/base_{f,f2,f3,f4,f5,fe,m,m2,m3,m4,m5,me}.jpg   人台底图（864×1152）
src/<部件>@<底图>.jpg                               原位重绘，例：hair_f11@base_f.jpg
   hair_* robe_* outer_* beard_*                    → extract.py 抠成 parts/
   acc_<x>@<发型名>.jpg（如 acc_f4@hair_f11）         饰品：从该发型的重绘图上再改，按发型对齐
   fx_* eyes_* eyesC_* eyesH_*                      → 五官库（compose.feature_lib）
   mark_*                                           → 花钿/痣/疤，框在 compose.MARK_BOXES
src/MANIFEST.txt                                    每张图的来源记录（save.sh 追加）
```
部件池（哪些发型/衣袍可抽、饰品挂在哪个发型上）在 `compose.py` 顶部：`HAIR`、`ROBES`、`OUTERS`、`ACC`、`BEARDS`、`MARK_BOXES`。
加新部件时**只往列表末尾追加**，并把新 id 写进 `scripts/world.gd` 的 `PV7_NEW` 一类常量，这样旧存档的人物不会换脸。

## 重建
```
export LIB5_DIR=/path/to/lib5            # 含 src/
cd tools/portrait_pipeline
python3 extract.py [只处理含这些字样的文件...]    # → $LIB5_DIR/parts/*.png + parts.json
python3 anchors.py                        # → $LIB5_DIR/anchors.json
python3 bake.py $LIB5_DIR/portrait5       # → 烘焙结果 + lib5.json（约 1.5 分钟）
cd ../.. && python3 tools/make_portrait_web.py $LIB5_DIR/portrait5   # → web_portrait/、data/lib5.json、特征包
python3 tools/portrait_pipeline/contact_sheet.py /tmp/eyes.png        # 眼型对照图
sh tools/run_tests.sh                     # 测试 + 导出
```
依赖：python3、opencv-python（含 SIFT）、numpy、scipy、Pillow。`register()` 结果缓存在 `$LIB5_DIR/cache/`。

新生成的图用 `save.sh` 收进 `src/`：`ATTACH_DIR=<生成图目录> LIB5_DIR=... ./save.sh <hash> <部件名> ...`

## 注意
- 发型重绘时模型常顺手改眼睛，不加 `eye_guard` 的话眨眼会看不见、选的眼型也会被盖住。
- 饰品抠图常把发髻的位移一起抠进来；看一眼 `parts/acc_*.png` 再决定要不要用。
- 游戏内立绘的样子以 Godot 渲染为准；调试导出里 `qinglu_dev('psheet:<json>')` 可一屏摆一组静止立绘。
