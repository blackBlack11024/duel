extends Node
# Boss 大腦。招式表在 data.gd；這裡只管「什麼時候出哪招」和每個人的特殊能力。
const St = preload("res://src/combatant.gd").St
var c
var id = ""
var cfg: Dictionary
var world
var cd = 1.5
var chain = ""
var last = ""
var shots = 0
var strafe = 1.0
var strafe_t = 0.0
var seen_seq = -1
var fight_t = 0.0
var tutorial = false
var grenades = []
var queued = ""
var said_t = 0.0
var ng = 0

func setup(comb, boss_id: String, w) -> void:
	c = comb; id = boss_id; cfg = D.BOSS[id]; world = w; c.ctrl = self
	c.ev.connect(_on_ev)
	ng = int(G.S.get("ng", 0))

func phase() -> int: return c.bar_i

func think(d: float) -> void:
	fight_t += d; said_t -= d
	var t = c.target
	if t == null or not t.alive(): return
	_special_tick(d)
	var to = t.global_position - c.global_position; to.y = 0
	var dist = to.length()
	var want_yaw = atan2(-to.x, -to.z)
	if c.state == St.ATTACK:
		var wu = float(c.move.get("wu", 0.5))
		if c.st_t < wu - 0.1: c.rotation.y = rotate_toward(c.rotation.y, want_yaw, float(c.move.get("track", 3.6)) * d)
		if c.move.get("kind", "") == "shot":
			var lock_t = wu - (0.0 if (t.tagged_t > 0 and id == "xue") else 0.17)
			if c.st_t < lock_t: c.aim_lock = t.global_position + Vector3(0, 1.15, 0) + t.velocity * 0.0
		return
	if c.state != St.IDLE: return
	c.rotation.y = rotate_toward(c.rotation.y, want_yaw, 7.0 * d)
	c.aim_lock = t.global_position + Vector3(0, 1.15, 0)
	# 反應：閃避玩家的攻擊
	if t.move_seq != seen_seq:
		seen_seq = t.move_seq
		if t.state == St.ATTACK and dist < 4.0 and randf() < float(cfg["dodge"]) and c.stam > 30:
			c.intent["mv"] = Vector2(strafe, -0.6); c.intent["dodge"] = true; return
	if queued != "":
		var q = queued; queued = ""; _go(q); return
	if c.pending_reattach != "":
		c.intent["do_move"] = {"id": "reattach", "anim": "reload", "kind": "fn", "fn": "reattach", "wu": 1.3, "rec": 0.2, "weak": true}; return
	cd -= d
	# 移動
	var pref = float(cfg["pref"])
	if t.state == St.BROKEN: pref = 2.0
	var mv = Vector2.ZERO
	if dist > pref + 0.6: mv.y = 1.0
	elif dist < pref - 1.2: mv.y = -0.8
	strafe_t -= d
	if strafe_t <= 0:
		strafe_t = randf_range(0.8, 2.2); strafe = 1.0 if randf() < 0.5 else -1.0
	if dist < pref + 3.0: mv.x = strafe * 0.55
	c.intent["mv"] = mv
	c.speed = float(cfg["speed"]) * (1.0 + 0.08 * phase())
	if cd > 0: return
	if chain != "":
		var ch = chain; chain = ""
		var cm = cfg["moves"][ch]
		if dist <= float(cm["r"][1]) + 0.8 and _usable(cm):
			_go(ch); return
	var pick = _choose(dist)
	if pick != "": _go(pick)

func _usable(m: Dictionary) -> bool:
	if int(m.get("ph", 0)) > phase(): return false
	if m.has("needs") and c.parts_off.has(m["needs"]): return false
	return true

func _choose(dist: float) -> String:
	if tutorial and fight_t < 28.0:
		return "chop" if dist < 3.2 else ""
	# 特殊條件
	match id:
		"xue":
			if shots >= 5: return "reload"
		"zha":
			if shots >= 6:
				return "seventh" if not c.parts_off.has("seventh") else "reload"
			if shots >= 7: return "reload"
		"ruan":
			if world.count_obj("hive", c) >= (3 if phase() >= 1 else 2) and randf() < 0.9:
				pass
	var tot = 0.0; var opts = []
	for k in cfg["moves"]:
		var m = cfg["moves"][k]
		var w = float(m.get("w", 1.0))
		if w <= 0 or not _usable(m): continue
		if dist < float(m["r"][0]) or dist > float(m["r"][1]): continue
		if k == last: w *= 0.35
		if id == "ruan" and k == "hive" and world.count_obj("hive", c) >= (3 if phase() >= 1 else 2): continue
		if id == "yaling" and k == "mine" and world.count_obj("mine", c) >= 4: continue
		if c.target.state == St.DRINK and (m.get("kind", "") == "shot" or m.has("lunge")): w *= 3.0
		if c.target.state == St.BROKEN and m.get("kind", "melee") == "melee": w *= float(m.get("dmg", 10)) / 8.0
		opts.append([k, w]); tot += w
	if opts.is_empty(): return ""
	var r = randf() * tot
	for o in opts:
		r -= o[1]
		if r <= 0: return o[0]
	return opts[0][0]

func _go(k: String) -> void:
	var m = cfg["moves"][k].duplicate(); m["id"] = k
	if tutorial and fight_t < 28.0: m["wu"] = float(m["wu"]) * 1.4
	if ng > 0: m["wu"] = float(m["wu"]) * 0.9
	if m.get("hyper", false) and c.parts_off.has("tank"): m["hyper"] = false
	last = k
	if m.get("ammo", 0) > 0 or k == "seventh": shots += 1
	c.intent["do_move"] = m

func move_done(m: Dictionary) -> void:
	var gap = randf_range(0.5, 1.1) - 0.12 * phase()
	if tutorial and fight_t < 28.0: gap = 1.7
	cd = max(0.2, gap)
	if m.has("next") and int(m.get("nextph", 0)) <= phase() and randf() < float(m["next"][1]):
		chain = m["next"][0]; cd = 0.05

func interrupted(m: Dictionary) -> void:
	cd = 0.6; chain = ""
	if m.get("fn", "") == "reattach" and c.pending_reattach != "":
		c.parts_off[c.pending_reattach] = 6.0; c.pending_reattach = ""

func _on_ev(n: String, data) -> void:
	match n:
		"phase":
			var ph = int(data)
			match id:
				"zha": queued = "wheel"
				"yaling":
					if ph == 2: queued = "bag"
				"ruan":
					for i in 3: world.spawn_hive(c, world.arena.random_spot(c.target.global_position, 4.0, 9.0), 0.0)
				"ge": world.arena.shrink(ph)
		"dealt":
			if data["out"] == "hit" and said_t <= 0 and randf() < 0.45:
				said_t = 9.0; world.boss_say("hit")
			elif data["out"] == "parry" and said_t <= 0 and randf() < 0.5:
				said_t = 7.0; world.boss_say("parried")
		"lost_part":
			said_t = 6.0; world.boss_say("disarmed")

# ---------------- 特殊招式 ----------------
func fn(m: Dictionary) -> void:
	var t = c.target
	match m.get("fn", ""):
		"reattach":
			if c.pending_reattach != "":
				c.parts_off.erase(c.pending_reattach); c.pending_reattach = ""; Snd.at("click", c.global_position, 3.0)
		"reload":
			shots = 0; Snd.at("reload", c.global_position, 2.0)
		"hook_pull": world.hook_pull(c, t, 0.75)
		"fly":
			var spot = world.arena.far_spot(t.global_position, c.global_position)
			world.fly_to(c, spot)
		"hive": world.spawn_hive(c, world.arena.random_spot(t.global_position, 2.5, 6.0), 0.0)
		"swarm": world.spawn_swarm(c, world.muzzle_pos(c), t)
		"smoke": world.spawn_smoke(t.global_position, 5.0, 9.0)
		"lob":
			if c.parts_off.has("safety"):
				world.explode(c.global_position + c.fwd() * 0.8, 3.0, 30.0, 45.0, null); return
			var g = world.spawn_grenade(c, world.muzzle_pos(c), _lob_vel(world.muzzle_pos(c), t.global_position + t.velocity * 0.5 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))), 34.0, 38.0, not c.parts_off.has("crank"))
			g.auto_t = randf_range(1.0, 3.2); grenades.append(g)
		"mine":
			for i in 2:
				var p = c.global_position.lerp(t.global_position, randf_range(0.35, 0.8)) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
				world.spawn_mine(c, world.arena.clamp_pos(p))
		"detonate":
			for g2 in grenades:
				if is_instance_valid(g2): g2.detonate()
			grenades.clear()
		"bag":
			for i in 6:
				var a = i * TAU / 6.0
				var g3 = world.spawn_grenade(c, c.global_position + Vector3(0, 1.6, 0), Vector3(cos(a) * randf_range(3, 7), 7, sin(a) * randf_range(3, 7)), 34.0, 38.0, true)
				g3.auto_t = 1.6 + i * 0.35; grenades.append(g3)
		"plates": world.arena.raise_around(t.global_position)
		"disarm":
			if c.dist_to(t) <= float(m.get("reach", 2.4)) + 0.4 and c.facing(t, 100.0) and not t.iframes and t.alive():
				var got = t.lose_mod()
				if got != "": world.boss_say("disarm_you")
		"wheel":
			if not c.parts_off.has("wheel"): world.arena.raise_water()

func _lob_vel(from: Vector3, to: Vector3) -> Vector3:
	var tt = clamp(from.distance_to(to) / 11.0, 0.7, 1.8)
	var v = (to - from) / tt; v.y = (to.y - from.y) / tt + 0.5 * 18.0 * tt
	return v

func _special_tick(d: float) -> void:
	if id == "yaling":
		# 延時：他決定什麼時候炸
		for g in grenades.duplicate():
			if not is_instance_valid(g):
				grenades.erase(g); continue
			if g.landed and g.manual:
				g.auto_t -= d
				var near = g.global_position.distance_to(c.target.global_position) < 2.4
				if (near and g.auto_t < 2.4) or g.auto_t <= 0:
					if c.global_position.distance_to(g.global_position) > 3.5 or g.auto_t < -1.5:
						g.detonate(); grenades.erase(g)
