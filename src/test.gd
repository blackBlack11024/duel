extends Node
# 自動測試：godot --path . -- --test <mode> [args]
#   parse           載入所有腳本
#   sim <boss> <skill> <n>   無頭模擬 n 場，印出勝率與時間
#   shot <boss> <secs>       截圖到 shots/
const BotS = preload("res://src/bot.gd")
var args: Array
func _ready() -> void:
	args = Array(OS.get_cmdline_user_args())
	var i = args.find("--test")
	var mode = args[i + 1] if args.size() > i + 1 else "parse"
	G.S = G.new_save(); G.S["prompts"] = {"alt": 9, "dodge": 9}; G.S["tut"] = 99 if mode != "hub" else 3
	match mode:
		"parse":
			for f in DirAccess.get_files_at("res://src"):
				if f.ends_with(".gd"):
					var s = load("res://src/" + f)
					print(f, " ", "OK" if s != null and s.can_instantiate() else "FAIL")
			get_tree().quit()
		"sim": _sim(args[i + 2], float(args[i + 3]), int(args[i + 4]))
		"shot": _shot(args[i + 2], float(args[i + 3]))
		"intro":
			first = true; _shot(args[i + 2], float(args[i + 3]))
		"hub": _hubshot()
		"view": _view()
		"net": _net(args[i + 2])

var first = false
func _mk(boss: String) -> Node:
	var f = load("res://src/fight.gd").new(); f.cfg = {"mode": "story", "boss": boss}
	G.S["gate"] = D.ORDER.find(boss); G.S["attempts"][boss] = 0 if first else 3
	add_child(f); return f

func _sim(boss: String, skill: float, n: int) -> void:
	Engine.time_scale = 8.0; Engine.max_fps = 0
	var wins = 0; var times = []
	for k in n:
		var f = _mk(boss)
		var bot = BotS.new(); bot.skill = skill; f.pctrl.bot = bot
		var t = 0.0; var res = "timeout"
		while t < 400.0:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if not is_instance_valid(f) or f.player == null: break
			if f.player.state == f.St.DEAD:
				res = "dead by " + f.player.killer_move; break
			if f.boss.state == f.St.DEAD:
				res = "win"; wins += 1; break
		print("%s #%d: %s t=%.0fs bossbar=%d bosshp=%.0f php=%.0f" % [boss, k, res, t, f.boss.bar_i, f.boss.hp, f.player.hp])
		times.append(t)
		print("   bot: ", bot.stats, " parts_off=", f.boss.parts_off.keys())
		f.over = true; f.busy = true
		remove_child(f); f.queue_free()
		await get_tree().process_frame
	print("RESULT %s skill=%.2f wins=%d/%d" % [boss, skill, wins, n])
	get_tree().quit()

func _shot(boss: String, secs: float) -> void:
	DirAccess.make_dir_absolute("res://shots")
	var f = _mk(boss)
	var bot = BotS.new(); bot.skill = 0.7; f.pctrl.bot = bot
	var marks = [1.5, 3.0, 5.0, 8.0, 12.0, 18.0, 25.0, 35.0, 50.0]
	var t = 0.0; var mi = 0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
		if mi < marks.size() and t >= marks[mi]:
			get_viewport().get_texture().get_image().save_png("res://shots/%s_%02d.png" % [boss, mi]); mi += 1
	get_tree().quit()

func _hubshot() -> void:
	DirAccess.make_dir_absolute("res://shots")
	var h = load("res://src/hub.gd").new(); add_child(h)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("res://shots/hub_0.png")
	for m in ["gun", "rack"]:
		h._open(m)
		if m == "gun":
			h.row_i = 0; h.rows[0]["i"] = 1
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("res://shots/hub_%s.png" % m)
		h._close()
	get_tree().quit()

func _net(role: String) -> void:
	var lo = {"melee": "laoban", "gun": "liukong", "gadget": "", "core": "xiejian", "mods": {}, "extra_flask": 0}
	if role == "host":
		Net.host()
		await Net.peer_joined
	else:
		Net.join(Net.encode("127.0.0.1"))
		await Net.peer_joined
	print(role, " connected")
	var f = load("res://src/fight.gd").new(); f.cfg = {"mode": "versus", "my": lo, "their": lo, "arena": "spillway"}
	add_child(f)
	var bot = BotS.new(); bot.skill = 0.5 if role == "host" else 0.2; f.pctrl.bot = bot
	var t = 0.0
	while t < 40.0:
		await get_tree().create_timer(5.0).timeout
		t += 5.0
		if not is_instance_valid(f): break
		print("%s t=%.0f myhp=%.0f foehp=%.0f wins=%s dist=%.1f state=%d" % [role, t, f.player.hp, f.boss.hp, str(f.wins), f.player.dist_to(f.boss), f.player.state])
	get_tree().quit()

func _view() -> void:
	# 每個場地一張全景
	DirAccess.make_dir_absolute("res://shots")
	for b in D.ORDER:
		var f = _mk(b)
		f.pctrl.locked = true; f.boss.ctrl = null; f.hud.hide_cross = true
		f.player.pitch = 0.22
		for i in 25: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://shots/view_%s.png" % b)
		f.over = true; f.busy = true; remove_child(f); f.queue_free()
		await get_tree().process_frame
	get_tree().quit()
