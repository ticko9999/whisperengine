extends Node
class_name GameDB

const FACTIONS := ["媒体", "警方", "黑帮", "企业", "粉丝团", "政务"]
const JOBS := ["明星", "警察", "黑帮打手", "企业高管", "记者", "市民", "博主"]
const CHANNELS := ["社交媒体", "街头传闻", "电视媒体"]

var npcs: Dictionary = {}
var news_pool: Array[Dictionary] = []
var clues_pool: Array[Dictionary] = []
var city_state := {
	"chaos": 20.0,
	"police_trust": 55.0,
	"market_confidence": 60.0,
	"gang_power": 35.0,
	"media_reputation": 50.0,
	"day": 1
}

func reset_runtime() -> void:
	npcs.clear()
	news_pool.clear()
	clues_pool.clear()
	city_state = {
		"chaos": 20.0,
		"police_trust": 55.0,
		"market_confidence": 60.0,
		"gang_power": 35.0,
		"media_reputation": 50.0,
		"day": 1
	}

func clamp_city_values() -> void:
	for key in city_state.keys():
		if city_state[key] is float:
			city_state[key] = clamp(city_state[key], 0.0, 100.0)
