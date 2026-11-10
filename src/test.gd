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
	G.S = G.new_save(); G.S["prompts"] = {"alt": 9, "dodge": 9}
	match mode:
		"parse":
			for f in DirAccess.get_files_at("res://src"):
				if f.ends_with(".gd"):
					var s = load("res://src/" + f)
					print(f, " ", "OK" if s != null and s.can_instantiate() else "FAIL")
			get_tree().quit()
		"sim": _sim(args[i + 2], float(args[i + 3]), int(args[i + 4]))
		"shot": _shot(args[i + 2], float(args[i + 3]))
		"hub": _hubshot()

func _mk(boss: String) -> Node:
	var f = load("res://src/fight.gd").new(); f.cfg = {"mode": "story", "boss": boss}
	G.S["gate"] = D.ORDER.find(boss); G.S["attempts"][boss] = 3
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
	G.main.go("hub")
