# whisperengine

《城中风声》可运行的 Godot 后台框架样例。

## 快速运行
1. 使用 Godot 4.2+ 打开本项目。
2. 运行主场景 `scenes/Main.tscn`。
3. 在输出面板观察：
   - 30秒循环（线索）
   - 3分钟循环（新闻发布）
   - 30分钟循环（城市结构变化）

## 核心脚本
- `scripts/autoload/GameDB.gd`
- `scripts/autoload/SimulationManager.gd`

## 设计文档
- `docs/godot_backend_plan_zh.md`
