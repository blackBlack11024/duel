extends "res://src/fight.gd"
# 結局：站在閘輪前，轉哪個輪子由玩家決定。沒有選項框。
var which = ""
var marks = []
var done = false

func _ready() -> void:
	Fx.root = self; Fx.pools.clear(); Fx.net_safe = false
	story = true; bid = "zha"; bcfg = D.BOSS["zha"]; cfg = {"mode": "story", "boss": "zha"}
	arena = ArenaS.new(); add_child(arena); arena.build("cistern", self); arena.water_level = 2
	_spawn_player(); player.global_position = Vector3(0, 0, -8)
	boss = null
	hud = HudS.new(); add_child(hud); hud.pl = player; hud.cam = pctrl.cam; hud.hide_cross = true
	hud.pause_choice.connect(_pause_choice)
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Snd.music("mus_final"); Snd.ambience("amb_water", -8.0)
	# 小輪＝開一道；大輪＝開全閘；身後的門＝不開，走出去
	marks = [{"id": "one", "pos": Vector3(-3.5, 1.3, -16.2)}, {"id": "all", "pos": arena.wheel_pos}, {"id": "none", "pos": Vector3(0, 1.4, 16.2)}]
	M.cyl(arena, 0.45, 0.1, marks[0]["pos"], M.rust(Color(0.3, 0.4, 0.45)), Vector3(90, 0, 0), -1.0, 12)
	M.box(arena, Vector3(2.2, 3.2, 0.2), Vector3(0, 1.6, 16.4), M.rust(Color(0.2, 0.2, 0.2))); arena._lamp(Vector3(0, 3.6, 15.6), Color(1, 0.9, 0.7), 2.0, 6)

func _process(d: float) -> void:
	t += d
	if Input.is_action_just_pressed("pause") and not hud.paused: hud.set_pause(true)
	if done: return
	var near = null
	for m in marks:
		if player.eye().distance_to(m["pos"]) < 3.2: near = m
	hud.prompt("interact" if near else "", near["pos"] if near else null)
	if near and Input.is_action_just_pressed("interact"): _choose(near["id"])

func _choose(id: String) -> void:
	done = true; pctrl.locked = true; hud.prompt("")
	Snd.play("gate", 3.0); Fx.add_shake(0.8)
	match id:
		"one":
			await get_tree().create_timer(2.0).timeout
			arena.water_level = 1
			hud.say("", "三號井有水，一季。", 4.0)
			await get_tree().create_timer(4.5).timeout
			hud.say("", "下一季，落閘照常。", 4.0)
		"all":
			Snd.play("explosion", 0.0, 0.5); Fx.add_shake(1.5)
			await get_tree().create_timer(2.0).timeout
			arena.water_level = 0
			hud.say("", "水沖下去。每一口井都有，一季。", 4.5)
			await get_tree().create_timer(5.0).timeout
			hud.say("", "之後沒有了。壩底也沒有了。", 4.0)
		"none":
			Snd.play("step_water", 4.0, 0.6)
			await get_tree().create_timer(2.0).timeout
			hud.say("", "鑰匙沉下去了。", 3.5)
			await get_tree().create_timer(4.0).timeout
			say("喇叭嫂", "laba", "收攤啦。今天沒人領錢。")
	await get_tree().create_timer(5.0).timeout
	Snd.music("")
	hud.title("", "落閘", 4.0)
	await get_tree().create_timer(5.0).timeout
	G.S["ending"] = id; G.S["ng"] = int(G.S.get("ng", 0)) + 1; G.S["gate"] = 0; G.S["attempts"] = {}; G.S["scrap_got"] = {}
	G.save(); G.main.go("hub")
