extends Node
# 存檔、輸入設定、進度。
var main
var S: Dictionary = {}
const SAVE = "user://save.json"
var mouse_sens = 0.0022
const ONLINE = false   # 連線對戰暫時關閉。改成 true 會在工棚開出對戰的門。

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_input(); load_save()

func new_save() -> Dictionary:
	return {"gate": 0, "owned": ["laoban", "liukong"], "equip": {"melee": "laoban", "gun": "liukong", "gadget": "", "core": ""},
		"mods": {}, "tune": {}, "quality": {}, "scrap": 30, "fine": 0, "tickets": 2, "tech": [], "cores": [],
		"attempts": {}, "deaths": {}, "pages": [], "prompts": {}, "scrap_got": {}, "ng": 0, "ending": "", "combo_n": 0, "trained": false,
		"opt": {"sens": 1.0, "fov": 95.0, "vol": 0.8, "music": 0.6, "assist_parry": false, "text_hints": false, "bars": false, "no_jam": false, "notebook": true, "fullscreen": false}}

func load_save() -> void:
	S = new_save()
	if FileAccess.file_exists(SAVE):
		var j = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if typeof(j) == TYPE_DICTIONARY:
			for k in j:
				if k == "opt":
					for o in j[k]: S["opt"][o] = j[k][o]
				else: S[k] = j[k]
	apply_opts()

func save() -> void:
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(S))

func opt(k: String): return S["opt"].get(k)

func apply_opts() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001, float(opt("vol")))))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if opt("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED)

func setup_input() -> void:
	var m = {
		"mv_f": [KEY_W], "mv_b": [KEY_S], "mv_l": [KEY_A], "mv_r": [KEY_D],
		"attack": ["m1", "jax5"], "alt": ["m2", "jax4"], "dodge": [KEY_SPACE, "j1"], "switch": [KEY_Q, "j3", "mwheel"],
		"gadget": [KEY_E, "j10"], "core": [KEY_F, "j9"], "core2": [KEY_G, "j12"], "reload": [KEY_R, "j2"], "drink": [KEY_R, "j11"],
		"interact": [KEY_V, "m4", "j8"], "jump": [KEY_CTRL, "j0"], "pause": [KEY_ESCAPE, "j6"], "crouch": [KEY_C, "j7"],
		"em1": [KEY_1], "em2": [KEY_2], "em3": [KEY_3], "em4": [KEY_4],
	}
	for a in m:
		if InputMap.has_action(a): continue
		InputMap.add_action(a, 0.4)
		for k in m[a]:
			var e
			if typeof(k) == TYPE_INT:
				e = InputEventKey.new(); e.physical_keycode = k
			elif k == "m1" or k == "m2" or k == "m4":
				e = InputEventMouseButton.new(); e.button_index = {"m1": MOUSE_BUTTON_LEFT, "m2": MOUSE_BUTTON_RIGHT, "m4": MOUSE_BUTTON_XBUTTON1}[k]
			elif k == "mwheel":
				e = InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_WHEEL_DOWN
			elif k.begins_with("jax"):
				e = InputEventJoypadMotion.new(); e.axis = int(k.substr(3)); e.axis_value = 1.0
			else:
				e = InputEventJoypadButton.new(); e.button_index = int(k.substr(1))
			InputMap.action_add_event(a, e)
	for pair in [["mv_f", JOY_AXIS_LEFT_Y, -1.0], ["mv_b", JOY_AXIS_LEFT_Y, 1.0], ["mv_l", JOY_AXIS_LEFT_X, -1.0], ["mv_r", JOY_AXIS_LEFT_X, 1.0]]:
		var e2 = InputEventJoypadMotion.new(); e2.axis = pair[1]; e2.axis_value = pair[2]; InputMap.action_add_event(pair[0], e2)

# ---- 進度 ----
func boss_id() -> String:
	return D.ORDER[min(int(S["gate"]), 5)]

func equip_stats(slot: String, off: Array = []) -> Dictionary:
	var id = S["equip"][slot]
	if id == "": return {}
	return D.wstats(id, S["mods"].get(id, {}), off, float(S["quality"].get(id, 1.0)))

func hp_max() -> float: return 100.0 + 20.0 * floor(int(S["gate"]) / 2.0)
func stam_max() -> float: return 120.0 if int(S["gate"]) >= 4 else 100.0
func flasks() -> int: return 4 if int(S["gate"]) >= 3 else 3
func flask_heal() -> float: return 45.0 if int(S["gate"]) >= 5 else 35.0

func on_attempt(b: String) -> void:
	S["attempts"][b] = int(S["attempts"].get(b, 0)) + 1; save()

func on_death(b: String, move: String) -> Array:
	# 回傳新解鎖的筆記頁
	var d = S["deaths"].get(b, {}); d[move] = int(d.get(move, 0)) + 1; S["deaths"][b] = d
	var got = int(S["scrap_got"].get(b, 0))
	if got < 70: S["scrap"] = int(S["scrap"]) + 12; S["scrap_got"][b] = got + 12
	var new_pages = []
	var need = 1 if opt("text_hints") else 2
	for pid in D.PAGES:
		var p = D.PAGES[pid]
		if p["boss"] == b and p["move"] == move and int(d[move]) >= need and not S["pages"].has(pid):
			S["pages"].append(pid); new_pages.append(pid)
	save(); return new_pages

func on_win(b: String) -> void:
	var i = D.ORDER.find(b)
	if i >= int(S["gate"]): S["gate"] = i + 1
	S["scrap"] = int(S["scrap"]) + 80; S["fine"] = int(S["fine"]) + 2; S["tickets"] = int(S["tickets"]) + 3
	var dr = D.BOSS[b]["drops"]
	for k in dr:
		if k == "core":
			if not S["cores"].has(dr[k]): S["cores"].append(dr[k])
		elif not S["owned"].has(dr[k]): S["owned"].append(dr[k])
	if D.TECH.has(b) and not S["tech"].has(D.TECH[b]): S["tech"].append(D.TECH[b])
	save()

func unlock_page(pid: String) -> bool:
	if S["pages"].has(pid): return false
	S["pages"].append(pid); save(); return true

func can_afford(p: Dictionary) -> bool:
	return int(S["scrap"]) >= int(p.get("c", 0)) and int(S["fine"]) >= int(p.get("f", 0)) and int(S["tickets"]) >= int(p.get("t", 0))

func pay(p: Dictionary) -> void:
	S["scrap"] = int(S["scrap"]) - int(p.get("c", 0)); S["fine"] = int(S["fine"]) - int(p.get("f", 0)); S["tickets"] = int(S["tickets"]) - int(p.get("t", 0))

func font() -> Font:
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans CJK TC", "Microsoft JhengHei", "PingFang TC", "Heiti TC", "Noto Sans TC", "WenQuanYi Zen Hei", "sans-serif"])
	f.font_weight = 700
	return f
