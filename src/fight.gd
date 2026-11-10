extends Node3D
# 一場決鬥：故事模式（對 Boss）或連線對戰。也是 combatant 口中的 world。
const Comb = preload("res://src/combatant.gd")
const St = Comb.St
const PlayerS = preload("res://src/player.gd")
const BodyS = preload("res://src/body.gd")
const AiS = preload("res://src/ai.gd")
const ArenaS = preload("res://src/arena.gd")
const HudS = preload("res://src/hud.gd")
const Objs = preload("res://src/objs.gd")
const Cine = preload("res://src/cine.gd")
const M = preload("res://src/mat.gd")

var cfg: Dictionary = {}
var arena
var player
var pctrl
var boss
var body
var ai
var hud
var objs = []
var over = false
var busy = false            # 演出中
var story = true
var bid = ""
var bcfg: Dictionary = {}
var attempt = 1
var said_until = 0.0
var t = 0.0
var prompt_cool = 0.0
var card: Node3D
var net_t = 0.0
var last_net = 0.0
var wins = [0, 0]
var round_t = 90.0
var round_live = false
var their_ready = false
var bot = null              # 測試用：自動操作玩家

func _ready() -> void:
	Fx.root = self; Fx.pools.clear(); Fx.net_safe = cfg.get("mode", "story") == "versus"
	story = cfg.get("mode", "story") == "story"
	arena = ArenaS.new(); add_child(arena)
	if story:
		bid = cfg["boss"]; bcfg = D.BOSS[bid]; arena.build(bcfg["arena"], self)
		attempt = int(G.S["attempts"].get(bid, 0)) + 1; G.on_attempt(bid)
	else: arena.build(cfg.get("arena", "spillway"), self)
	_spawn_player()
	if story: _spawn_boss()
	else: _spawn_remote()
	hud = HudS.new(); add_child(hud); hud.pl = player; hud.foe = boss; hud.cam = pctrl.cam
	hud.pause_choice.connect(_pause_choice)
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Snd.ambience("amb_water" if arena.kind == "cistern" else ("amb_crowd" if arena.kind in ["spillway", "silt"] else "amb_wind"), -16.0)
	if story: _story_start()
	else: _versus_start()

func _spawn_player() -> void:
	player = Comb.new(); player.world = self; player.cname = "pc"; add_child(player); player.setup()
	var side = 1.0
	if not story and not Net.is_host: side = -1.0
	player.global_position = arena.p_spawn if side > 0 else arena.b_spawn
	player.rotation.y = 0.0 if side > 0 else PI
	if story:
		player.hp_max = G.hp_max(); player.stam_max = G.stam_max(); player.flasks = G.flasks(); player.flask_heal = G.flask_heal()
		player.set_weapons(G.equip_stats("melee"), G.equip_stats("gun"), G.equip_stats("gadget"))
		player.core = "xiejian"; player.core2 = G.S["equip"].get("core", "")
	else:
		var my = cfg["my"]
		player.hp_max = 100.0; player.flasks = 1 + int(my.get("extra_flask", 0))
		player.set_weapons(D.wstats(my["melee"], my["mods"].get(my["melee"], {})), D.wstats(my["gun"], my["mods"].get(my["gun"], {})) if my["gun"] != "" else {}, D.wstats(my["gadget"]) if my["gadget"] != "" else {})
		player.core = my.get("core", "")
	player.hp = player.hp_max; player.stam = player.stam_max
	pctrl = PlayerS.new(); player.add_child(pctrl); pctrl.setup(player)
	player.ev.connect(_on_player_ev)

func _spawn_boss() -> void:
	boss = Comb.new(); boss.world = self; boss.is_boss = true; boss.cname = bid; add_child(boss)
	var rp = bcfg["rig"].duplicate(); rp["bars"] = bcfg["bars"].size()
	boss.setup(0.42 * float(rp.get("bulk", 1.0)), float(rp["h"]))
	boss.global_position = arena.b_spawn; boss.rotation.y = PI
	var ng = 1.0 + 0.25 * int(G.S.get("ng", 0))
	boss.bars = []
	for b in bcfg["bars"]: boss.bars.append(float(b) * ng)
	boss.hp = boss.bars[0]; boss.hp_max = boss.hp
	boss.posture_max = float(bcfg["posture"]) * ng; boss.block_chance = float(bcfg["block"]); boss.speed = float(bcfg["speed"])
	boss.melee = {"id": bcfg["melee"], "parry": 0.0, "stab": 0.6}; boss.stam_max = 9999.0; boss.stam = 9999.0
	body = BodyS.new(); boss.add_child(body); body.setup(boss, rp, bcfg["melee"], bcfg["gun"])
	ai = AiS.new(); boss.add_child(ai); ai.setup(boss, bid, self)
	ai.tutorial = bid == "bao" and attempt == 1
	boss.target = player; player.target = boss
	boss.ev.connect(_on_boss_ev)

func _spawn_remote() -> void:
	boss = Comb.new(); boss.world = self; boss.local = false; boss.cname = "foe"; add_child(boss); boss.setup()
	boss.global_position = arena.b_spawn if Net.is_host else arena.p_spawn
	var th = cfg["their"]
	boss.hp_max = 100.0; boss.hp = 100.0
	boss.set_weapons(D.wstats(th["melee"], th["mods"].get(th["melee"], {})), D.wstats(th["gun"], th["mods"].get(th["gun"], {})) if th["gun"] != "" else {}, {})
	body = BodyS.new(); boss.add_child(body)
	body.setup(boss, {"h": 1.8, "bulk": 1.0, "skin": Color(0.62, 0.48, 0.4), "cloth": Color(0.35, 0.25, 0.15), "acc": "pc", "bars": 0}, th["melee"], th["gun"])
	boss.target = player; player.target = boss
	Net.got.connect(_on_net); Net.peer_left.connect(_on_peer_left)

# ---------------- world API ----------------
func combatants() -> Array:
	var a = []
	if player and is_instance_valid(player): a.append(player)
	if boss and is_instance_valid(boss): a.append(boss)
	return a

func ray(from: Vector3, to: Vector3, exclude: Array = [], mask: int = 7) -> Dictionary:
	var q = PhysicsRayQueryParameters3D.create(from, to, mask)
	var ex = []
	for e in exclude:
		if e != null and is_instance_valid(e): ex.append(e.get_rid())
	q.exclude = ex
	var r = get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and r["collider"].has_meta("obj"): r["collider"] = r["collider"].get_meta("obj")
	return r

func muzzle_pos(c) -> Vector3:
	if c == player:
		if pctrl.wm_gun and is_instance_valid(pctrl.wm_gun): return pctrl.wm_gun.get_node("muzzle").global_position if pctrl.wm_gun.has_node("muzzle") else pctrl.wm_gun.global_position
		return player.eye() + player.aim_dir() * 0.5
	return body.muzzle()

func mods_of(c, id: String) -> Dictionary:
	if story: return G.S["mods"].get(id, {}) if c == player else {}
	return cfg["my"]["mods"].get(id, {}) if c == player else cfg["their"]["mods"].get(id, {})

func melee_objects(c, mv: Dictionary) -> void:
	for o in objs.duplicate():
		if not is_instance_valid(o): continue
		var d = o.global_position - c.global_position; d.y = 0
		if d.length() <= float(mv.get("reach", 2.4)) + 0.6 and (d.length() < 0.6 or rad_to_deg(c.fwd().angle_to(d.normalized())) < 70.0):
			o.melee_hit(c, mv)

func shockwave(c, mv: Dictionary) -> void:
	Fx.dust(c.global_position, 30); Fx.add_shake(0.7); Snd.at("explosion", c.global_position, -2.0, 1.5)
	var mi = M.cyl(self, 1.0, 0.05, c.global_position + Vector3(0, 0.05, 0), M.ghost(Color(1, 0.8, 0.5, 0.5)), Vector3.ZERO, -1.0, 24)
	var tw = mi.create_tween(); tw.tween_property(mi, "scale", Vector3(float(mv.get("reach", 3.5)), 1, float(mv.get("reach", 3.5))), 0.25); tw.tween_callback(mi.queue_free)

func explode(pos: Vector3, r: float, dmg: float, post: float, owner_c) -> void:
	Fx.explosion(pos, r)
	for cb in combatants():
		if cb == owner_c and cb.is_boss: continue
		var d = cb.global_position + Vector3(0, 0.9, 0) - pos
		if d.length() > r: continue
		var k = clamp(1.0 - d.length() / r * 0.6, 0.3, 1.0)
		var out = cb.take({"dmg": dmg * k, "post": post * k, "kind": "explosion", "unb": false, "heavy": true, "dir": Vector3(d.x, 0, d.z).normalized(), "move": "lob", "push": 9.0 * k})
		if out == "hit" and cb.is_boss: Fx.gore(cb.global_position + Vector3(0, 1.1, 0), d.normalized(), 5)
	for o in objs.duplicate():
		if is_instance_valid(o) and o.kind in ["grenade", "mine", "hive"] and o.global_position.distance_to(pos) < r * 0.7 and o.global_position.distance_to(pos) > 0.05:
			if o.kind == "hive": o.shot_hit(owner_c if owner_c else player, 40.0)
			else: get_tree().create_timer(0.15).timeout.connect(func(): if is_instance_valid(o): o.detonate())

func _add_obj(o, pos: Vector3, owner_c) -> void:
	o.world = self; o.owner_c = owner_c; o.position = pos; add_child(o); objs.append(o)

func spawn_grenade(owner_c, pos: Vector3, vel: Vector3, dmg: float, post: float, manual: bool):
	var g = Objs.Grenade.new(); g.vel = vel; g.dmg = dmg; g.post = post; g.manual = manual; _add_obj(g, pos, owner_c)
	if owner_c == player and not story: Net.send("spawn", ["grenade", pos, vel, dmg, post, manual])
	return g
func spawn_mine(owner_c, pos: Vector3):
	var m = Objs.Mine.new(); _add_obj(m, Vector3(pos.x, 0, pos.z), owner_c)
	if owner_c == player and not story: Net.send("spawn", ["mine", pos])
	return m
func my_mine(owner_c):
	for o in objs:
		if is_instance_valid(o) and o.kind == "mine" and o.owner_c == owner_c: return o
	return null
func spawn_hive(owner_c, pos: Vector3, life: float):
	var h = Objs.Hive.new(); h.life = life; _add_obj(h, Vector3(pos.x, 0, pos.z), owner_c)
	if owner_c == player and not story: Net.send("spawn", ["hive", pos, life])
	return h
func spawn_smoke(pos: Vector3, r: float, life: float):
	var s = Objs.Smoke.new(); s.radius = r; s.life = life; _add_obj(s, Vector3(pos.x, 0, pos.z), null); return s
func spawn_swarm(owner_c, pos: Vector3, tgt):
	var s = Objs.Swarm.new(); s.tgt = tgt; _add_obj(s, pos, owner_c); return s
func count_obj(kind: String, owner_c) -> int:
	var n = 0
	for o in objs:
		if is_instance_valid(o) and o.kind == kind and o.owner_c == owner_c: n += 1
	return n
func in_smoke(pos: Vector3) -> bool:
	for o in objs:
		if is_instance_valid(o) and o.kind == "smoke" and o.life > 1.0 and Vector2(o.global_position.x - pos.x, o.global_position.z - pos.z).length() < o.radius: return true
	return false

func hook_pull(c, tg, _k: float) -> void:
	var a = muzzle_pos(c); var b = tg.global_position + Vector3(0, 1.1, 0)
	Fx.tracer(a, b, Color(0.8, 0.8, 0.8), 0.03); Snd.at("hook", a, 2.0)
	var r = ray(a, b, [c], 1)
	if not r.is_empty(): return
	var dist = c.dist_to(tg)
	var dir = (tg.global_position - c.global_position); dir.y = 0
	c.deal({"dmg": 5.0, "post": 10.0, "kind": "melee", "unb": false, "heavy": false, "dir": dir.normalized(), "move": "hookpull", "pull": clamp(dist * 1.5, 6.0, 15.0), "stun": 0.45})

func fly_to(c, spot: Vector3) -> void:
	var from = c.global_position
	Fx.tracer(from + Vector3(0, 1.4, 0), spot + Vector3(0, 6, 0), Color(0.8, 0.8, 0.8), 0.03)
	c.set_state(St.CINE)
	var tw = create_tween()
	tw.tween_method(func(u): if is_instance_valid(c): c.global_position = from.lerp(spot, u) + Vector3(0, sin(u * PI) * 3.5, 0), 0.0, 1.0, 0.6)
	tw.tween_callback(func(): if is_instance_valid(c) and c.state == St.CINE: c.set_state(St.IDLE))

func tune(id: String) -> Array:
	var tn = G.S["tune"].get(id, {}) if story else {}
	return [1.0 + 0.12 * float(tn.get("a", 0)), 1.0 + 0.12 * float(tn.get("b", 0))]

func use_gadget(c, id: String) -> void:
	var tn = tune(id) if c == player else [1.0, 1.0]
	var tg = c.target
	match id:
		"huizhi":
			var from = c.eye(); var r = ray(from, from + c.aim_dir() * 18.0 * tn[1], [c])
			Snd.at("hook", from, 0.0)
			if r.is_empty(): return
			Fx.tracer(muzzle_pos(c) if c != player else from + c.aim_dir() * 0.4, r["position"], Color(0.8, 0.8, 0.8), 0.03)
			if r["collider"] == tg:
				var dir = (tg.global_position - c.global_position); dir.y = 0
				c.deal({"dmg": 4.0, "post": 10.0 * tn[0], "kind": "melee", "unb": false, "heavy": false, "dir": dir.normalized(), "move": "hook", "pull": 9.0 * tn[0], "stun": 0.4})
			else:
				var to = r["position"] - c.global_position; c.impulse += Vector3(to.x, 0, to.z).normalized() * min(16.0, to.length() * 1.6); c.velocity.y = clamp(to.y * 1.4, 0, 8.0)
		"shuiba":
			spawn_smoke(c.global_position + c.fwd() * 2.0, 4.5 * tn[1], 8.0 * tn[0])
			if c == player and not story: Net.send("spawn", ["smoke", c.global_position + c.fwd() * 2.0, 4.5 * tn[1], 8.0 * tn[0]])
		"jiadang":
			if tg:
				var s = spawn_swarm(c, c.eye() + c.aim_dir(), tg); s.life = 7.0 * tn[1]
				if c == player and not story: Net.send("spawn", ["swarm", c.eye() + c.aim_dir()])
		"laihui":
			var sw = Objs.Saw.new(); sw.vel = c.aim_dir() * 26.0 * tn[0]; sw.dmg = 26.0 * tn[0]; sw.bounces = 3 + int(round((tn[1] - 1.0) * 8.0)); _add_obj(sw, c.eye() + c.aim_dir() * 0.6, c)
		"jieyixia":
			c.magnet_t = c.clock + 2.5 * tn[1]; Snd.at("zap", c.global_position, -4.0, 0.6); Fx.flash(c.eye(), Color(0.3, 0.6, 1.0), 3.0, 2.5 * tn[1], 5.0)
			if tg and tg.state == St.RELOAD and c.dist_to(tg) < 10.0 * tn[0]:
				tg.reserve = max(0, tg.reserve - int(tg.gun.get("mag", 1))); Snd.at("pickup", c.global_position, 2.0)
		"guodian":
			Snd.at("zap", c.global_position, 2.0); Fx.sparks(c.eye() + c.aim_dir() * 1.2, Color(0.5, 0.8, 1.0), 20, 6.0)
			if tg and c.dist_to(tg) < (3.2 if tg.water == 0 else 6.0) and c.facing(tg, 80.0):
				c.deal({"dmg": 8.0 * tn[0], "post": 18.0 * tn[0], "kind": "melee", "unb": true, "heavy": false, "dir": (tg.global_position - c.global_position).normalized(), "move": "shock", "stun": 0.6 * tn[0]})

# ---------------- 台詞 ----------------
func boss_say(key: String, force: bool = false) -> float:
	if not story or bcfg.is_empty(): return 0.0
	if not force and t < said_until: return 0.0
	var L = bcfg["lines"]
	if bid == "yaling":
		var cards = {"hit": L["hit_cards"], "disarmed": ["等一下"], "parried": ["等一下"]}.get(key, [])
		if cards.is_empty(): return 0.0
		return show_card(cards[randi() % cards.size()])
	if not L.has(key): return 0.0
	var arr = L[key]
	var line = arr[randi() % arr.size()] if typeof(arr) == TYPE_ARRAY else arr
	return say(bcfg["name"], bcfg["voice"], line)

func say(who: String, voice: String, line: String) -> float:
	var dur = max(1.6, Snd.speak(voice, line) + 0.9)
	hud.say(who, line, dur); said_until = t + dur + 1.5
	return dur

func laba(line: String) -> float:
	if line == "": return 0.0
	return say("喇叭嫂", "laba", line)

func show_card(text: String) -> float:
	# 啞鈴的紙板
	if card and is_instance_valid(card): card.queue_free()
	if not body.rig.J.has("hand_l"): return 0.0
	card = Node3D.new(); body.rig.J["hand_l"].add_child(card); card.position = Vector3(0, -0.25, -0.05)
	M.box(card, Vector3(0.7, 0.5, 0.02), Vector3.ZERO, M.wood(Color(0.7, 0.6, 0.42)))
	var l = Label3D.new(); l.text = text; l.font = G.font(); l.font_size = 120; l.pixel_size = 0.0018; l.modulate = Color(0.08, 0.06, 0.05); l.outline_size = 0
	card.add_child(l); l.position = Vector3(0, 0, -0.012); l.rotation_degrees = Vector3(0, 180, 0); card.rotation_degrees = Vector3(90, 0, 0)
	body.rig.pose("card"); Snd.at("card", boss.global_position, 2.0)
	hud.say("（紙板）", text, 2.2); said_until = t + 3.5
	var c = card
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(c): c.queue_free()
		if is_instance_valid(body) and boss.state == St.IDLE: body.rig.pose(""))
	return 2.2

# ---------------- 故事流程 ----------------
func _story_start() -> void:
	Snd.music("")
	busy = true
	if attempt == 1 or cfg.get("force_intro", false): await Cine.intro(self)
	else:
		pctrl.locked = true
		hud.title("第%s閘" % ["一", "二", "三", "四", "五", "六"][D.ORDER.find(bid)], bcfg["name"], 1.2)
		await get_tree().create_timer(1.3).timeout
		pctrl.locked = false
	busy = false
	Snd.music("mus_final" if bid == "zha" else "mus_fight")

func _on_player_ev(n: String, data) -> void:
	match n:
		"dead":
			if over: return
			over = true
			if story: _player_died(str(data))
			else: _round_lost()
		"parry": G.S["prompts"]["alt"] = int(G.S["prompts"].get("alt", 0)) + 1
		"dodge": G.S["prompts"]["dodge"] = int(G.S["prompts"].get("dodge", 0)) + 1
		"disarm_ok":
			G.S["prompts"]["core"] = int(G.S["prompts"].get("core", 0)) + 1
			if story: hud.say("", "—— " + bcfg["parts"].get(str(data), str(data)) + " ——", 1.6)
		"combo":
			if int(G.S.get("combo_n", 0)) == 5 and G.unlock_page("adv_combo"): hud.show_page(D.PAGES["adv_combo"]["sk"], 5.0)
		"switch": G.S["prompts"]["switch"] = int(G.S["prompts"].get("switch", 0)) + 1
		"drink": G.S["prompts"]["drink"] = int(G.S["prompts"].get("drink", 0)) + 1
		"mods":
			if data != null and story: hud.say("", "—— " + str(data) + " ——", 1.4)

func _on_boss_ev(n: String, data) -> void:
	match n:
		"phase":
			Snd.play("gate", -4.0, 1.2); Fx.add_shake(0.5)
			if bid != "zha": laba(["還沒完！", "欸欸欸還有一條！", "下注的不要走！"][randi() % 3])
		"dead":
			if not over:
				over = true; _boss_died(true)
		"kneel": _kneel()

func _player_died(mv: String) -> void:
	busy = true
	Snd.music("")
	var pages = G.on_death(bid, mv)
	await Cine.death(self)
	var L = bcfg["lines"]
	if bid == "yaling": show_card(L["kill_card"])
	else: say(bcfg["name"], bcfg["voice"], L["kill3"][randi() % L["kill3"].size()] if attempt >= 3 else L["kill"][0])
	await get_tree().create_timer(2.4).timeout
	var lk = L["laba_kill"]
	laba(str(lk[min(attempt - 1, lk.size() - 1)]).replace("{n}", str(attempt)))
	if not pages.is_empty() and G.opt("notebook"): hud.show_page(D.PAGES[pages[0]]["sk"], 4.0); Snd.play("card", 0.0)
	hud.prompt("switch", null)
	var wait = 2.6 if pages.is_empty() else 4.0
	var tt = 0.0
	while tt < wait:
		await get_tree().process_frame
		tt += get_process_delta_time()
		if Input.is_action_just_pressed("switch"):
			G.main.go("hub"); return
		if Input.is_action_just_pressed("attack") and tt > 0.8: break
	G.main.go("fight", {"mode": "story", "boss": bid})

var exit_mark: Node3D
func _kneel() -> void:
	# 最後一條打完：他跪著講完話。要不要補最後一下，玩家自己決定。
	Snd.music("")
	exit_mark = Node3D.new(); add_child(exit_mark); exit_mark.position = Vector3(0, 0, -arena.half.y + 1.6) if arena.round_r <= 0 else Vector3(0, 0, -arena.round_r + 2.0)
	M.cyl(exit_mark, 0.8, 0.14, Vector3(0, 1.4, 0), M.rust(Color(0.5, 0.15, 0.1)), Vector3(90, 0, 0), -1.0, 16)
	var l = OmniLight3D.new(); l.light_color = Color(0.5, 0.85, 1.0); l.light_energy = 3.0; l.omni_range = 7.0; exit_mark.add_child(l); l.position = Vector3(0, 1.6, 0.6)
	var L = bcfg["lines"]
	if bid == "yaling":
		for cd in L["defeat_cards"]:
			if boss.state != St.KNEEL: return
			await get_tree().create_timer(show_card(cd) + 0.3).timeout
		return
	for ln in L["defeat"]:
		if boss.state != St.KNEEL: return
		await get_tree().create_timer(say(bcfg["name"], bcfg["voice"], ln) + 0.2).timeout
	if L.has("pc_after") and boss.state == St.KNEEL:
		await get_tree().create_timer(say("釘子", "pc", L["pc_after"]) + 0.2).timeout
		if boss.state == St.KNEEL: say(bcfg["name"], bcfg["voice"], L["after"])

func _boss_died(killed: bool) -> void:
	busy = true
	Snd.music("")
	G.on_win(bid)
	if not killed:
		var sp = G.S.get("spared", [])
		if not sp.has(bid): sp.append(bid)
		G.S["spared"] = sp; G.save()
	await Cine.win(self, killed)
	if bid == "zha": G.main.go("ending", "choose")
	else: G.main.go("hub")

func start_execution(att, vic) -> void:
	if busy: return
	if not story: Net.send("exec", null)
	busy = true
	await Cine.execution(self, att, vic)
	busy = false
	if not story and vic == boss:
		pass

# ---------------- 每幀 ----------------
func _process(d: float) -> void:
	t += d
	if Input.is_action_just_pressed("pause") and not hud.paused: hud.set_pause(true)
	if player == null or boss == null: return
	hud.smoke = lerp(hud.smoke, 1.0 if in_smoke(player.global_position) else 0.0, clamp(d * 4.0, 0, 1))
	if bot: bot.tick(d)
	_prompts(d)
	if story and not over and exit_mark != null and boss.state == St.KNEEL and player.global_position.distance_to(exit_mark.global_position) < 3.0 and Input.is_action_just_pressed("interact") and not player._can_execute():
		over = true; _boss_died(false)
	if not story: _versus_tick(d)

func _need(k: String) -> bool:
	return int(G.S["prompts"].get(k, 0)) < 3 or G.opt("text_hints")

func _prompts(d: float) -> void:
	if busy or over or pctrl.locked:
		if not over: hud.prompt("")
		return
	var p = ""; var pos = null
	var bpos = boss.global_position + Vector3(0, 1.5, 0)
	var dist = player.dist_to(boss)
	if exit_mark != null and boss.state == St.KNEEL and player.global_position.distance_to(exit_mark.global_position) < 6.0:
		p = "interact"; pos = exit_mark.global_position + Vector3(0, 1.4, 0)
	elif (boss.state == St.BROKEN or boss.state == St.KNEEL):
		p = "interact"; pos = bpos
	elif boss.is_boss and body.can_glint() and player.wrench >= player.wrench_need() and dist < 3.4 and _need("core"):
		p = "core"; pos = bpos
	elif boss.state == St.ATTACK and boss.st_t < float(boss.move.get("wu", 0)) and dist < 5.0:
		if boss.move.get("unb", false) and _need("dodge"):
			p = "dodge"; pos = bpos
		elif boss.move.get("kind", "melee") == "melee" and player.stance == "melee" and _need("alt"):
			p = "alt"; pos = bpos
		elif boss.move.get("kind", "") == "shot" and player.stance == "melee" and _need("alt"):
			p = "alt"; pos = bpos
	elif player.hp < player.hp_max * 0.4 and player.flasks > 0 and player.stance == "melee" and _need("drink") and dist > 4.0: p = "drink"
	elif player.stance == "gun" and player.ammo == 0 and player.reserve > 0 and player.state == St.IDLE: p = "reload"
	elif story and attempt == 1 and bid == "bao" and t > 14.0 and not player.gun.is_empty() and _need("switch") and boss.state == St.IDLE and dist > 3.5: p = "switch"
	hud.prompt(p, pos)

func _pause_choice(i: int) -> void:
	hud.set_pause(false)
	match i:
		1:
			if not story: Net.close()
			G.save(); G.main.go("hub")
		2:
			G.save(); get_tree().quit()

# ---------------- 連線對戰 ----------------
func _versus_start() -> void:
	Snd.music("mus_fight")
	hud.rounds = [0, 0, 0]
	_round_begin()

func _round_begin() -> void:
	over = false; busy = true; pctrl.locked = true
	for o in objs.duplicate():
		if is_instance_valid(o): o.queue_free()
	objs.clear()
	var host = Net.is_host
	player.global_position = arena.p_spawn if host else arena.b_spawn; pctrl.set_yaw(0.0 if host else PI); player.pitch = 0.0
	player.hp = player.hp_max; player.stam = player.stam_max; player.posture = 0.0; player.flasks = 1 + int(cfg["my"].get("extra_flask", 0)); player.wrench = 0
	player.set_weapons(player.melee, player.gun, player.gadget); player.mods_off = []; player.bleed_t = 0.0; player.weight = 0; player.sharp = 1.0
	player.set_state(St.IDLE); player.stance = "melee"; player.velocity = Vector3.ZERO; player.impulse = Vector3.ZERO
	pctrl.cine = false
	round_t = 90.0
	hud.title("", ["一", "二", "三"][min(2, wins[0] + wins[1])], 1.0)
	await get_tree().create_timer(1.4).timeout
	busy = false; pctrl.locked = false; round_live = true

func _round_lost() -> void:
	round_live = false
	Net.send("lost", null)
	_round_end(false)

func _round_end(won: bool) -> void:
	round_live = false; over = true
	wins[0 if won else 1] += 1
	hud.rounds[wins[0] + wins[1] - 1] = 1 if won else 2
	if not won: await Cine.death(self)
	else: await get_tree().create_timer(2.5).timeout
	if wins[0] >= 2 or wins[1] >= 2:
		hud.title("", "勝" if wins[0] >= 2 else "敗", 2.5)
		await get_tree().create_timer(3.0).timeout
		G.main.go("hub", {"lobby": true}); return
	_round_begin()

func _versus_tick(d: float) -> void:
	net_t -= d
	if net_t <= 0:
		net_t = 1.0 / 30.0; Net.send("st", player.net_state(), false)
	hud.net_warn = t - last_net > 0.4 and last_net > 0
	if round_live:
		round_t -= d; hud.timer_frac = clamp(round_t / 90.0, 0, 1)
		if round_t <= 0 and Net.is_host:
			var i_win = player.hp / player.hp_max >= boss.hp / max(1.0, boss.hp_max)
			Net.send("timeup", not i_win); _round_end(i_win)
	for i in 4:
		if Input.is_action_just_pressed("em%d" % (i + 1)) and not pctrl.locked: Net.send("emote", i)

func _on_net(kind: String, data) -> void:
	if not is_inside_tree() or boss == null: return
	match kind:
		"st":
			last_net = t; boss.apply_net(data)
		"hit":
			var out = player.take(data)
			Net.send("out", [data, out])
			if out == "hit" or out == "block": pass
		"out":
			player.on_outcome(data[0], data[1])
			if data[1] == "hit": boss.ev.emit("hurt", data[0])
			elif data[1] == "block": boss.ev.emit("blocked", data[0])
			elif data[1] == "parry" or data[1] == "deflect": boss.ev.emit("parry", data[0])
		"disarm": Net.send("dres", player.be_disarmed())
		"dres": player._disarm_result(str(data))
		"lost":
			if round_live or not over: _round_end(true)
		"timeup":
			if round_live: _round_end(bool(data))
		"exec":
			if player.state == St.BROKEN:
				player.set_state(St.VICTIM)
				get_tree().create_timer(1.5).timeout.connect(func():
					if is_instance_valid(player) and player.state == St.VICTIM:
						player.hp = 0.0; player.set_state(St.DEAD); player.ev.emit("dead", "exec"))
		"spawn":
			match data[0]:
				"grenade":
					var g = Objs.Grenade.new(); g.vel = data[2]; g.dmg = data[3]; g.post = data[4]; g.manual = false; g.fuse = 2.2; _add_obj(g, data[1], boss)
				"mine":
					var m = Objs.Mine.new(); _add_obj(m, Vector3(data[1].x, 0, data[1].z), boss)
				"hive":
					var h = Objs.Hive.new(); h.life = data[2]; _add_obj(h, Vector3(data[1].x, 0, data[1].z), boss)
				"smoke": spawn_smoke(data[1], data[2], data[3])
				"swarm":
					var s = Objs.Swarm.new(); s.tgt = player; _add_obj(s, data[1], boss)
		"emote":
			body.rig.pose(["nod", "point", "shrug", "tap"][int(data) % 4])
			get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(body) and boss.state == St.IDLE: body.rig.pose(""))

func _on_peer_left() -> void:
	if not is_inside_tree(): return
	hud.title("", "斷線", 2.0)
	await get_tree().create_timer(2.2).timeout
	Net.close(); G.main.go("hub")

func _exit_tree() -> void:
	if Net.got.is_connected(_on_net): Net.got.disconnect(_on_net)
	if Net.peer_left.is_connected(_on_peer_left): Net.peer_left.disconnect(_on_peer_left)
	Engine.time_scale = 1.0; get_tree().paused = false
