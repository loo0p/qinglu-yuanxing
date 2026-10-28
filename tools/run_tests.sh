#!/bin/sh
# 一键：无头规则测试 + 江湖指标 + UI 冒烟 + 乱点试玩 + Web 导出（release=玩家版，debug=带调试钩子，只给截图）
# Godot 路径可用环境变量 GODOT 覆盖
set -e
G=${GODOT:-/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64}
cd "$(dirname "$0")/.."
$G --headless --path . --import >/dev/null 2>&1 || true
timeout 300 $G --headless --path . -s res://tests/run_tests.gd
timeout 300 $G --headless --path . -s res://tests/world_test.gd
timeout 300 $G --headless --path . -s res://tests/ui_smoke.gd
timeout 300 $G --headless --path . -s res://tests/agency_test.gd
timeout 300 $G --headless --path . -s res://tests/meddle_test.gd
timeout 300 $G --headless --path . -s res://tests/travel_test.gd
timeout 300 $G --headless --path . -s res://tests/storylet_engine_test.gd
timeout 600 $G --headless --path . -s res://tests/saga_test.gd
timeout 300 $G --headless --path . -s res://tests/play_random.gd
mkdir -p build/web build/web_debug
$G --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1
$G --headless --path . --export-debug "Web" build/web_debug/index.html >/dev/null 2>&1 || true
mkdir -p build/web/audio build/web_debug/audio && cp web_audio/*.ogg build/web/audio/ && cp web_audio/*.ogg build/web_debug/audio/
for d in build/web build/web_debug; do mkdir -p $d/portrait && cp -r web_portrait/. $d/portrait/ && rm -rf $d/portrait/.gdignore $d/portrait/feat; done
python3 tools/precompress.py build/web || true
echo "导出完成：build/web/（玩家版） build/web_debug/（调试版）"
