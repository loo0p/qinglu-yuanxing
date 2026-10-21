#!/bin/bash
# 跑全部分支 × 第5点 × 老龟，输出表格行
echo "分支|第5点|老龟|筑基日|闭关基础|感悟|丹|闭关合计%|余韵|感悟折损|历练日|闭关日|满后等丹日|青芝产|耗|余|干粮余|饥乏|灵石|山村|快|中|慢"
for b in 均衡 偏闭关 偏历练 筑基丹失败 心魔失败; do for e in field shuitian; do for lg in ${LGS:-C B D}; do
LAOGUI=$lg EXTRA=$e python3 sim.py $b >/dev/null || { echo "$b|$e|$lg|卡死"; continue; }
python3 -c "
import json;j=json.load(open('results.json'))[0]
print('|'.join(str(x) for x in ['$b','$e','$lg',j['筑基日'],j['修为来源']['biguan'],j['修为来源']['ganwu'],j['修为来源']['dan'],j['闭关(基础+炼化)占比%'],j['余韵'],j['感悟折损(软上限)'],j['历练日'],j['闭关日'],j['修为满后仍等丹的闭关日'],j['青芝产出'],j['青芝消耗'],j['青芝剩余'],j['干粮剩余'],j['饥乏日'],j['灵石'],j['山村'],j['快读(重35/轻8/重访3秒)'],j['实际时长(分钟)'],j['慢读(重75/轻18/重访6秒)']]))"
done; done; done
