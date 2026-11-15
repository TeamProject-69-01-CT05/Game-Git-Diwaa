class_name LevelDataLoader
extends RefCounted

## ตัวโหลดข้อมูลด่าน (Level Data Loader)
## อ่านข้อมูลจาก res://features/dialogue/levels/level_%02d.gd (static func get_data())
## ใช้ร่วมกันระหว่างหน้าบทสนทนา, หน้าเลือกด่าน, Sandbox และหน้าสรุปผลด่าน

const LEVEL_PATH_FORMAT := "res://features/dialogue/levels/level_%02d.gd"


static func get_level_path(level_num: int) -> String:
	return LEVEL_PATH_FORMAT % level_num


static func has_level(level_num: int) -> bool:
	return ResourceLoader.exists(get_level_path(level_num))


## คืนค่าข้อมูลด่าน หรือ Dictionary ว่างถ้าไม่มีไฟล์ข้อมูล
static func load_data(level_num: int) -> Dictionary:
	var path := get_level_path(level_num)
	if not ResourceLoader.exists(path):
		return {}
	var script = load(path)
	if script and script.has_method("get_data"):
		return script.get_data()
	return {}


## นิยามภารกิจของ "ขั้นเล่นจริง" (คีย์ "gameplay" ในไฟล์ข้อมูลด่าน) หรือ {} ถ้าด่านนั้นยังไม่มีขั้นนี้
static func get_gameplay_step(level_num: int, step: int) -> Dictionary:
	var gameplay: Dictionary = load_data(level_num).get("gameplay", {})
	return gameplay.get(step, {})


static func get_gameplay_step_count(level_num: int) -> int:
	return load_data(level_num).get("gameplay", {}).size()


static func has_gameplay(level_num: int, step: int) -> bool:
	return not get_gameplay_step(level_num, step).is_empty()


## รายการสไลด์สาธิตคำสั่งสำหรับหน้าต่าง Command Summary & Demonstration Modal
static func get_demonstration_slides(level_num: int, step: int = 1) -> Array:
	var data := load_data(level_num)
	if data.has("demonstration"):
		var demo = data["demonstration"]
		if demo is Array:
			return demo
		elif demo is Dictionary and demo.has(step):
			var step_demo = demo[step]
			if step_demo is Array:
				return step_demo
	return []


## ชื่อคำสั่งหลักของด่าน สำหรับแสดงบนการ์ดเลือกด่านและหน้าสรุปผล
static func get_display_command(level_num: int, data: Dictionary = {}) -> String:
	if data.is_empty():
		data = load_data(level_num)
	if data.has("commands") and data["commands"].size() > 0:
		return str(data["commands"][0]).replace("--", "")
	if data.has("title"):
		return str(data["title"])
	return "git version" if level_num == 1 else "git command"

