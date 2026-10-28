# Storylet Engine 1.0.0（Godot 4，纯 GDScript）

用数据（JSON 内容包）驱动的事件 / 叙事引擎。它不认识任何具体游戏：游戏通过一个 **adapter**（鸭子类型的胶水对象）接入。
做三件事：**挑事**（谁、何时、发哪一条）、**定结局**（同一事件的多个结局按人物与关系加权）、**成文**（变体语法写进履历）。

思路来源见 `docs/design/event-engine-research.md`（青庐仓库）。代码复用：`vendor/tracery.gd`（GDTracery，Apache-2.0，有改动，见文件头）。

## 目录
| 文件 | 作用 |
|---|---|
| `storylet_engine.gd` | 引擎本体（`preload` 使用，不注册 class_name） |
| `se_lint.gd` | 内容包静态检查：表达式能否解析、角色/变量/语法符号有没有来处、op 是否认识、chain/offer 目标是否存在 |
| `se_sim.gd` | 模拟台：跑完后统计行数、去重率、每条 storylet / 每个结局的覆盖 |
| `tools/lint_cli.gd` | 命令行 lint：`godot --headless --path . -s res://addons/storylet_engine/tools/lint_cli.gd -- a.json b.json` |
| `examples/` | 最小示例：四个人的小村子（`example_adapter.gd` + `example_pack.json`） |
| `vendor/` | GDTracery 及其许可证 |

## 快速开始
```gdscript
const SE = preload("res://addons/storylet_engine/storylet_engine.gd")
var eng = SE.new(my_adapter, save_data.get("se", {}), seed)   # 状态就是这个 Dictionary，原样存进存档
eng.load_pack_file("res://data/packs/my_pack.json")
# 每一刻（tick：日、月、年都行，见“时间单位”）：
eng.tick_due()          # 到期的连锁事件
eng.tick_world()        # trigger=daily 的世界事件（大比、秘境……）
for a in some_actors: eng.beat(a)     # 人物各自的“一拍”（trigger=actor，按显著度挑一条）
eng.emit("death", {"A": who}, {"how": "坐化"})   # 游戏里发生了什么，就发个信号（trigger=on:death）
save_data["se"] = eng.save_state()
```

## Adapter 接口
必需：`se_now() -> int`（当前第几刻）、`se_actors() -> Array`、`se_id(a) -> int`、`se_actor(id)`、`se_name(a) -> String`、`se_chronicle(a, text, inst, eng)`。
可选：`se_alive(a)`（连锁事件到期时跳过死人，`dead_ok` 例外）、`se_var(name, inst, eng)`（文本里 `{name}` 的游戏变量）、
`se_op(op, inst, eng)`（游戏专属效果）、`se_ticks(n, unit) -> float`（n 个 unit 合多少刻，见“时间单位”）、`se_offer(inst, eng)`（把要玩家选的事交给游戏排队）。
表达式里 `g.xxx(...)` 调的就是 adapter 上的方法（查询函数随便加）。

## 内容包格式
```json
{"id": "pack_id", "version": 1, "unit": "day", "host_vars": ["天气"], "host_ops": ["gold"],
 "grammar": {"food": ["一碗面", "两个包子"]},
 "storylets": [ {...}, ... ]}
```
storylet 字段：
- `id`、`trigger`：`actor` / `daily` / `chain` / `bio` / `offer` / `manual` / `on:<信号>`
- `in`：调用方预先绑好的角色（actor/bio/on:* 缺省 `["A"]`）；`roles`：引擎来选的角色
  `{name, from?, where?(SELF), weight?(SELF), optional?, fixed?, each?, limit?, allow_same?}`
- `when`（条件）、`weight`（显著度）、`p`（daily 每 unit 的概率）、`priority` + `family`（同信号同族只发最具体的一条：L4D 规则库做法）
- 节奏闸门：`max`、`min_t`（旧名 `min_day`）、`cooldown`、`actor_cooldown`、`family_gap`；新鲜度 `novelty`；同族衰减（cfg.family_decay）
- `effects`（先执行，CK3 的 immediate）→ `outcomes`（加权挑一个；`first:true` 的按顺序先到先得）
- `choices`（只用于 offer：`[{id, label, when?, outcomes:[...]}]`，由游戏 present/choose）、`text`（offer 的开场）
- `bio` 专用：`age:[lo, hi]`、`free_age`（插曲，不推进当前年纪，最后按年纪排序）
- `dead_ok`（哪些角色死了也照发）、`ctx_in`（offer/chain 由上游带来的 ctx 变量名，供 lint 认）

内置 op：`chron`(who/text/vars/key)、`var`/`say`、`set`、`flag`(key/add/set)、`gvar`、`schedule`(id/in/cast/keep/ctx)、
`run`、`emit`(signal)、`offer`、`if`(when/then/else)、`chance`(p/then/else)、`pick`(options)、`cast`(补一个角色/else)、
`drop`、`each`(from/as/limit/effects)。其余交给 `adapter.se_op`。所有 op 都可带 `when`。

文本：`{A}` 角色名、`{ctx变量}`、`{host_var}`、`#symbol#` 语法（可嵌套；`#d_{k}#` 这种按变量拼的符号也行）。
每个符号的选择避开最近用过的一半（`cfg.recent_frac`），引擎 RNG 有种子，存读档后结果一致。

表达式是 Godot `Expression`：可用名字 `g`（adapter）、`se`（引擎：`chance/roll/ri/flag/fired/since/now/var_get`）、`ctx`、`SELF`、各角色名。
storylet 里声明过、但这次没绑上的角色在表达式里是 `null`（可以写 `M != null`）。

## 时间单位
引擎里没有“日”：它只认 `adapter.se_now()` 返回的整数“刻”，调用方每走一刻调一次 `tick_due / tick_world / beat`。
包（或单条 storylet）用 `"unit"` 声明时长按什么写（缺省 `"tick"`，即直接是刻）。下面这些都会经 `adapter.se_ticks(n, unit)` 换算成刻，向上取整：
`cooldown`、`actor_cooldown`、`family_gap`、`min_t`/`min_day`、`schedule`/`chain` 的 `in`；`trigger=daily` 的 `p` 视为“每 unit 的概率”，换算成每刻 `1-(1-p)^(1/k)`。
没实现 `se_ticks` 或 unit 与刻相同则一概原样（一刻=1）。
例：青庐 v0.12 一刻=一日、包写 `"unit": "day"`；改成按月走时，只要 `se_now` 返回月序号、`se_ticks(n, "day")` 返回 `n/30.0`，包不用改。
不会自动换算的：表达式里直接比 `se.now()`/`se.since()` 的数字、`op.chance` 的 `p`（每次执行一次，不随时间）、`beat` 的调用频率（由游戏决定）、
adapter 自己的变量（如青庐的 `sbg` 闭关天数）。生平 `age` 一直是“岁”，与刻无关。

## 生平（前尘）
`eng.biography(actor, seed, ctx0)` 依次跑所有 `trigger=bio` 的 storylet，返回 `[[年纪, 句子], ...]`（按年纪排序）。
不动引擎主 RNG、不留“最近用过”的痕迹，同一个人同一个种子永远同一份前尘。

## Web 导出注意
运行期不依赖 RegEx 等可裁模块（vendor/tracery.gd 已改成手写扫描），所以在裁掉 regex 模块的 Web 模板上也能跑；只有 `se_lint.gd`（编辑器 / 命令行工具）用 RegEx，别在游戏运行时加载它。

## 测试
- `tests/storylet_engine_test.gd`（引擎自身，用 examples）
- 游戏侧：青庐的 `tests/saga_test.gd`（lint、每个选项可渲染、多局长跑重复率与覆盖、存读确定性、旧档）

## 许可
引擎代码随青庐仓库；`vendor/tracery.gd` 为 Apache-2.0（GDTracery，Althar93），许可证见 `vendor/LICENSE-GDTracery.txt`。
