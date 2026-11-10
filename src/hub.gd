extends "res://src/fight.gd"
# 工棚：可以走動的據點。工作檯、鍛爐、調校台、武器架、筆記本、收音機、兩扇門、訓練樁。
const Icons = preload("res://src/icons.gd")
const WM = preload("res://src/wm.gd")
var arg = null
var stations = []            # {id, pos}
var ui: Control
var mode = ""                # 開啟中的介面
var rows = []                # [{key, label, opts:[{id,name,...}], i}]
var row_i = 0
var preview: Node3D
var font: Font
var forge = {}               # 鍛造小遊戲狀態
var pending = {}             # 鍛造完成後要套用的變更
var lobby = {"state": "menu", "code": [], "entry": [], "mode": 0, "pts": 10, "their": null, "ready": false}
var near = ""
var page_i = 0
var held_t = 0.0

func _ready() -> void:
	Fx.root = self; Fx.pools.clear(); Fx.net_safe = false
	story = true; bid = "dummy"; bcfg = D.DUMMY; cfg = {"mode": "story", "boss": "dummy"}
	font = G.font()
	arena = ArenaS.new(); add_child(arena); arena.build("hub", self)
	_room()
	_spawn_player()
	player.global_position = Vector3(0, 0, 3.5)
	_spawn_boss()
	boss.global_position = Vector3(3.5, 0, -2.0); ai.tutorial = false
	hud = HudS.new(); add_child(hud); hud.pl = player; hud.foe = null; hud.cam = pctrl.cam
	hud.pause_choice.connect(_pause_choice)
	ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(ui); ui.draw.connect(_draw_ui)
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Snd.music("mus_hub"); Snd.ambience("amb_fire", -18.0)
	Net.got.connect(_on_lobby_net); Net.peer_joined.connect(_on_joined)
	if typeof(arg) == TYPE_DICTIONARY and arg.get("lobby", false) and Net.active: _open("lobby")
	for it in [["crate", Vector3(-2.5, 0, 5.2)], ["crate", Vector3(-3.4, 0, 5.0)], ["pot", Vector3(6.3, 0, -3.0)], ["pot", Vector3(6.0, 0, -3.8)], ["barrel", Vector3(1.8, 0, 5.3)], ["planks", Vector3(-1.0, 0, -5.6)]]:
		spawn_prop(it[0], it[1], randf() * TAU if it[0] != "planks" else 0.0)
	tut_i = int(G.S.get("tut", 0))
	if tut_i == 0: _opening()
	else: tut_ready = true

# ---------------- 教學 ----------------
var tut_i = 0
var tut_ready = false
var flags = {}
var tut_hold = 0.0
var start_pos = Vector3.ZERO
const TUT = [
	["WASD 移動，滑鼠看四周。走到木樁前面。", "near"],
	["按【左鍵】揮擊。打木樁幾下。", "light"],
	["【按住左鍵】蓄力，放開是重擊。重擊最能打亂對手的架勢。", "heavy"],
	["木樁晃得越厲害，架勢越快崩。把它打到跪下，靠近按【V】處決。\n處決會直接打掉對手一整條護板。", "exec"],
	["按【空白鍵】閃避。閃的那一下是無敵的。", "dodge"],
	["按【Q】換成槍，【左鍵】開槍，【右鍵】瞄準。打木樁一槍。", "shot"],
	["拿槍時按【R】裝填。再按【Q】換回近戰。", "back"],
	["【按住右鍵】格擋，擋的時候會扣體力。試著按住。", "block"],
	["彈反：對手打到你的前一瞬間才按右鍵。不扣體力，還能拿到一格扳手。\n扳手集滿後，在對手出招時按【F】可以拆掉他的零件。（按 V 繼續）", "ok"],
	["對手武器發【紅光】的招擋不住，只能閃。\n受傷了，拿近戰武器時按【R】喝水。（按 V 繼續）", "ok"],
	["牆邊的檯子可以改裝武器。忘了怎麼玩，按【Esc】看操作說明。\n準備好就走進亮藍燈的門。", "end"],
]

func _opening() -> void:
	pctrl.locked = true
	for ln in ["大旱第四十年。只剩這座壩裡還有水。", "每一季，各個聚落派一個人下到壩底，一對一打。\n贏一場，開一道閘，水歸贏家的聚落。", "三號井上一季派的是你師傅。他死在第三閘。\n這一季沒人肯去。你去了。"]:
		hud.say("", ln, 4.6)
		var tt = 0.0
		while tt < 4.8:
			await get_tree().process_frame
			tt += get_process_delta_time()
			if tt > 0.5 and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")): break
	hud.say("", "", 0.1)
	pctrl.locked = false; tut_ready = true; start_pos = player.global_position

func _tut_tick(d: float) -> void:
	if not tut_ready or tut_i >= TUT.size():
		hud.tut.text = ""; return
	var step = TUT[tut_i]
	hud.tut.text = step[0]
	var ok = false
	match step[1]:
		"near": ok = player.dist_to(boss) < 3.2
		"light", "heavy", "exec", "dodge", "shot": ok = flags.get(step[1], false)
		"back": ok = flags.get("reload", false) and player.stance == "melee"
		"block":
			if player.state == St.BLOCK: tut_hold += d
			ok = tut_hold > 0.8
		"ok": ok = Input.is_action_just_pressed("interact")
		"end":
			tut_hold += d; ok = tut_hold > 14.0
	if ok:
		tut_i += 1; flags = {}; tut_hold = 0.0; G.S["tut"] = tut_i; G.save(); Snd.play("pickup", -6.0)

func _st(id: String, pos: Vector3) -> void: stations.append({"id": id, "pos": pos})

func _room() -> void:
	arena.half = Vector2(7, 6)
	M.solid(arena, Vector3(16, 1, 14), Vector3(0, -0.5, 0), M.concrete(Color(0.3, 0.28, 0.26)))
	for w in [[Vector3(1, 5, 14), Vector3(-7.5, 2.5, 0)], [Vector3(1, 5, 14), Vector3(7.5, 2.5, 0)], [Vector3(16, 5, 1), Vector3(0, 2.5, -6.5)], [Vector3(16, 5, 1), Vector3(0, 2.5, 6.5)], [Vector3(16, 1, 14), Vector3(0, 5.5, 0)]]:
		M.solid(arena, w[0], w[1], M.concrete(Color(0.34, 0.31, 0.28)))
	arena.sun.visible = false
	arena.env.background_color = Color(0.02, 0.02, 0.02); arena.env.ambient_light_color = Color(0.6, 0.55, 0.5); arena.env.ambient_light_energy = 0.75; arena.env.fog_density = 0.01
	arena._lamp(Vector3(0, 4.2, 1), Color(1.0, 0.85, 0.65), 4.0, 14, true); arena._lamp(Vector3(-3, 4.2, -3), Color(1.0, 0.85, 0.65), 2.5, 10); arena._lamp(Vector3(3, 4.2, 3.5), Color(1.0, 0.85, 0.65), 2.5, 10)
	# 工作檯（改槍）
	M.solid(arena, Vector3(2.6, 0.9, 0.9), Vector3(-6.2, 0.45, 2.5), M.wood(), Vector3(0, 90, 0))
	M.box(arena, Vector3(0.5, 0.25, 0.3), Vector3(-6.3, 1.05, 3.2), M.iron()); arena._lamp(Vector3(-6.4, 2.2, 2.5), Color(0.9, 0.95, 1.0), 1.6, 5)
	_st("gun", Vector3(-6.2, 1.2, 2.5))
	# 鍛爐
	M.solid(arena, Vector3(1.6, 1.0, 1.6), Vector3(-5.8, 0.5, -4.6), M.concrete(Color(0.2, 0.18, 0.17)))
	M.box(arena, Vector3(1.0, 0.1, 1.0), Vector3(-5.8, 1.02, -4.6), M.glow(Color(1.0, 0.35, 0.05), 3.0)); arena._lamp(Vector3(-5.8, 1.7, -4.6), Color(1.0, 0.45, 0.1), 3.0, 7)
	M.solid(arena, Vector3(0.7, 0.75, 0.4), Vector3(-4.2, 0.37, -4.4), M.iron()); M.cyl(arena, 0.35, 0.7, Vector3(-4.3, 0.35, -5.6), M.rust())
	_st("melee", Vector3(-5.0, 1.2, -4.5))
	# 調校台
	M.solid(arena, Vector3(1.8, 0.9, 0.8), Vector3(0.5, 0.45, -5.8), M.rust(Color(0.3, 0.33, 0.3)))
	for i in 4: M.cyl(arena, 0.06, 0.25, Vector3(-0.1 + i * 0.4, 1.0, -5.8), M.steel())
	_st("tune", Vector3(0.5, 1.2, -5.8))
	# 武器架
	M.solid(arena, Vector3(0.3, 2.2, 3.0), Vector3(-7.0, 1.1, -1.0), M.wood(Color(0.3, 0.2, 0.12)))
	var i2 = 0
	for id in G.S["owned"]:
		var wn = WM.make(id); arena.add_child(wn); wn.position = Vector3(-6.75, 1.9 - (i2 % 3) * 0.6, -2.2 + int(i2 / 3.0) * 0.55)
		wn.rotation_degrees = Vector3(0, 0, 90) if D.wkind(id) == "melee" else Vector3(0, 0, 0); wn.scale = Vector3.ONE * 0.8; i2 += 1
	_st("rack", Vector3(-6.8, 1.3, -1.0))
	# 筆記本
	M.solid(arena, Vector3(1.0, 0.8, 0.7), Vector3(5.8, 0.4, 4.6), M.wood()); M.box(arena, Vector3(0.4, 0.04, 0.3), Vector3(5.8, 0.83, 4.6), M.cloth(Color(0.5, 0.42, 0.3)), Vector3(0, 20, 0))
	_st("notebook", Vector3(5.8, 1.0, 4.6))
	# 收音機（選項）
	M.box(arena, Vector3(0.45, 0.3, 0.2), Vector3(4.2, 1.5, 6.0), M.wood(Color(0.45, 0.3, 0.18))); M.cyl(arena, 0.08, 0.02, Vector3(4.1, 1.5, 5.88), M.iron(), Vector3(90, 0, 0)); M.solid(arena, Vector3(0.8, 1.35, 0.4), Vector3(4.2, 0.67, 6.0), M.rust())
	_st("options", Vector3(4.2, 1.5, 5.9))
	# 往壩底的門
	M.box(arena, Vector3(2.4, 3.4, 0.2), Vector3(4.5, 1.7, -5.95), M.rust(Color(0.25, 0.3, 0.3))); arena._lamp(Vector3(4.5, 3.8, -5.3), Color(0.5, 0.85, 1.0), 2.0, 5)
	var g = int(G.S["gate"])
	for k in 6:
		M.box(arena, Vector3(0.12, 0.5, 0.05), Vector3(3.75 + k * 0.3, 2.6, -5.8), M.glow(Color(0.5, 0.85, 1.0), 2.5) if k < g else M.iron())
	_st("door", Vector3(4.5, 1.6, -5.8))
	# 對戰的門（G.ONLINE 關閉時不蓋）
	if G.ONLINE:
		M.box(arena, Vector3(0.2, 3.0, 2.0), Vector3(6.95, 1.5, 0.5), M.rust(Color(0.4, 0.2, 0.15))); arena._lamp(Vector3(6.4, 3.3, 0.5), Color(1.0, 0.3, 0.2), 1.6, 4)
		for sx in [-0.3, 0.3]: M.cap(arena, 0.12, 0.9, Vector3(6.8, 2.0, 0.5 + sx), M.iron())
		_st("lobby", Vector3(6.8, 1.6, 0.5))

# ---------------- 覆寫 ----------------
func _on_player_ev(n: String, data) -> void:
	match n:
		"dealt":
			if data["out"] != "miss":
				if data["info"]["kind"] == "bullet": flags["shot"] = true
				elif data["info"].get("move", "") == "heavy": flags["heavy"] = true
				elif data["info"].get("move", "") == "light": flags["light"] = true
		"dodge": flags["dodge"] = true
		"reload": flags["reload"] = true
	if n == "dead":
		player.hp = player.hp_max; player.set_state(St.IDLE)
	elif n == "combo" and int(G.S.get("combo_n", 0)) == 5 and G.unlock_page("adv_combo"): hud.show_page(D.PAGES["adv_combo"]["sk"], 5.0)
	elif n in ["parry", "dodge", "disarm_ok", "switch", "drink"]: super._on_player_ev(n, null if n != "disarm_ok" else "spring")
func _on_boss_ev(_n: String, _data) -> void: pass
func start_execution(_att, vic) -> void:
	vic.posture = 0.0; vic.set_state(St.STUN, 1.0); Snd.play("break", 0.0)
	flags["exec"] = true; Fx.add_shake(0.6); Snd.play("hit_flesh", 2.0, 0.7)
	for i in 6: Fx.gib(vic.global_position + Vector3(0, 1.2, 0), Vector3(randf_range(-4, 4), randf_range(2, 6), randf_range(-4, 4)), Vector3(0.2, 0.05, 0.1), M.wood(), 8.0)
	G.S["prompts"]["interact"] = int(G.S["prompts"].get("interact", 0)) + 1
func boss_say(_k: String, _f: bool = false) -> float: return 0.0

func _process(d: float) -> void:
	t += d
	if Input.is_action_just_pressed("pause") and not hud.paused and mode == "": hud.set_pause(true)
	player.hp = min(player.hp_max, player.hp + 20.0 * d); player.flasks = max(player.flasks, 1)
	if not player.gun.is_empty() and player.reserve < 4: player.reserve = int(player.gun["reserve"])
	boss.hp = boss.hp_max
	if mode != "":
		hud.tut.text = ""
		_ui_input(d); ui.queue_redraw(); return
	_tut_tick(d)
	near = ""
	for s in stations:
		var to = s["pos"] - player.eye()
		if to.length() < 3.0 and player.aim_dir().dot(to.normalized()) > 0.75:
			near = s["id"]; hud.prompt("interact", s["pos"]); break
	if near == "":
		_prompts(d)
		if hud.prompt_act == "interact" and boss.state != St.BROKEN: hud.prompt("")
	elif Input.is_action_just_pressed("interact") and not (tut_ready and tut_i < TUT.size() and TUT[tut_i][1] == "ok"): _open(near)
	ui.queue_redraw()

func _open(id: String) -> void:
	Snd.play("ui", 0.0)
	if id == "door":
		G.save()
		if int(G.S["gate"]) >= 6: G.main.go("ending", "choose")
		else: G.main.go("fight", {"mode": "story", "boss": G.boss_id()})
		return
	mode = id; row_i = 0; pctrl.locked = true; player.reset_intent(); hud.prompt(""); hud.hide_cross = true
	pctrl.vm.visible = false; boss.ctrl = null; boss.set_state(St.IDLE); boss.reset_intent()
	_build_rows()

func _close() -> void:
	if mode == "lobby" and Net.active: Net.close()
	mode = ""; pctrl.locked = false; hud.hide_cross = false; _preview(""); G.save()
	pctrl.vm.visible = true; boss.ctrl = ai
	lobby = {"state": "menu", "code": [], "entry": [], "mode": 0, "pts": 10, "their": null, "ready": false}
	_reequip()

func _reequip() -> void:
	player.set_weapons(G.equip_stats("melee"), G.equip_stats("gun"), G.equip_stats("gadget")); player.core2 = G.S["equip"].get("core", "")
	if player.gun.is_empty(): player.stance = "melee"
	pctrl.rebuild_weapons()

func _preview(id: String) -> void:
	if preview and is_instance_valid(preview): preview.queue_free()
	preview = null
	if id == "" or D.CORES.has(id): return
	preview = WM.make(id, {}, G.S["mods"].get(id, {})); pctrl.cam.add_child(preview)
	preview.position = Vector3(-0.62, 0.02 if D.wkind(id) != "melee" else -0.26, -0.95)
	preview.scale = Vector3.ONE * (0.55 if D.wkind(id) == "melee" else 1.0)
	var l = OmniLight3D.new(); l.light_energy = 1.5; l.omni_range = 2.0; preview.add_child(l); l.position = Vector3(0.3, 0.5, 0.6)

func _wid() -> String:
	return G.S["equip"]["gun"] if mode == "gun" else (G.S["equip"]["melee"] if mode == "melee" else G.S["equip"]["gadget"])

func _build_rows() -> void:
	rows = []
	match mode:
		"gun", "melee":
			var id = _wid()
			if id == "": return
			var tbl = D.GUN_PARTS if mode == "gun" else D.MELEE_PARTS
			var cur = G.S["mods"].get(id, {})
			for slot in tbl:
				var opts = tbl[slot]; var ci = 0
				for k in opts.size():
					if opts[k]["id"] == cur.get(slot, "std"): ci = k
				rows.append({"key": slot, "label": D.SLOT_NAMES.get(slot, slot), "opts": opts, "i": ci, "have": ci})
			_preview(id)
		"tune":
			var gid = G.S["equip"]["gadget"]
			if gid == "": return
			var tn = G.S["tune"].get(gid, {})
			for k in 2:
				var o = []
				for v in range(-2, 3): o.append({"id": v, "name": D.GADGETS[gid]["axes"][k]})
				rows.append({"key": ["a", "b"][k], "opts": o, "i": int(tn.get(["a", "b"][k], 0)) + 2, "have": 0})
			_preview(gid)
		"rack":
			for slot in ["melee", "gun", "gadget", "core"]:
				var o2 = []
				var src = {"melee": D.MELEE, "gun": D.GUNS, "gadget": D.GADGETS, "core": D.CORES}[slot]
				if slot != "melee": o2.append({"id": "", "name": "—"})
				for id2 in src:
					if slot == "core":
						if G.S["cores"].has(id2): o2.append({"id": id2, "name": src[id2]["name"]})
					elif G.S["owned"].has(id2): o2.append({"id": id2, "name": src[id2]["name"]})
					elif src[id2].has("price") and int(G.S["gate"]) >= int(src[id2]["gate"]): o2.append({"id": id2, "name": src[id2]["name"], "t": int(src[id2]["price"]), "buy": true})
				var ci2 = 0
				for k in o2.size():
					if o2[k]["id"] == G.S["equip"][slot]: ci2 = k
				rows.append({"key": slot, "label": D.SLOT_NAMES.get(slot, slot), "opts": o2, "i": ci2, "have": ci2})
			_preview(G.S["equip"]["melee"])
		"options":
			for o3 in [["sens", "靈敏度", [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]], ["fov", "視野", [80.0, 90.0, 95.0, 100.0, 110.0]], ["vol", "音量", [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]], ["music", "音樂", [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]],
				["assist_parry", "彈反輔助", [false, true]], ["text_hints", "文字提示", [false, true]], ["bars", "傳統血條", [false, true]], ["no_jam", "關閉卡彈", [false, true]], ["notebook", "筆記本提示", [false, true]], ["fullscreen", "全螢幕", [false, true]], ["reset", "刪除存檔", [false, true]]]:
				var oo = []; var ci3 = 0
				for k in o3[2].size():
					var v2 = o3[2][k]
					oo.append({"id": v2, "name": ("開" if v2 else "關") if typeof(v2) == TYPE_BOOL else str(v2)})
					if o3[0] != "reset" and G.opt(o3[0]) == v2: ci3 = k
				rows.append({"key": o3[0], "label": o3[1], "opts": oo, "i": ci3, "have": ci3})
		"notebook": page_i = 0
		"lobby": _lobby_rows()

func _lobby_rows() -> void:
	rows = []
	if lobby["state"] == "menu":
		rows.append({"key": "host", "label": "開房", "opts": [{"id": 0, "name": ""}], "i": 0, "have": 0})
		rows.append({"key": "join", "label": "加入", "opts": [{"id": 0, "name": ""}], "i": 0, "have": 0})
	elif lobby["state"] == "entry":
		for k in 8:
			var o = []
			for sidx in 16: o.append({"id": sidx, "name": D.SYMS[sidx]})
			rows.append({"key": "sym%d" % k, "label": "", "opts": o, "i": 0, "have": 0})
		rows.append({"key": "go", "label": "連線", "opts": [{"id": 0, "name": ""}], "i": 0, "have": 0})
	elif lobby["state"] == "loadout":
		rows.append({"key": "vmode", "label": "模式", "opts": [{"id": 0, "name": "自選"}, {"id": 1, "name": "原廠"}, {"id": 2, "name": "抽籤"}], "i": lobby["mode"], "have": 0})
		for slot in ["melee", "gun", "gadget", "core"]:
			var src = {"melee": D.MELEE, "gun": D.GUNS, "gadget": D.GADGETS, "core": D.CORES}[slot]
			var o2 = []
			if slot != "melee": o2.append({"id": "", "name": "—", "pt": 0})
			for id in src: o2.append({"id": id, "name": src[id]["name"], "pt": int(src[id]["cost"])})
			rows.append({"key": slot, "label": D.SLOT_NAMES.get(slot, slot), "opts": o2, "i": 0, "have": 0})
		rows.append({"key": "arena", "label": "場地", "opts": [{"id": "spillway", "name": "洩洪道"}, {"id": "gallery", "name": "廊道"}, {"id": "engine", "name": "機房"}, {"id": "silt", "name": "沉砂池"}, {"id": "sluice", "name": "閘室"}, {"id": "cistern", "name": "蓄水廊"}], "i": 0, "have": 0})
		rows.append({"key": "ready", "label": "準備", "opts": [{"id": 0, "name": ""}], "i": 0, "have": 0})
	row_i = min(row_i, max(0, rows.size() - 1))

func _pts_used() -> int:
	var n = 0
	for r in rows:
		if r["key"] in ["melee", "gun", "gadget", "core"]: n += int(r["opts"][r["i"]].get("pt", 0))
	return n

func _my_loadout() -> Dictionary:
	var lo = {"melee": "laoban", "gun": "liukong", "gadget": "", "core": "xiejian", "mods": {}, "extra_flask": 0}
	if lobby["mode"] == 1: return lo
	if lobby["mode"] == 2:
		lo["melee"] = D.MELEE.keys()[randi() % D.MELEE.size()]; lo["gun"] = D.GUNS.keys()[randi() % D.GUNS.size()]
		lo["gadget"] = D.GADGETS.keys()[randi() % D.GADGETS.size()]; lo["core"] = D.CORES.keys()[randi() % D.CORES.size()]; return lo
	for r in rows:
		if r["key"] in ["melee", "gun", "gadget", "core"]: lo[r["key"]] = r["opts"][r["i"]]["id"]
	lo["extra_flask"] = int(max(0, 10 - _pts_used()) / 3.0)
	return lo

func _ui_input(d: float) -> void:
	if not forge.is_empty():
		_forge_tick(d); return
	var back = Input.is_action_just_pressed("alt") or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_cancel")
	if back:
		if mode == "lobby" and lobby["state"] != "menu":
			Net.close(); lobby["state"] = "menu"; lobby["ready"] = false; _lobby_rows(); return
		_close(); return
	if preview: preview.rotation.y += d * 0.8
	if mode == "notebook":
		var n = G.S["pages"].size()
		if n > 0 and (Input.is_action_just_pressed("mv_r") or Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("attack")):
			page_i = (page_i + 1) % n; Snd.play("card", -4.0)
		if n > 0 and (Input.is_action_just_pressed("mv_l") or Input.is_action_just_pressed("ui_left")): page_i = (page_i + n - 1) % n
		return
	if rows.is_empty(): return
	if Input.is_action_just_pressed("mv_b") or Input.is_action_just_pressed("ui_down"):
		row_i = (row_i + 1) % rows.size(); Snd.play("ui", -8.0); _row_changed()
	if Input.is_action_just_pressed("mv_f") or Input.is_action_just_pressed("ui_up"):
		row_i = (row_i + rows.size() - 1) % rows.size(); Snd.play("ui", -8.0); _row_changed()
	var r = rows[row_i]
	var dx = 0
	if Input.is_action_just_pressed("mv_r") or Input.is_action_just_pressed("ui_right"): dx = 1
	if Input.is_action_just_pressed("mv_l") or Input.is_action_just_pressed("ui_left"): dx = -1
	if dx != 0 and r["opts"].size() > 1:
		r["i"] = (r["i"] + dx + r["opts"].size()) % r["opts"].size(); Snd.play("ui", -6.0, 1.3)
		if mode in ["options", "tune"]: _apply(r)
		elif mode == "rack": _preview(r["opts"][r["i"]]["id"])
		elif mode == "lobby" and r["key"] == "vmode": lobby["mode"] = r["i"]
	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"): _apply(r)

func _row_changed() -> void:
	if mode == "rack": _preview(rows[row_i]["opts"][rows[row_i]["i"]]["id"])

func _locked(o: Dictionary) -> bool:
	return o.has("need") and not G.S["tech"].has(o["need"])

func _apply(r: Dictionary) -> void:
	var o = r["opts"][r["i"]]
	match mode:
		"gun", "melee":
			if r["i"] == r["have"]: return
			if _locked(o) or not G.can_afford(o):
				Snd.play("click", 0.0, 0.6); return
			if mode == "melee" and D.FORGE_SLOTS.has(r["key"]):
				pending = {"r": r, "o": o}; _forge_start(); return
			_commit_part(r, o, 1.0)
		"tune":
			var gid = G.S["equip"]["gadget"]; var tn = G.S["tune"].get(gid, {}); tn[r["key"]] = int(o["id"]); G.S["tune"][gid] = tn
		"rack":
			if o.get("buy", false):
				if int(G.S["tickets"]) < int(o["t"]):
					Snd.play("click", 0.0, 0.6); return
				G.S["tickets"] = int(G.S["tickets"]) - int(o["t"]); G.S["owned"].append(o["id"]); Snd.play("pickup", 0.0)
				o.erase("buy"); o.erase("t")
			G.S["equip"][r["key"]] = o["id"]; r["have"] = r["i"]; Snd.play("lever", -2.0)
		"options":
			if r["key"] == "reset":
				if r["i"] == 1:
					G.S = G.new_save(); G.save(); G.main.go("hub")
				return
			G.S["opt"][r["key"]] = o["id"]; r["have"] = r["i"]; G.apply_opts()
		"lobby": _lobby_apply(r)

func _commit_part(r: Dictionary, o: Dictionary, q: float) -> void:
	var id = _wid()
	G.pay(o)
	var ms = G.S["mods"].get(id, {}); ms[r["key"]] = o["id"]; G.S["mods"][id] = ms
	if q != 1.0: G.S["quality"][id] = q
	r["have"] = r["i"]; Snd.play("lever", 0.0); Snd.play("hammer", -6.0)
	_preview(id); G.save()

# ---------------- 鍛造：看火色下錘 ----------------
func _forge_start() -> void:
	forge = {"t": 0.0, "hits": [], "phase": randf() * 3.0, "done_t": -1.0}
	Snd.play("hiss", -8.0, 1.4)

func _heat() -> float:
	return 0.5 + 0.5 * sin(forge["t"] * 2.6 + forge["phase"])

func _forge_tick(d: float) -> void:
	forge["t"] += d
	if forge["done_t"] >= 0:
		forge["done_t"] -= d
		if forge["done_t"] <= 0:
			var acc = 0.0
			for h in forge["hits"]: acc += h
			acc /= 3.0
			var q = 0.95 + 0.1 * acc
			forge = {}
			_commit_part(pending["r"], pending["o"], q); pending = {}
		return
	if Input.is_action_just_pressed("alt") or Input.is_action_just_pressed("pause"):
		forge = {}; pending = {}; return
	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact"):
		# 麥稈黃（0.72 附近）最好
		var a = clamp(1.0 - abs(_heat() - 0.72) / 0.28, 0.0, 1.0)
		forge["hits"].append(a)
		Snd.play("hammer", 2.0, 0.9 + a * 0.3); Fx.add_shake(0.25)
		Fx.sparks(pctrl.cam.global_position + player.aim_dir() * 0.9, Color(1, 0.6 + 0.3 * a, 0.2), int(6 + a * 30), 5.0)
		if forge["hits"].size() >= 3:
			forge["done_t"] = 1.1; Snd.play("hiss", 2.0)

# ---------------- 大廳 ----------------
func _lobby_apply(r: Dictionary) -> void:
	match r["key"]:
		"host":
			lobby["code"] = Net.host()
			if lobby["code"].is_empty():
				Snd.play("click", 0.0, 0.6); return
			lobby["state"] = "wait"; rows = []
		"join":
			lobby["state"] = "entry"; _lobby_rows()
		"go":
			var code = []
			for k in 8: code.append(rows[k]["i"])
			if Net.join(code):
				lobby["state"] = "connecting"; rows = []
			else: Snd.play("click", 0.0, 0.6)
		"ready":
			if lobby["mode"] == 0 and _pts_used() > 10:
				Snd.play("click", 0.0, 0.6); return
			lobby["ready"] = true; lobby["mine"] = _my_loadout(); lobby["arena"] = rows[rows.size() - 2]["opts"][rows[rows.size() - 2]["i"]]["id"]
			Net.send("ready", lobby["mine"]); Snd.play("lever", 0.0)
			_try_start()

func _on_joined() -> void:
	if mode != "lobby": return
	lobby["state"] = "loadout"; _lobby_rows(); Snd.play("pickup", 0.0)

func _on_lobby_net(kind: String, data) -> void:
	if not is_inside_tree(): return
	match kind:
		"code":
			if lobby["state"] == "wait": lobby["code2"] = data
		"ready":
			lobby["their"] = data; _try_start()
		"start":
			G.main.go("fight", {"mode": "versus", "my": lobby["mine"], "their": lobby["their"], "arena": data})

func _try_start() -> void:
	if lobby["ready"] and lobby["their"] != null and Net.is_host:
		Net.send("start", lobby["arena"])
		G.main.go("fight", {"mode": "versus", "my": lobby["mine"], "their": lobby["their"], "arena": lobby["arena"]})

func _exit_tree() -> void:
	if Net.got.is_connected(_on_lobby_net): Net.got.disconnect(_on_lobby_net)
	if Net.peer_joined.is_connected(_on_joined): Net.peer_joined.disconnect(_on_joined)
	super._exit_tree()

# ---------------- 繪製 ----------------
func _res(x: float, y: float) -> void:
	var items = [["scrap", int(G.S["scrap"]), Color(0.7, 0.7, 0.7)], ["fine", int(G.S["fine"]), Color(1, 0.8, 0.3)], ["ticket", int(G.S["tickets"]), Color(0.5, 0.85, 1.0)]]
	for i in 3:
		Icons.stat(ui, items[i][0], Vector2(x + i * 120, y), 13, items[i][2])
		ui.draw_string(font, Vector2(x + 22 + i * 120, y + 9), str(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))

func _cost(o: Dictionary, x: float, y: float) -> void:
	var k = 0
	for c in [["c", "scrap", Color(0.7, 0.7, 0.7)], ["f", "fine", Color(1, 0.8, 0.3)], ["t", "ticket", Color(0.5, 0.85, 1.0)]]:
		if int(o.get(c[0], 0)) > 0:
			var ok = int(G.S[{"c": "scrap", "f": "fine", "t": "tickets"}[c[0]]]) >= int(o[c[0]])
			Icons.stat(ui, c[1], Vector2(x + k * 70, y), 9, c[2] if ok else Color(1, 0.2, 0.2))
			ui.draw_string(font, Vector2(x + 14 + k * 70, y + 7), str(int(o[c[0]])), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1) if ok else Color(1, 0.3, 0.3)); k += 1

func _draw_ui() -> void:
	if mode == "": return
	var vs = ui.size
	ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45))
	if not forge.is_empty():
		_draw_forge(vs); return
	if mode == "notebook":
		var r = Rect2(vs.x * 0.5 - 330, vs.y * 0.5 - 250, 660, 500)
		ui.draw_rect(r, Color(0.82, 0.76, 0.62)); ui.draw_rect(r, Color(0.3, 0.25, 0.2), false, 4.0)
		var pg = G.S["pages"]
		if pg.size() > 0 and D.PAGES.has(pg[page_i % pg.size()]):
			Icons.sketch(ui, D.PAGES[pg[page_i % pg.size()]]["sk"], r.grow(-30), font)
			for i in pg.size(): ui.draw_circle(Vector2(vs.x * 0.5 - pg.size() * 9 + i * 18, r.end.y + 24), 5, Color(1, 1, 1) if i == page_i else Color(0.4, 0.4, 0.4))
		return
	var x0 = vs.x * 0.27; var y0 = 90.0
	if mode == "lobby": _draw_lobby(vs)
	for i in rows.size():
		var r2 = rows[i]; var o = r2["opts"][r2["i"]]
		var y = y0 + i * (46 if rows.size() > 9 else 54)
		var sel = i == row_i
		if sel: ui.draw_rect(Rect2(x0 - 16, y - 24, 470, 46), Color(1, 0.8, 0.3, 0.16))
		var col = Color(1, 1, 1) if sel else Color(0.65, 0.65, 0.65)
		var lab = str(r2.get("label", ""))
		if lab != "": ui.draw_string(font, Vector2(x0, y + 9), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
		var nx = x0 + (120 if lab != "" else 0)
		if r2["opts"].size() > 1 and sel:
			ui.draw_string(font, Vector2(nx - 26, y + 9), "‹", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col); ui.draw_string(font, Vector2(nx + 170, y + 9), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
		if mode == "tune":
			ui.draw_string(font, Vector2(x0, y + 9), o["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
			for k in 5: ui.draw_rect(Rect2(x0 + 150 + k * 34, y - 10, 26, 20), Color(1, 0.8, 0.3) if k == r2["i"] else Color(0.3, 0.3, 0.3), true)
			continue
		var name_col = col
		if _locked(o): name_col = Color(0.5, 0.3, 0.3)
		elif r2["i"] == r2["have"] and mode in ["gun", "melee", "rack"]: name_col = Color(1, 0.85, 0.4) if sel else Color(0.8, 0.7, 0.4)
		ui.draw_string(font, Vector2(nx, y + 9), str(o["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, name_col)
		if _locked(o): Icons.stat(ui, "lock", Vector2(nx + 140, y), 9, Color(0.8, 0.3, 0.3))
		elif r2["i"] != r2["have"] or o.get("buy", false): _cost(o, nx + 210, y)
		if o.has("pt"):
			for k in int(o["pt"]): Icons.stat(ui, "ticket", Vector2(nx + 210 + k * 22, y), 8, Color(0.5, 0.85, 1.0))
	if mode in ["gun", "melee", "rack", "tune"]: _res(x0, vs.y - 40)
	_draw_desc(vs, x0)
	if mode in ["gun", "melee"] and not rows.is_empty(): _draw_stats(vs)
	if mode == "rack" and not rows.is_empty():
		var id = rows[row_i]["opts"][rows[row_i]["i"]]["id"]
		if id != "" and not D.CORES.has(id) and D.wkind(id) != "gadget": _draw_stats(vs, id)

func _txt(pos: Vector2, text: String, size: int, col: Color) -> float:
	ui.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.9))
	ui.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# 選中項目的文字說明：這個零件改什麼、要什麼才能裝
func _draw_desc(vs: Vector2, x0: float) -> void:
	if rows.is_empty() or not (mode in ["gun", "melee", "rack", "tune", "lobby"]): return
	var r = rows[row_i]; var o = r["opts"][r["i"]]
	var y = vs.y - 132.0
	ui.draw_rect(Rect2(x0 - 16, y - 34, vs.x - x0 - 20, 76), Color(0, 0, 0, 0.6))
	match mode:
		"gun", "melee":
			var x = x0
			x += _txt(Vector2(x, y), "%s：%s　" % [D.SLOT_NAMES.get(r["key"], ""), o["name"]], 24, Color(1, 0.85, 0.4))
			var eff = D.part_effects(o)
			if eff.is_empty(): _txt(Vector2(x, y), "沒有增減", 22, Color(0.75, 0.75, 0.75))
			for e in eff: x += _txt(Vector2(x, y), e[0] + "　", 22, Color(0.4, 0.95, 0.45) if e[1] else Color(1.0, 0.4, 0.35))
			if _locked(o): _txt(Vector2(x0, y + 32), "需要手藝：" + D.TECH_NAMES.get(o["need"], ""), 20, Color(1.0, 0.45, 0.4))
			elif r["i"] == r["have"]: _txt(Vector2(x0, y + 32), "已裝上", 20, Color(0.7, 0.7, 0.7))
			elif not G.can_afford(o): _txt(Vector2(x0, y + 32), "材料不夠（齒輪＝廢料，太陽＝精件，水滴＝水票）", 20, Color(1.0, 0.45, 0.4))
			elif mode == "melee" and D.FORGE_SLOTS.has(r["key"]): _txt(Vector2(x0, y + 32), "左鍵開始鍛造：燒到麥稈黃時下錘，三次。敲得準，品質越好。", 20, Color(0.85, 0.85, 0.85))
			else: _txt(Vector2(x0, y + 32), "左鍵裝上。綠色是變好，紅色是變差。", 20, Color(0.85, 0.85, 0.85))
		"tune":
			_txt(Vector2(x0, y), o["name"], 24, Color(1, 0.85, 0.4))
			_txt(Vector2(x0, y + 32), D.AXIS_TEXT.split("|")[row_i % 2], 20, Color(0.85, 0.85, 0.85))
		"rack", "lobby":
			var id = str(o["id"])
			if id == "": return
			var key = id + "_core" if (r["key"] == "core" and D.TRAITS.has(id + "_core")) else id
			_txt(Vector2(x0, y), D.wname(id), 24, Color(1, 0.85, 0.4))
			_txt(Vector2(x0, y + 32), D.TRAITS.get(key, ""), 20, Color(0.9, 0.9, 0.9))
			if o.get("buy", false): _txt(Vector2(x0 + 110, y), "（未持有，左鍵用水票買）", 20, Color(0.5, 0.85, 1.0))

func _draw_stats(vs: Vector2, only_id: String = "") -> void:
	var id = only_id if only_id != "" else _wid()
	var kind = D.wkind(id)
	var cur = G.S["mods"].get(id, {}).duplicate(); var cand = cur.duplicate()
	if only_id == "":
		var r = rows[row_i]; cand[r["key"]] = r["opts"][r["i"]]["id"]
	var q = float(G.S["quality"].get(id, 1.0))
	var a = D.wstats(id, cur, [], q); var b = D.wstats(id, cand, [], q); var base = D.wstats(id, {}, [], 1.0)
	var lst = D.GUN_STATS if kind == "gun" else D.MELEE_STATS
	var x = vs.x - 250; var y = 96.0
	for i in lst.size():
		var k = lst[i][0]
		var bv = max(0.001, float(base.get(k, 1.0)))
		var fa = clamp(float(a.get(k, bv)) / bv * 0.5, 0.05, 1.0); var fb = clamp(float(b.get(k, bv)) / bv * 0.5, 0.05, 1.0)
		var yy = y + i * 36
		Icons.stat(ui, lst[i][1], Vector2(x - 150, yy + 6), 10, Color(0.9, 0.9, 0.9))
		_txt(Vector2(x - 132, yy + 13), D.STAT_NAMES.get(k, k), 19, Color(0.9, 0.9, 0.9))
		ui.draw_rect(Rect2(x, yy, 210, 12), Color(0.15, 0.15, 0.15))
		ui.draw_rect(Rect2(x, yy, 210 * min(fa, fb), 12), Color(0.85, 0.85, 0.85))
		if abs(fb - fa) > 0.002:
			var better = (fb > fa) != lst[i][2]
			ui.draw_rect(Rect2(x + 210 * min(fa, fb), yy, 210 * abs(fb - fa), 12), Color(0.3, 0.9, 0.35) if better else Color(0.95, 0.25, 0.2))

func _draw_forge(vs: Vector2) -> void:
	var h = _heat()
	var col = Color(0.25, 0.02, 0.0).lerp(Color(1.0, 0.35, 0.05), clamp(h * 2.0, 0, 1)).lerp(Color(1.0, 0.95, 0.75), clamp(h * 2.0 - 1.0, 0, 1))
	var c = vs * 0.5
	ui.draw_rect(Rect2(c.x - 260, c.y - 26, 520, 52), col)
	ui.draw_colored_polygon(PackedVector2Array([Vector2(c.x + 260, c.y - 26), Vector2(c.x + 340, c.y), Vector2(c.x + 260, c.y + 26)]), col)
	ui.draw_rect(Rect2(c.x - 360, c.y - 12, 100, 24), Color(0.25, 0.18, 0.1))
	# 對照色：麥稈黃
	ui.draw_rect(Rect2(c.x - 30, c.y + 70, 60, 26), Color(1.0, 0.72, 0.3)); ui.draw_rect(Rect2(c.x - 30, c.y + 70, 60, 26), Color(1, 1, 1), false, 2.0)
	for i in 3:
		var done = i < forge["hits"].size()
		ui.draw_circle(Vector2(c.x - 40 + i * 40, c.y - 80), 10, Color(1, 0.8, 0.3).lerp(Color(0.4, 1.0, 0.4), forge["hits"][i]) if done else Color(0.3, 0.3, 0.3))
	if abs(h - 0.72) < 0.1 and forge["done_t"] < 0: Icons.action(ui, "attack", Vector2(c.x, c.y + 150), pctrl.using_pad, 1.2, font, t)

func _draw_lobby(vs: Vector2) -> void:
	var st = lobby["state"]
	if st == "wait":
		var code = lobby.get("code2", lobby["code"])
		for k in code.size():
			var p = Vector2(vs.x * 0.5 - 4 * 74 + k * 74, vs.y * 0.5 - 40)
			ui.draw_rect(Rect2(p, Vector2(64, 76)), Color(0.1, 0.1, 0.1, 0.9)); ui.draw_rect(Rect2(p, Vector2(64, 76)), Color(1, 0.8, 0.3), false, 3.0)
			ui.draw_string(font, p + Vector2(12, 54), D.SYMS[int(code[k])], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1))
		for i in 3: ui.draw_circle(Vector2(vs.x * 0.5 - 20 + i * 20, vs.y * 0.5 + 90), 5, Color(1, 1, 1, 0.3 + 0.7 * float(int(t * 2.0) % 3 == i)))
	elif st == "connecting":
		for i in 3: ui.draw_circle(Vector2(vs.x * 0.5 - 20 + i * 20, vs.y * 0.5), 6, Color(1, 1, 1, 0.3 + 0.7 * float(int(t * 2.0) % 3 == i)))
	elif st == "loadout":
		var used = _pts_used()
		for k in 10: Icons.stat(ui, "ticket", Vector2(vs.x - 320 + k * 26, 120), 10, (Color(0.5, 0.85, 1.0) if used <= 10 else Color(1, 0.2, 0.2)) if k < used else Color(0.25, 0.25, 0.25))
		if lobby["ready"]: ui.draw_circle(Vector2(vs.x - 300, 180), 12, Color(0.4, 1.0, 0.4))
		if lobby["their"] != null: ui.draw_circle(Vector2(vs.x - 260, 180), 12, Color(1.0, 0.4, 0.3))
