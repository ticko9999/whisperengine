extends Node
class_name SimulationManager

# 30秒循环（此处用1秒代替）
const TICK_SECONDS := 1.0
const CLUE_CYCLE_TICKS := 1      # 30秒
const NEWS_CYCLE_TICKS := 6      # 3分钟
const STRUCTURE_CYCLE_TICKS := 60 # 30分钟

var tick: int = 0
var run_seed: int = 0
var queued_news: Array[Dictionary] = []

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = TICK_SECONDS
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_on_tick)
	add_child(timer)

func start_new_run(seed: int = -1) -> void:
	run_seed = seed if seed >= 0 else Time.get_unix_time_from_system()
	seed(run_seed)
	GameDB.reset_runtime()
	_generate_npcs(140)
	print("新档已创建，seed=", run_seed, "，NPC=", GameDB.npcs.size())

# ---- 1) 新闻系统 ----
func create_news(title: String, content: String, truth: float, style: String, tags: Array[String], source_id: int) -> Dictionary:
	var news := {
		"id": "%s_%d" % [style, Time.get_ticks_msec()],
		"title": title,
		"content": content,
		"truth": clamp(truth, 0.0, 1.0),
		"style": style, # 真实新闻/夸张新闻/假新闻/调查报道
		"tags": tags,
		"source_id": source_id,
		"credibility": 0.5,
		"spread_speed": 0.5,
		"influence_range": 0.5,
		"reach": 0.0,
		"heat": 20.0,
		"age": 0
	}
	news.credibility = _calc_news_credibility(news)
	news.spread_speed = _calc_spread_speed(news)
	news.influence_range = _calc_influence_range(news)
	return news

# ---- 2) 线索系统 ----
func collect_clue(npc_id: int) -> Dictionary:
	var npc: Dictionary = GameDB.npcs.get(npc_id, {})
	if npc.is_empty():
		return {}
	var clue := {
		"id": "clue_%d" % Time.get_ticks_msec(),
		"npc_id": npc_id,
		"topic": npc.secrets.pick_random(),
		"reliability": randf_range(0.4, 0.95),
		"urgency": randf_range(0.2, 1.0)
	}
	GameDB.clues_pool.append(clue)
	return clue

# ---- 3) 城市NPC模拟系统 ----
func _generate_npcs(count: int) -> void:
	for i in count:
		var npc := {
			"id": i,
			"name": "NPC_%03d" % i,
			"job": GameDB.JOBS.pick_random(),
			"faction": GameDB.FACTIONS.pick_random(),
			"relations": {},
			"secrets": _generate_secrets(),
			"emotion": {
				"anger": randf_range(10, 50),
				"fear": randf_range(10, 40),
				"trust_media": randf_range(20, 80)
			},
			"attention_tags": _pick_attention_tags(),
			"status": "idle"
		}
		GameDB.npcs[i] = npc
	_build_relations()

func _build_relations() -> void:
	for id in GameDB.npcs.keys():
		for _j in 3:
			var target := randi_range(0, GameDB.npcs.size() - 1)
			if target == id:
				continue
			GameDB.npcs[id].relations[target] = randf_range(-1.0, 1.0)

# ---- 4) 社会关系系统 ----
func update_relationships_from_news(news: Dictionary) -> void:
	for npc in GameDB.npcs.values():
		if "明星" in news.tags and npc.faction == "粉丝团":
			npc.relations[news.source_id] = npc.relations.get(news.source_id, 0.0) - 0.2
		if "警方" in news.tags and npc.faction == "黑帮":
			npc.relations[news.source_id] = npc.relations.get(news.source_id, 0.0) - 0.15

# ---- 5) 传播系统 ----
func propagate_news(news: Dictionary) -> void:
	var channel_weights := {
		"社交媒体": 1.0,
		"街头传闻": 0.7,
		"电视媒体": 0.5
	}
	for channel in GameDB.CHANNELS:
		var gain := news.credibility * news.spread_speed * channel_weights[channel]
		gain *= (1.0 + GameDB.city_state.chaos / 100.0)
		news.reach += gain
	_apply_news_to_npcs(news)
	news.heat = clamp(news.heat + news.reach * 0.6, 0.0, 100.0)

func _apply_news_to_npcs(news: Dictionary) -> void:
	for npc in GameDB.npcs.values():
		var affinity := 0.1
		for t in news.tags:
			if t in npc.attention_tags:
				affinity += 0.3
		var impact := news.credibility * news.influence_range * affinity
		npc.emotion.anger = clamp(npc.emotion.anger + impact * 12.0, 0.0, 100.0)
		npc.emotion.fear = clamp(npc.emotion.fear + impact * 8.0, 0.0, 100.0)
		npc.emotion.trust_media = clamp(npc.emotion.trust_media + (news.truth - 0.5) * 10.0, 0.0, 100.0)

# ---- 6) 城市事件系统 ----
func process_city_events() -> void:
	if GameDB.city_state.chaos > 65.0:
		_emit_event("城市骚动", "街区爆发冲突，商业区关闭。")
	if GameDB.city_state.police_trust < 35.0:
		_emit_event("警方调查", "内部调查启动，执法效率下降。")
	if GameDB.city_state.gang_power > 70.0:
		_emit_event("黑帮扩张", "灰色产业链控制更多地盘。")

func _emit_event(event_name: String, desc: String) -> void:
	print("[事件]", event_name, "-", desc)

# ---- 7) 阵营系统 ----
func resolve_faction_power_shift() -> void:
	var fan_mood := _average_emotion_by_faction("粉丝团", "anger")
	if fan_mood > 55.0:
		GameDB.city_state.chaos += 6.0
	if GameDB.city_state.police_trust < 40.0:
		GameDB.city_state.gang_power += 4.0

# ---- 8) 玩家媒体成长系统 ----
func update_media_growth(news: Dictionary) -> void:
	var growth := news.reach * news.credibility * 0.8
	GameDB.city_state.media_reputation += growth * 0.2
	GameDB.city_state.media_reputation -= (1.0 - news.truth) * 4.0

# ---- 9) 新闻真实性系统 ----
func _calc_news_credibility(news: Dictionary) -> float:
	var style_modifier := {
		"真实新闻": 0.2,
		"夸张新闻": -0.1,
		"假新闻": -0.3,
		"调查报道": 0.3
	}
	return clamp(news.truth + style_modifier.get(news.style, 0.0), 0.05, 0.98)

# ---- 10) 城市混乱度系统 ----
func update_city_chaos(news: Dictionary) -> void:
	var delta := news.heat * (1.0 - news.truth) * 0.08
	if "明星" in news.tags:
		delta += 2.0
	if "警方" in news.tags:
		delta += 3.0
	GameDB.city_state.chaos += delta
	GameDB.clamp_city_values()

# ---- 核心循环 ----
func _on_tick() -> void:
	tick += 1
	if tick % CLUE_CYCLE_TICKS == 0:
		var clue := collect_clue(randi_range(0, GameDB.npcs.size() - 1))
		if not clue.is_empty() and randf() > 0.55:
			var generated_news := create_news(
				"匿名爆料：%s" % clue.topic,
				"根据线索指向，相关人物可能涉及%s" % clue.topic,
				clue.reliability,
				"夸张新闻",
				[_topic_to_tag(clue.topic)],
				clue.npc_id
			)
			queued_news.append(generated_news)

	if tick % NEWS_CYCLE_TICKS == 0 and not queued_news.is_empty():
		var news: Dictionary = queued_news.pop_front()
		propagate_news(news)
		update_relationships_from_news(news)
		update_media_growth(news)
		update_city_chaos(news)
		GameDB.news_pool.append(news)
		print("[新闻发布]", news.title, " | 触达=", snapped(news.reach, 0.01), " | 混乱=", snapped(GameDB.city_state.chaos, 0.01))

	if tick % STRUCTURE_CYCLE_TICKS == 0:
		resolve_faction_power_shift()
		process_city_events()
		GameDB.city_state.day += 1
		print("--- Day", GameDB.city_state.day, "城市状态:", GameDB.city_state)

func inject_demo_event_star_scandal() -> void:
	var demo_news := create_news(
		"顶流明星深夜丑闻曝光",
		"偷拍视频显示其团队涉嫌操控粉丝应援资金。",
		0.72,
		"调查报道",
		["明星", "警方", "企业"],
		0
	)
	queued_news.push_front(demo_news)

func _calc_spread_speed(news: Dictionary) -> float:
	return clamp(0.4 + news.truth * 0.35 + news.tags.size() * 0.05, 0.1, 1.0)

func _calc_influence_range(news: Dictionary) -> float:
	return clamp(0.35 + news.credibility * 0.5, 0.15, 1.0)

func _average_emotion_by_faction(faction: String, key: String) -> float:
	var total := 0.0
	var count := 0.0
	for npc in GameDB.npcs.values():
		if npc.faction == faction:
			total += npc.emotion.get(key, 0.0)
			count += 1.0
	return 0.0 if count == 0 else total / count

func _generate_secrets() -> Array[String]:
	var pool := [
		"明星代言回扣",
		"警方受贿名单",
		"黑帮地盘交易",
		"企业财务造假",
		"政务人员亲属输送"
	]
	pool.shuffle()
	return pool.slice(0, 2)

func _pick_attention_tags() -> Array[String]:
	var tags := ["明星", "警方", "黑帮", "企业", "政务"]
	tags.shuffle()
	return tags.slice(0, 2)

func _topic_to_tag(topic: String) -> String:
	if topic.find("明星") >= 0:
		return "明星"
	if topic.find("警方") >= 0:
		return "警方"
	if topic.find("黑帮") >= 0:
		return "黑帮"
	if topic.find("企业") >= 0:
		return "企业"
	return "政务"
