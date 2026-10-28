# 事件引擎调研：组合事件、同事件多结局、可插拔（v0.12）

> 性质：**设计调研 + 已落地的取舍记录**。“已核实”指 2026-10-28 用 GitHub API / 公开资料查过；“未核实”指凭公开演讲、论文或社区资料的转述，未读到一手源码。
> 结论先说：没有一个现成开源项目同时满足「纯 GDScript、能 Web 导出、有种子可复现、按人物/关系选角、同一事件多结局、生平成文」。
> 所以自写了 `addons/storylet_engine/`（与青庐无关的引擎）+ `scripts/saga.gd`（青庐胶水）+ `data/packs/*.json`（内容）。只直接复用了 GDTracery 的代码。

## 1. 逐个看

| 来源 | 是什么 | 许可 / 活跃度（已核实 2026-10-28） | 拿来了什么 |
|---|---|---|---|
| **Storylet / QBN**（Fallen London、StoryNexus；Emily Short《Beyond Branching》2016；Dendry） | 一条 storylet = 条件（qualities）+ 内容 + 效果；从“当下可发的”里挑 | Fallen London 闭源；`aucchen/dendry` MIT，2026-04 有提交，42★；原版 `dendry/dendry` MIT，2015 后不动 | **核心模型**：`when` + `weight` 的可发池；quality = 人物属性 / 关系 / flag。代码未用（Dendry 是 JS 的整套 IF 运行时） |
| **Twine**（Harlowe/SugarCube/Chapbook） | 超文本分支 | `klembot/twinejs` GPL-3.0（不能拷进本仓库）；Chapbook MIT | 只借：文本内联变量 `{x}` 的写法 |
| **Valve / Elan Ruskin 规则库**（GDC 2012《Rule Databases for Contextual Dialog and Game Logic》） | 事件发“查询”，规则库里条件最多 / 最具体的那条胜出 | 演讲，无源码（未核实细节以演讲公开幻灯为准） | **`emit(signal)` + `family` + `priority`**：同一信号下，同族只发最具体的一条；不同族同时发（一死，道侣、徒弟、她各自一条） |
| **RimWorld**（AI Storyteller、Tale） | 说书人按张力/冷却/人口调节事件节奏；Tale 记下发生过的事供艺术品描述 | 闭源，EULA 不许复用代码 | 只借：节奏闸门（`cooldown`、`min_day`、`family_gap`、同族衰减）；“先发生、后成文” |
| **Crusader Kings III** 事件脚本 | `trigger` / `immediate` / `option` + `ai_chance` / 连锁 `trigger_event = { days = N }` | 闭源；脚本格式见官方 wiki（未逐条核实） | **`effects` 先跑（immediate）→ `outcomes` 加权**；`choices` 每项有自己的加权结局（玩家选“劝”，结果按对方性格分好坏）；`schedule` = 延时连锁 |
| **Ink / godot-ink** | 分支对白脚本语言 | `inkle/ink` MIT，2026-05；`paulloz/godot-ink` MIT，2026-07，788★ | 没用：godot-ink 走 C#（.NET），Godot 4 的 C# 不能 Web 导出；而且它是对白树，不是“谁身上会发生什么” |
| **Yarn Spinner + Godot 版** | 对白脚本 | `YarnSpinner` MIT，2026-10 活跃；`YarnSpinner-Godot` MIT，2026-10 活跃 | 没用：同样依赖 C#/.NET，Web 导出不行。（更正：早先草稿写“因许可证不用”是错的，两者都是 MIT） |
| **Dialogic 2** | Godot 对白 / 时间线插件 | `dialogic-godot/dialogic` MIT，2026-08，6.1k★ | 没用：时间线编辑器 + 对白 UI，体量大、偏过场；青庐已有自己的事件卡 UI |
| **Tracery / GDTracery** | 变体语法 `#symbol#` | `galaxykate/tracery` Apache-2.0；`Althar93/GDTracery` Apache-2.0，2026-04 | **直接复用 GDTracery 代码**（`vendor/tracery.gd`）：加了 `picker` 回调（避开最近用过的一半）、去掉 class_name，RNG 换成引擎的种子 RNG |
| **Expressionist**（James Ryan） | 带标签的生成语法 | `james-owen-ryan/expressionist` MIT，2022 后不动 | 只借：语法符号按“变量拼名”（`#d_mourn_{kind}#`）选分支句 |
| **Versu / CiF / Ensemble**（Evans & Short；McCoy 等 Prom Week） | 社会惯例、人物按意愿选社交动作 | Versu 闭源；`ensemble-engine/ensemble` 许可未声明（NOASSERTION），2022 后不动 | 只借：`roles` 的 `where` / `weight` 用人物性格、关系算选角意愿（v0.9 agency 早已在用） |
| **Wildermyth** | 事件按“角色槽”从队伍里挑人（role casting），结局改写人物（伤疤、关系、变身） | 闭源；modding 文档公开（未逐条核实） | **选角**：`roles:[{name, from, where, weight, optional, each}]`；一个事件给多人各写一笔 |
| **Caves of Qud · Sultan histories**（Grinblat & Bucklew, FDG 2017） | 先模拟事件，再按事件倒推生成有因果的传记文字 | 闭源；论文公开 | **前尘**：`trigger=bio` 的 storylet 按年龄依次跑，返回 `[[岁, 句子]]`；`free_age` 插曲最后按年纪排序 |
| **鬼谷八荒** | NPC 自己结交、结仇、成侣、收徒、渡劫，玩家看得到每个人的生平 | 闭源 | 体验目标：NPC 不是为她服务的道具；“地点只调概率” |
| 其它找到的：`t-mw/storylets-rs`（Rust，MIT）、`storylet-studio/storylets`（TS，MIT，2026-10） | 小型 storylet 库 | 已核实许可 | 体量小、语言不合，只对照了 API 命名 |

## 2. 我们的引擎（候选代码 → 随 v0.12 发布）
- **组合事件**：`schedule`（N 日后连锁）、`run`（立刻连锁）、`emit`（再发信号）、`flag` 计数（“炼丹三回以上才可能成九转丹”“吵过三回才分开”“情劫被推开过才有心魔”）。
- **同一事件多结局**：`outcomes` 加权（权重是表达式，吃性格、境界、关系、记忆），`first:true` 做优先分支；玩家选项下面还有加权结局。
- **可插拔**：引擎只认 adapter 的 6 个必需方法；游戏专属效果走 `se_op`；内容是 JSON 包，可加可卸（`add_pack` / `remove_pack`）。
- **可复现**：引擎 RNG 有种子、状态是纯 Dictionary（存进存档 `w.se`）；前尘用独立种子。
- **质量工具**：lint CLI、模拟台（覆盖率、去重率）、青庐侧 `tests/saga_test.gd`。

## 3. 没做 / 留到以后
- 旧的手写事件模板（`world.gd` 的 T 表、agency 的主动动作）这一版仍走旧代码，没有迁进包里；新事件与 NPC 之间的江湖自转（相遇八种事、独处、破境、坐化、飞升、新人、丧事）已迁入。
- 没有可视化编辑器；内容由 `tools/make_packs.py` 生成 JSON（作者写 Python 结构，lint 把关）。
