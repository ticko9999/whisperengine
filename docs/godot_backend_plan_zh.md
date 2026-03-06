# 《城中风声》Godot可运行后台框架（3-6个月独立开发版）

## 1 游戏系统架构

### 1.1 总体架构（ECS-lite + 数据驱动）
- **Presentation层**：UI、地图、时间轴、事件弹窗。
- **Application层**：`SimulationManager` 驱动30秒/3分钟/30分钟三段循环。
- **Domain层**：10个核心系统（新闻、线索、NPC、关系、传播、事件、阵营、媒体成长、真实性、混乱度）。
- **Data层**：JSON/Resource配置 + 存档快照。

### 1.2 为什么推荐 Godot（不是 Unity）
- 1-2人团队开发效率高，脚本热更新快。
- 原生场景与节点组织适合“系统模拟 + UI密集”项目。
- Steam Early Access 所需平台导出链路稳定。

### 1.3 模块划分
- `GameDB`：全局数据仓库（NPC、新闻、线索、城市状态）。
- `SimulationManager`：统一调度器，按Tick触发系统。
- `NarrativeTemplates`（可后续补）：AI关闭时的文本模板。
- `SaveService`（可后续补）：序列化与版本迁移。

---

## 2 技术实现方案

### 2.1 数据结构设计
- **NPC**：`id/job/faction/relations/secrets/emotion/attention_tags/status`
- **News**：`title/content/truth/style/tags/credibility/spread_speed/influence_range/reach/heat`
- **Clue**：`topic/reliability/urgency/source_npc`
- **CityState**：`chaos/police_trust/market_confidence/gang_power/media_reputation/day`

### 2.2 NPC模拟算法（100-300人）
- 每个NPC维护“关注标签 + 情绪状态”。
- 新闻传播时计算 `impact = credibility * influence_range * affinity`。
- `affinity` 来自标签匹配（命中标签增益）。
- 每30分钟进行阵营聚合（如粉丝愤怒均值、黑帮势力变化）。

### 2.3 新闻传播算法
- 每条新闻有三参数：**可信度、传播速度、影响范围**。
- 三渠道传播：社交媒体/街头传闻/电视媒体，不同渠道权重不同。
- `reach += credibility * spread_speed * channel_weight * (1 + chaos)`。
- `heat` 由`reach`增长，进一步反馈至城市混乱度。

### 2.4 城市状态更新算法
- `chaos += heat * (1-truth) * k + tag_bonus`。
- 低警信 -> 黑帮势力增长。
- 高混乱 -> 触发骚动事件。
- 每30分钟聚合一次，形成可感知“阶段变化”。

### 2.5 UI系统设计
- **左栏**：线索池（来源、可靠度、紧急度）。
- **中栏**：编辑器（标题、正文、风格、真实性滑条）。
- **右栏**：城市指标（混乱、警信、黑帮、媒体声誉）+ 热点新闻。
- **底栏**：时间轴（30秒/3分钟/30分钟节点提示）。

### 2.6 存档系统设计
- 存档频率：每日自动 + 手动。
- 结构：`meta + city_state + npcs(diff) + news_recent + event_flags + rng_seed`。
- 保留`save_version`支持字段迁移。

---

## 3 Demo设计（15分钟）

### 3.1 强制包含内容
1. **明星丑闻事件**（开场2分钟内触发）
2. **城市骚动**（混乱度越阈值自动触发）
3. **警方调查**（警信低于阈值触发）

### 3.2 体验节奏
- 0-3分钟：玩家拿到明星线索并发出首条报道。
- 3-8分钟：粉丝情绪飙升，街头冲突增加。
- 8-12分钟：警方公信力受挫，内部调查弹窗。
- 12-15分钟：玩家面临“继续追热点/转向调查”的分支。

### 3.3 成功判定
- 至少发布3条新闻。
- 触发2次城市事件。
- 媒体声誉不低于20（避免直接破产）。

---

## 4 三个月开发计划（周计划）

### 第1-2周
- 建项目骨架、全局状态、Tick调度器。
- 完成NPC随机生成、基础关系网络。
- 可复用资源：Godot UI Theme、开源图标。

### 第3-4周
- 完成线索系统、新闻编辑数据结构。
- 完成新闻真实性与可信度计算。
- 接入模板文本（AI关闭fallback）。

### 第5-6周
- 完成传播系统三渠道算法。
- 完成NPC情绪受新闻影响逻辑。
- 建立城市混乱度与基础事件触发。

### 第7-8周
- 完成阵营系统（粉丝/警方/黑帮/企业）势力结算。
- 完成玩家媒体成长（声誉、受众、广告收益雏形）。
- 加入15分钟Demo脚本事件。

### 第9-10周
- UI可玩化（线索面板、编辑器、城市仪表盘）。
- 存档/读档、每日结算、失败条件。

### 第11周
- 数值平衡（传播速度、混乱阈值、收益衰减）。
- Bug修复、性能测试（300 NPC）。

### 第12周
- Steam EA最小可交付打包：
  - 一张城市地图（抽象化）
  - 3条主事件链
  - 1套新手引导
  - crash日志与反馈入口

---

## 5 示例代码映射
- NPC数据结构：`SimulationManager._generate_npcs`
- 新闻传播算法：`SimulationManager.propagate_news`
- 城市状态更新逻辑：`SimulationManager.update_city_chaos` + `process_city_events`

---

## 6 风险与优化建议

### 主要风险
- **数值爆炸**：混乱度和传播热度容易滚雪球。
- **内容生产压力**：叙事文本量过大。
- **后期性能**：300 NPC全量逐帧运算成本高。

### 对应优化
- 采用“分层更新”：
  - 高频只更新热点NPC，低频更新背景NPC。
- 所有文本系统模板化，AI仅做润色。
- 数值上限和衰减机制（热度衰减、情绪回落、每日重置系数）。
