#!/bin/sh
# 候选代码·灰盒：一键跑无头测试 + UI 冒烟 + Web 导出
set -e
G=/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64
cd "$(dirname "$0")/.."
$G --headless --path . --import >/dev/null 2>&1 || true
timeout 300 $G --headless --path . -s res://tests/run_tests.gd
timeout 300 $G --headless --path . -s res://tests/ui_smoke.gd
$G --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1
echo "导出完成：build/web/"
