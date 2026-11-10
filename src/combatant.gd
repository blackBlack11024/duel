extends CharacterBody3D
# 戰鬥者：玩家、Boss、連線對手共用同一套規則。差別只在 ctrl（輸入來源）。
enum St {IDLE, ATTACK, BLOCK, DODGE, STUN, BROKEN, EXEC, VICTIM, DEAD, RELOAD, DRINK, DISARM, KNEEL, CINE, JAM}
signal ev(name: String, data)

var ctrl = null
var target = null            # 對手（另一個 combatant）
var is_boss = false
var local = true             # false = 連線對手的傀儡
var cname = ""
var world = null             # fight 場景

var hp = 100.0
var hp_max = 100.0
var bars: Array = []
var bar_i = 0
var stam = 100.0
var stam_max = 100.0
var stam_delay = 0.0
var posture = 0.0
var posture_max = 100.0
var post_delay = 0.0
var block_chance = 0.0

var melee: Dictionary = {}
var gun: Dictionary = {}
var gadget: Dictionary = {}
var core = ""
var core2 = ""
var stance = "melee"
var ammo = 0
var reserve = 0
var flasks = 3
var flask_heal = 35.0
var wrench = 0
var gadget_cd = 0.0
var gadget_uses = 0
var core_cd = 0.0
var sharp = 1.0

var state = St.IDLE
var st_t = 0.0
var st_dur = 0.0
var move: Dictionary = {}
var move_seq = 0
var hit_done = false
var landed = false
var combo = 0
var combo_t = 0.0
var charging = false
var block_t = 99.0
var iframes = false
var fire_cd = 0.0
var draw_t = 0.0
var swap_bonus_t = 0.0
var last_melee_hit = -9.0
var last_shot_hit = -9.0
var aiming = false
var pitch = 0.0
var speed = 4.4
var impulse = Vector3.ZERO
var water = 0                # 0 無 1 腳踝 2 膝蓋
var buf = ""
var buf_t = 0.0
var intent = {}
var clock = 0.0
var bar_dead = false
var invuln_t = 0.0
var killer_move = ""

# 狀態效果
var weight = 0
var weight_t = 0.0
var regen_cut_t = 0.0
var tagged_t = 0.0
var bleed_t = 0.0
var rivets = 0
var parts_off = {}           # Boss：被卸的零件 -> 剩餘秒數
var mods_off: Array = []     # 玩家：被卸的改裝欄
var mods_off_t = 0.0
var pending_reattach = ""
var grenade_out = null
var hyper_on = true

func _init() -> void:
	collision_layer = 2; collision_mask = 1 | 2

func setup(radius: float = 0.38, height: float = 1.8) -> void:
	var cs = CollisionShape3D.new(); var sh = CapsuleShape3D.new(); sh.radius = radius; sh.height = height
	cs.shape = sh; cs.position = Vector3(0, height * 0.5, 0); add_child(cs)
	reset_intent()

func reset_intent() -> void:
	intent = {"mv": Vector2.ZERO, "sprint": false, "attack": false, "attack_held": false, "alt": false, "alt_pressed": false, "dodge": false, "switch": false,
		"gadget": false, "core": false, "core2": false, "reload": false, "drink": false, "interact": false, "jump": false, "do_move": null}

func set_weapons(m: Dictionary, g: Dictionary, gd: Dictionary) -> void:
	melee = m; gun = g; gadget = gd
	if not gun.is_empty():
		ammo = int(gun.get("mag", 0)); reserve = int(gun.get("reserve", 0))
	gadget_uses = int(gadget.get("uses", 0)) if not gadget.is_empty() else 0

func wrench_need() -> int:
	return 2 if melee.get("id", "") == "laoban" else 3

func fwd() -> Vector3: return -global_transform.basis.z
func eye() -> Vector3: return global_position + Vector3(0, 1.62, 0)
func aim_dir() -> Vector3: return (Basis(Vector3.UP, rotation.y) * Basis(Vector3.RIGHT, pitch)) * Vector3(0, 0, -1)
func busy() -> bool: return state != St.IDLE
func alive() -> bool: return state != St.DEAD
func dist_to(o) -> float:
	var d = o.global_position - global_position; d.y = 0; return d.length()
func facing(o, deg: float) -> bool:
	var d = o.global_position - global_position; d.y = 0
	if d.length() < 0.05: return true
	return rad_to_deg(fwd().angle_to(d.normalized())) <= deg * 0.5

func set_state(s: int, dur: float = 0.0) -> void:
	state = s; st_t = 0.0; st_dur = dur; iframes = false; charging = false
	if s != St.ATTACK: move = {}
	ev.emit("state", s)

# ---------------- 每 tick ----------------
func _physics_process(d: float) -> void:
	clock += d
	if not local:
		st_t += d; return
	if ctrl: ctrl.think(d)
	_timers(d)
	_update_state(d)
	_move(d)
	reset_intent_edges()

func reset_intent_edges() -> void:
	for k in ["attack", "alt_pressed", "dodge", "switch", "gadget", "core", "core2", "reload", "drink", "interact", "jump"]: intent[k] = false
	intent["do_move"] = null

func _timers(d: float) -> void:
	st_t += d; block_t += d; fire_cd -= d; draw_t -= d; swap_bonus_t -= d; gadget_cd -= d; core_cd -= d; combo_t -= d; invuln_t -= d
	if buf_t > 0: buf_t -= d
	else: buf = ""
	for k in ["attack", "dodge", "switch", "core", "gadget", "reload", "drink", "core2"]:
		if intent[k]: buf = k; buf_t = 0.2
	# 體力
	stam_delay -= d
	if stam_delay <= 0 and state != St.BLOCK and state != St.DODGE:
		var r = 32.0 * (1.0 - 0.15 * weight)
		if regen_cut_t > 0: r *= 0.5
		stam = min(stam_max, stam + r * d)
	elif stam_delay <= 0 and state == St.BLOCK: stam = min(stam_max, stam + 8.0 * d)
	# 架勢
	post_delay -= d
	if post_delay <= 0 and state != St.BROKEN and state != St.KNEEL:
		posture = max(0.0, posture - 12.0 * (0.4 + 0.6 * hp / max(1.0, hp_max)) * d)
	if weight > 0:
		weight_t -= d
		if weight_t <= 0: weight = 0
	regen_cut_t -= d; tagged_t -= d
	if bleed_t > 0:
		bleed_t -= d; hp -= 3.0 * d
		if hp <= 0: _hp_zero("bleed")
	if mods_off_t > 0:
		mods_off_t -= d
		if mods_off_t <= 0 and not mods_off.is_empty():
			mods_off = []; ev.emit("mods", null)
	for k in parts_off.keys():
		if parts_off[k] > 0:
			parts_off[k] -= d
			if parts_off[k] <= 0:
				parts_off[k] = 0.0; pending_reattach = k

func _update_state(d: float) -> void:
	match state:
		St.IDLE: _idle()
		St.ATTACK: _attack(d)
		St.BLOCK:
			if not intent["alt"] or stance != "melee":
				set_state(St.IDLE); _idle()
			elif buf != "" or intent["interact"]: _idle()
		St.DODGE:
			iframes = st_t >= 0.06 and st_t <= 0.36
			if st_t >= st_dur: set_state(St.IDLE)
		St.STUN:
			if st_t >= st_dur: set_state(St.IDLE)
		St.BROKEN:
			if st_t >= st_dur:
				posture = 0.0
				if bar_dead: next_bar()
				else: set_state(St.IDLE)
		St.RELOAD:
			if buf == "dodge": _idle()
			elif st_t >= st_dur:
				var need = int(gun["mag"]) - ammo; var take_n = min(need, reserve)
				ammo += take_n; reserve -= take_n; set_state(St.IDLE)
		St.JAM:
			if intent["reload"] or st_t > 2.0: set_state(St.RELOAD, 0.5); ev.emit("unjam", null)
		St.DRINK:
			if st_t >= st_dur:
				hp = min(hp_max, hp + flask_heal); bleed_t = 0.0; set_state(St.IDLE)
		St.DISARM:
			if not hit_done and st_t >= 0.18:
				hit_done = true; _try_disarm()
			if st_t >= st_dur: set_state(St.IDLE)
		St.EXEC, St.VICTIM, St.CINE, St.KNEEL, St.DEAD: pass

func _idle() -> void:
	if state != St.IDLE and state != St.BLOCK and state != St.RELOAD: return
	if intent["do_move"] != null:
		start_move(intent["do_move"]); return
	var b = buf
	if b == "dodge" and stam > 5:
		buf = ""; _dodge(); return
	if intent["interact"] and target != null and _can_execute():
		world.start_execution(self, target); return
	if b == "switch" and not gun.is_empty():
		buf = ""; switch_stance(); return
	if b == "core":
		buf = ""; _use_core(core); return
	if b == "core2" and core2 != "":
		buf = ""; _use_core(core2); return
	if b == "gadget" and not gadget.is_empty() and gadget_cd <= 0 and gadget_uses > 0:
		buf = ""; _use_gadget(); return
	if state == St.RELOAD: return
	if stance == "melee":
		if b == "drink" and flasks > 0 and hp < hp_max:
			buf = ""; flasks -= 1; set_state(St.DRINK, 0.9); ev.emit("drink", null); return
		if b == "attack" and stam > 3:
			buf = ""; start_move(_light()); return
		if intent["alt"]:
			if state != St.BLOCK:
				set_state(St.BLOCK); block_t = 0.0; ev.emit("block", null)
			return
	else:
		aiming = intent["alt"]
		if b == "reload" and ammo < int(gun["mag"]) and reserve > 0:
			buf = ""; set_state(St.RELOAD, float(gun["reload"])); ev.emit("reload", null); return
		var want = intent["attack"] or b == "attack" or (gun.get("id", "") == "dianming" and intent["attack_held"])
		if want and fire_cd <= 0 and draw_t <= 0:
			buf = ""
			if gun.get("id", "") == "menlei" and grenade_out != null and is_instance_valid(grenade_out):
				grenade_out.detonate(); grenade_out = null; return
			if ammo > 0: _fire()
			else:
				ev.emit("empty", null); fire_cd = 0.25
				if reserve > 0:
					set_state(St.RELOAD, float(gun["reload"])); ev.emit("reload", null)
	if state == St.BLOCK: set_state(St.IDLE)

func switch_stance() -> void:
	stance = "gun" if stance == "melee" else "melee"
	aiming = false
	if stance == "gun":
		var dr = float(gun.get("draw", 0.3))
		if clock - last_melee_hit < 0.45:
			dr *= 0.6; ev.emit("combo", "gun"); G.S["combo_n"] = int(G.S.get("combo_n", 0)) + 1
		draw_t = dr
	else:
		swap_bonus_t = 0.6 if clock - last_shot_hit < 0.45 else 0.0
		draw_t = 0.2
	if state != St.RELOAD: pass
	else: set_state(St.IDLE)
	ev.emit("switch", stance)

func _light() -> Dictionary:
	var sp = float(melee.get("spd", 1.0))
	if combo_t <= 0: combo = 0
	var anims = ["swing_r", "swing_l", "thrust" if melee.get("cls", "") == "pole" else "overhead"]
	var wu = 0.2 * sp * (0.6 if swap_bonus_t > 0 else 1.0)
	var m = {"id": "light", "anim": anims[combo % 3], "wu": wu, "act": 0.12, "rec": 0.3 * sp, "dmg": float(melee["dmg"]) * (0.75 + 0.25 * sharp), "post": float(melee["post"]),
		"reach": float(melee["reach"]), "arc": 110.0, "stam": 13.0, "lunge": 2.5, "player": true}
	combo += 1; combo_t = 1.2; swap_bonus_t = 0.0
	return m

func _heavy() -> Dictionary:
	var sp = float(melee.get("spd", 1.0)); var hv = float(melee.get("heavy", 1.0))
	return {"id": "heavy", "anim": "overhead", "wu": 0.45 * sp, "wu_max": 1.1 * sp, "act": 0.14, "rec": 0.5 * sp, "dmg": float(melee["dmg"]) * 1.75 * hv * (0.75 + 0.25 * sharp), "post": float(melee["post"]) * 2.3 * hv,
		"reach": float(melee["reach"]) + 0.2, "arc": 80.0, "stam": 26.0, "lunge": 5.0, "heavy": true, "player": true, "charge": true,
		"unb": melee.get("id", "") == "shougong", "hyper": core == "gongqi" or core2 == "gongqi"}

func start_move(m: Dictionary) -> void:
	var mm = m.duplicate()
	if mm.has("off"):
		for pk in mm["off"]:
			if parts_off.has(pk):
				for k in mm["off"][pk]: mm[k] = mm["off"][pk][k]
	if not mm.has("act"): mm["act"] = 0.14
	if mm.has("feint"): mm["wu"] = float(mm["wu"]) + randf() * float(mm["feint"])
	set_state(St.ATTACK)
	move = mm; hit_done = false; landed = false; move_seq += 1
	stam -= float(mm.get("stam", 0.0)); stam_delay = 0.7
	charging = false
	ev.emit("attack", mm)

func _attack(d: float) -> void:
	var wu = float(move["wu"])
	# 玩家：輕擊前搖結束仍按住 → 轉重擊蓄力
	if move.get("id", "") == "light" and not hit_done and st_t >= wu - 0.02 and intent["attack_held"] and stam > 10:
		var keep = st_t
		start_move(_heavy()); st_t = keep; charging = true; combo = 0
		ev.emit("charge", null); return
	if charging:
		if (not intent["attack_held"] and st_t >= float(move["wu"])) or st_t >= float(move["wu_max"]):
			move["wu"] = st_t; charging = false; ev.emit("release", move)
		elif buf == "dodge" and stam > 5:
			buf = ""; _dodge()
		return
	if not hit_done and st_t >= wu:
		hit_done = true; _resolve_move()
		if state != St.ATTACK or move.is_empty(): return
	if hit_done and landed and move.get("player", false) and st_t >= wu + float(move["act"]):
		if buf == "dodge" and stam > 5:
			buf = ""; _dodge(); return
		if buf == "switch" and not gun.is_empty():
			buf = ""; set_state(St.IDLE); switch_stance(); return
		if buf == "attack" and st_t >= wu + float(move["act"]) + float(move["rec"]) * 0.45:
			buf = ""; start_move(_light()); return
	if st_t >= wu + float(move["act"]) + float(move["rec"]):
		var done = move
		set_state(St.IDLE)
		if ctrl and ctrl.has_method("move_done"): ctrl.move_done(done)

func _resolve_move() -> void:
	var kind = move.get("kind", "melee")
	ev.emit("active", move)
	if kind == "fn":
		if ctrl and ctrl.has_method("fn"): ctrl.fn(move)
		return
	if kind == "shot":
		_boss_shot(move); return
	# 近戰
	if world: world.melee_objects(self, move)
	if move.get("shock", false) and world: world.shockwave(self, move)
	if target == null or not target.alive(): return
	var reach = float(move.get("reach", 2.4)) + 0.4
	if dist_to(target) > reach or not facing(target, float(move.get("arc", 110.0))): return
	if abs(target.global_position.y - global_position.y) > 2.0: return
	if move.get("shock", false) and not target.is_on_floor(): return
	deal(_info_from(move, "melee"))

func _info_from(m: Dictionary, kind: String) -> Dictionary:
	var dir = (target.global_position - global_position); dir.y = 0; dir = dir.normalized()
	var info = {"dmg": float(m.get("dmg", 10)), "post": float(m.get("post", 10)), "kind": kind, "unb": m.get("unb", false), "heavy": m.get("heavy", false) or float(m.get("dmg", 0)) >= 28,
		"dir": dir, "move": m.get("id", ""), "push": float(m.get("push", 0)), "pull": float(m.get("pull", 0))}
	if m.get("tag", false): info["tag"] = true
	if m.get("rivet", false): info["rivet"] = true
	if is_boss and cname == "bao" and kind == "melee": info["weight"] = true
	if not is_boss and kind == "melee":
		if m.get("heavy", false):
			if melee.get("id", "") == "banshan": info["bleed"] = true
			if melee.get("id", "") == "gemi": info["pull"] = 4.0
			if core == "guobang" or core2 == "guobang": info["regen_cut"] = true
		if core == "guahao" or core2 == "guahao": info["tag"] = true
		if target.rivets >= 3:
			info["post"] = float(info["post"]) + 35.0; info["rivet_pop"] = true
	return info

# 送出一次攻擊。本機目標直接結算；連線目標交給對方機器判定（防守方說了算）。
func deal(info: Dictionary) -> void:
	if not local or target == null: return
	if target.local:
		var out = target.take(info)
		on_outcome(info, out)
	else:
		Net.send("hit", info)

func on_outcome(info: Dictionary, out: String) -> void:
	if out == "miss": return
	landed = true
	if info["kind"] == "melee":
		if out == "hit" or out == "block": last_melee_hit = clock
		if out == "block": sharp = max(0.0, sharp - 0.035 / max(0.3, float(melee.get("dur", 1.0))))
		elif out == "hit": sharp = max(0.0, sharp - 0.012 / max(0.3, float(melee.get("dur", 1.0))))
		if out == "parry":
			# 被彈反
			add_posture(34.0 if not is_boss else 30.0)
			if state == St.ATTACK and not (move.get("hyper", false) and hyper_on and not parts_off.has("tank")): set_state(St.STUN, 0.7)
		if info.get("rivet_pop", false) and out != "miss": target.rivets = 0
	elif info["kind"] == "bullet" and out == "hit": last_shot_hit = clock
	ev.emit("dealt", {"info": info, "out": out})

func add_posture(a: float) -> void:
	if state == St.BROKEN or state == St.KNEEL or state == St.DEAD or state == St.VICTIM: return
	posture += a; post_delay = 1.6
	if posture >= posture_max: _break()

func _break() -> void:
	posture = posture_max
	set_state(St.BROKEN, 3.2 if is_boss else 2.2)
	ev.emit("broken", null)

# ---------------- 受擊 ----------------
var magnet_t = 0.0
func take(info: Dictionary) -> String:
	if not local: return "miss"
	if magnet_t > clock and info["kind"] == "bullet" and not info.get("unb", false):
		ev.emit("deflect", info); return "deflect"
	if state == St.DEAD or state == St.EXEC or state == St.VICTIM or state == St.CINE or state == St.KNEEL or invuln_t > 0: return "miss"
	if iframes and info["kind"] != "dot": return "miss"
	var kind = info["kind"]
	var dmg = float(info["dmg"]); var post = float(info["post"])
	var dir: Vector3 = info.get("dir", Vector3.ZERO)
	var front = dir.length() < 0.1 or rad_to_deg(fwd().angle_to(-dir)) < 75.0
	var out = "hit"
	var pw = float(melee.get("parry", 0.15)) + (0.05 if (not is_boss and G.opt("assist_parry")) else 0.0)
	if state == St.BLOCK and front and kind != "dot" and kind != "explosion":
		if kind == "bullet":
			if block_t <= pw + 0.05 and not info.get("unb", false): out = "deflect"
		elif not info.get("unb", false):
			if block_t <= pw: out = "parry"
			else: out = "block"
	elif state == St.BLOCK and kind == "explosion" and melee.get("id", "") == "banyuan" and front: out = "block"
	# Boss 的格擋（AI 決定）
	if is_boss and out == "hit" and kind == "melee" and state == St.IDLE and front and not info.get("unb", false):
		var bc = block_chance * (0.5 if info.get("heavy", false) else 1.0)
		if randf() < bc:
			out = "block"; ev.emit("block", null)
	match out:
		"parry":
			wrench = min(3, wrench + 1); stam = min(stam_max, stam + 10.0)
			if not gun.is_empty(): reserve += 1
			ev.emit("parry", info); return out
		"deflect":
			ev.emit("deflect", info); return out
		"block":
			var st = clamp(float(melee.get("stab", 0.5)), 0.0, 0.92)
			stam -= dmg * (2.3 - st * 1.3) * (1.5 if info.get("heavy", false) else 1.0); stam_delay = 1.0
			hp -= dmg * (0.15 if not is_boss else 0.35)
			var pp = post * (0.9 if info.get("heavy", false) else 0.4)
			ev.emit("blocked", info)
			if stam <= 0:
				stam = 0.0; pp += 30.0
				if not is_boss: set_state(St.STUN, 0.6)
			add_posture(pp)
			if hp <= 0: _hp_zero(info.get("move", ""))
			return out
	# ---- 命中 ----
	var broken = state == St.BROKEN
	if kind == "bullet":
		if broken: dmg *= 1.5
		elif info.get("pierce", false): pass
		else:
			post += dmg * 0.6; dmg *= 0.4
	elif broken: dmg *= 1.3
	if state == St.RELOAD or state == St.DRINK or move.get("weak", false): post *= 2.0
	if info.get("instabreak", false) and (state == St.RELOAD or state == St.DRINK or (state == St.ATTACK and hit_done)): post += posture_max
	if not is_boss and (core == "gongqi" or core2 == "gongqi") and state == St.ATTACK and move.get("heavy", false): dmg *= 1.3
	hp -= dmg
	if info.get("weight", false):
		weight = min(4, weight + 1); weight_t = 8.0
	if info.get("regen_cut", false): regen_cut_t = 4.0
	if info.get("tag", false): tagged_t = 10.0
	if info.get("bleed", false): bleed_t = 6.0
	if info.get("rivet", false): rivets = min(3, rivets + 1)
	if float(info.get("push", 0)) > 0: impulse += dir * float(info["push"])
	if float(info.get("pull", 0)) > 0: impulse -= dir * float(info["pull"])
	ev.emit("hurt", info)
	# 硬直
	var armored = state == St.ATTACK and move.get("hyper", false) and hyper_on and not parts_off.has("tank")
	if not broken and kind != "dot":
		if is_boss:
			if (state == St.ATTACK and move.get("weak", false)) or (info.get("heavy", false) and state == St.IDLE) or float(info.get("stun", 0)) > 0:
				var was = move
				set_state(St.STUN, max(0.45, float(info.get("stun", 0))))
				if ctrl and ctrl.has_method("interrupted"): ctrl.interrupted(was)
		elif not armored:
			set_state(St.STUN, max(0.32, float(info.get("stun", 0))))
	if hp <= 0: _hp_zero(info.get("move", ""))
	else: add_posture(post * (0.45 if (is_boss and kind == "melee" and not info.get("heavy", false)) else 1.0))
	return out

func _hp_zero(mv: String) -> void:
	hp = 0.0; killer_move = mv
	if is_boss:
		bar_dead = true
		if bar_i >= bars.size() - 1:
			set_state(St.KNEEL); ev.emit("kneel", null)
		else:
			posture = posture_max; set_state(St.BROKEN, 5.0); ev.emit("broken", null)
	else:
		set_state(St.DEAD); ev.emit("dead", mv)

func next_bar() -> void:
	bar_dead = false
	if bar_i + 1 >= bars.size():
		hp = 0.0; bar_dead = true; posture = 0.0
		set_state(St.KNEEL); ev.emit("kneel", null); return
	bar_i += 1
	hp = float(bars[bar_i]); hp_max = hp; posture = 0.0; invuln_t = 2.0
	set_state(St.STUN, 1.6)
	ev.emit("phase", bar_i)

func _can_execute() -> bool:
	if target == null or not (target.state == St.BROKEN or target.state == St.KNEEL): return false
	return dist_to(target) < 3.2 and facing(target, 120.0)

# ---------------- 動作 ----------------
func _dodge() -> void:
	stam -= 22.0; stam_delay = 0.7
	var mv: Vector2 = intent["mv"]
	var dir = Vector3(mv.x, 0, -mv.y)
	if dir.length() < 0.2: dir = Vector3(0, 0, 1)
	dir = (Basis(Vector3.UP, rotation.y) * dir).normalized()
	var sp = 9.5 if water < 2 else 5.0
	set_state(St.DODGE, 0.5)
	impulse = dir * sp
	ev.emit("dodge", dir)

func _move(d: float) -> void:
	var mv: Vector2 = intent["mv"]
	var sp = speed
	match state:
		St.IDLE:
			if intent["sprint"] and stance == "melee" and mv.y > 0.5 and stam > 1:
				sp *= 1.55; stam -= 7.0 * d; stam_delay = 0.3
			if stance == "gun" and aiming and gun.get("id", "") != "guahao": sp *= 0.5
		St.BLOCK: sp *= 0.5
		St.ATTACK:
			sp *= 0.35
			if charging: sp *= 0.6 if melee.get("id", "") != "shougong" else 0.15
		St.RELOAD: sp *= 0.75
		St.DRINK: sp *= 0.4
		St.DODGE: sp *= 0.15
		_: sp = 0.0
	if water == 1: sp *= 0.85
	elif water >= 2: sp *= 0.65
	var want = (Basis(Vector3.UP, rotation.y) * Vector3(mv.x, 0, -mv.y)) * sp
	if state == St.ATTACK and move.has("lunge") and not charging:
		var wu = float(move["wu"])
		if st_t > wu - 0.12 and st_t < wu + float(move["act"]): want += fwd() * float(move["lunge"])
	var acc = 14.0 if is_on_floor() else 3.0
	velocity.x = move_toward(velocity.x, want.x, acc * sp * d + 40.0 * d)
	velocity.z = move_toward(velocity.z, want.z, acc * sp * d + 40.0 * d)
	velocity.x += impulse.x; velocity.z += impulse.z
	if not is_on_floor(): velocity.y -= 18.0 * d
	elif intent["jump"] and (state == St.IDLE or state == St.BLOCK): velocity.y = 6.2
	move_and_slide()
	velocity.x -= impulse.x; velocity.z -= impulse.z
	impulse = impulse.move_toward(Vector3.ZERO, 30.0 * d) if state != St.DODGE else impulse * (1.0 - 2.2 * d)

# ---------------- 射擊 ----------------
func _fire() -> void:
	var id = gun.get("id", "")
	if not G.opt("no_jam") and randf() < float(gun.get("jam", 0.0)):
		set_state(St.JAM); ev.emit("jam", null); return
	var pellets = int(gun.get("pellets", 1)); var spread = float(gun["spread"]); var cost = 1
	var rof = float(gun["rof"])
	if id == "liukong" and not aiming:
		spread *= 3.5; rof *= 0.55
	elif aiming: spread *= 0.45 * float(gun.get("aim", 1.0))
	if id == "duiban" and aiming and ammo >= 2:
		pellets *= 2; cost = 2
	ammo -= cost; fire_cd = rof
	ev.emit("fired", {"recoil": float(gun["recoil"]) * cost, "flash": float(gun.get("flash", 1.0))})
	if id == "menlei":
		grenade_out = world.spawn_grenade(self, eye() + aim_dir() * 0.8, aim_dir() * 16.0 + Vector3(0, 3, 0), float(gun["dmg"]), float(gun["post"]), true); return
	var hits = 0; var head = false; var dmg = 0.0
	var from = eye()
	for i in pellets:
		var dir = _spread(aim_dir(), spread)
		if tag_assist(): dir = (target.global_position + Vector3(0, 1.2, 0) - from).normalized()
		var r = world.ray(from, from + dir * 200.0, [self])
		var endp = from + dir * 60.0
		if not r.is_empty():
			endp = r["position"]
			var c = r["collider"]
			if c == target:
				var dist = from.distance_to(endp)
				var fall = clamp(1.0 - max(0.0, dist - float(gun["range"])) / float(gun["range"]), 0.15, 1.0)
				dmg += float(gun["dmg"]) * fall; hits += 1
				if endp.y - target.global_position.y > 1.5: head = true
			elif c.has_method("shot_hit"): c.shot_hit(self, float(gun["dmg"]))
			else: Fx.sparks(endp, Color(1, 0.8, 0.5), 5, 3.0)
		Fx.tracer(world.muzzle_pos(self), endp)
	if hits > 0 and target != null:
		var info = {"dmg": dmg, "post": float(gun["post"]) * hits, "kind": "bullet", "unb": false, "heavy": dmg >= 40, "dir": (target.global_position - global_position).normalized(), "move": "shot"}
		if head and id == "guahao": info["pierce"] = true
		if head: info["dmg"] = dmg * 1.25
		if id == "changzui": info["instabreak"] = true
		if id == "dianming": info["rivet"] = true
		if gun.get("mods_salt", false): info["stun"] = 0.3
		if target.tagged_t > 0 and (core == "guahao" or core2 == "guahao"): target.tagged_t = 0.0
		deal(info)

func tag_assist() -> bool:
	if target == null or target.tagged_t <= 0 or not (core == "guahao" or core2 == "guahao"): return false
	return rad_to_deg(aim_dir().angle_to((target.global_position + Vector3(0, 1.2, 0) - eye()).normalized())) < 14.0

func _spread(dir: Vector3, deg: float) -> Vector3:
	var a = deg_to_rad(deg) * sqrt(randf()); var b = randf() * TAU
	var up = Vector3.UP if abs(dir.y) < 0.95 else Vector3.RIGHT
	var x = dir.cross(up).normalized(); var y = x.cross(dir).normalized()
	return (dir + (x * cos(b) + y * sin(b)) * tan(a)).normalized()

# Boss 開槍：前搖期間瞄準線跟著目標，開火前 0.16 秒鎖定（由 ai 更新 aim_lock）
var aim_lock = Vector3.ZERO
func _boss_shot(m: Dictionary) -> void:
	if target == null: return
	var from = world.muzzle_pos(self)
	var to = aim_lock
	if target.tagged_t > 0 and cname == "xue":
		to = target.global_position + Vector3(0, 1.2, 0); target.tagged_t = 0.0
	var pellets = int(m.get("pellets", 1)); var hits = 0
	var base = (to - from).normalized()
	for i in pellets:
		var dir = _spread(base, float(m.get("spread", 0.4)))
		var r = world.ray(from, from + dir * 150.0, [self])
		var endp = from + dir * 60.0
		if not r.is_empty():
			endp = r["position"]
			if r["collider"] == target: hits += 1
			else: Fx.sparks(endp, Color(1, 0.8, 0.5), 4, 3.0)
		Fx.tracer(from, endp, Color(1, 0.85, 0.5), 0.02)
	Snd.at(m.get("snd", "shot_revolver"), from, 3.0)
	Fx.flash(from, Color(1, 0.7, 0.3), 6.0, 0.08)
	ev.emit("bossfired", m)
	if hits > 0:
		var info = _info_from(m, "bullet"); info["dmg"] = float(m["dmg"]) * hits; info["post"] = float(m.get("post", 5)) * hits
		deal(info)

# ---------------- 核心 / 奇械 ----------------
func _use_core(c: String) -> void:
	match c:
		"xiejian":
			if wrench < wrench_need():
				ev.emit("nocore", null); return
			set_state(St.DISARM, 0.6); hit_done = false; ev.emit("disarm_try", null)
		"fenchao":
			if core_cd > 0: return
			core_cd = 18.0; world.spawn_hive(self, global_position + fwd() * 2.5, 12.0); ev.emit("coreuse", c)
		"yanshi":
			if world.my_mine(self) != null: world.my_mine(self).detonate()
			elif core_cd <= 0:
				core_cd = 10.0; world.spawn_mine(self, global_position + fwd() * 1.2); ev.emit("coreuse", c)
		_: pass

func _try_disarm() -> void:
	if target == null or dist_to(target) > 3.2 or not facing(target, 90.0):
		wrench = max(0, wrench - 1); ev.emit("disarm_fail", null); return
	if target.local:
		var res = target.be_disarmed()
		_disarm_result(res)
	else: Net.send("disarm", null)

func _disarm_result(res: String) -> void:
	if res == "":
		wrench = max(0, wrench - 1); ev.emit("disarm_fail", null)
	else:
		wrench = 0; ev.emit("disarm_ok", res)

# 被卸件。回傳被卸掉的零件名（空字串＝失敗）
func be_disarmed() -> String:
	if is_boss:
		if state != St.ATTACK or not move.has("part") or parts_off.has(move["part"]): return ""
		if st_t > float(move["wu"]) + float(move["act"]) + 0.1: return ""
		var pk = move["part"]
		parts_off[pk] = 25.0
		var was = move
		set_state(St.STUN, 1.3); add_posture(30.0)
		if ctrl and ctrl.has_method("interrupted"): ctrl.interrupted(was)
		ev.emit("lost_part", pk)
		return pk
	# 玩家：攻擊前搖或裝填中才會被卸
	if not (state == St.ATTACK or state == St.RELOAD or state == St.DRINK or state == St.STUN): return ""
	return lose_mod()

func lose_mod() -> String:
	var w = gun if stance == "gun" else melee
	var id = w.get("id", "")
	var ms = world.mods_of(self, id)
	var slots = []
	for k in ms:
		if ms[k] != "std" and not mods_off.has(k): slots.append(k)
	set_state(St.STUN, 0.8)
	if slots.is_empty():
		hp -= 12.0; ev.emit("hurt", {"dmg": 12.0, "kind": "melee", "dir": Vector3.ZERO})
		if hp <= 0: _hp_zero("grab")
		return "手"
	var sl = slots[randi() % slots.size()]
	mods_off.append(sl); mods_off_t = 25.0 if (target and target.is_boss) else 8.0
	ev.emit("mods", sl)
	return D.part(D.wkind(id), sl, ms[sl])["name"]

func _use_gadget() -> void:
	gadget_cd = float(gadget.get("cd", 5.0))
	if int(gadget.get("uses", 99)) < 90: gadget_uses -= 1
	ev.emit("gadget", gadget.get("id", ""))
	world.use_gadget(self, gadget.get("id", ""))

# ---------------- 連線同步 ----------------
func net_state() -> Array:
	return [global_position, rotation.y, pitch, state, stance, move_seq, move.get("anim", ""), float(move.get("wu", 0.2)), float(move.get("act", 0.12)), float(move.get("rec", 0.3)),
		hp, posture, stam, wrench, move.get("unb", false), aiming, charging]

var net_pos = Vector3.ZERO
func apply_net(a: Array) -> void:
	net_pos = a[0]; rotation.y = lerp_angle(rotation.y, a[1], 0.6); pitch = a[2]
	var ns = int(a[3])
	if a[4] != stance:
		stance = a[4]; ev.emit("switch", stance)
	if int(a[5]) != move_seq:
		move_seq = int(a[5]); state = St.ATTACK; st_t = 0.0
		move = {"anim": a[6], "wu": a[7], "act": a[8], "rec": a[9], "unb": a[14]}
		ev.emit("attack", move)
	if ns != state:
		state = ns; st_t = 0.0
		if ns == St.BLOCK: block_t = 0.0
		ev.emit("state", ns)
		if ns == St.BROKEN: ev.emit("broken", null)
	hp = a[10]; posture = a[11]; stam = a[12]; wrench = int(a[13]); aiming = a[15]
	if charging and not a[16]: ev.emit("release", move)
	charging = a[16]

func _process(d: float) -> void:
	if not local and net_pos != Vector3.ZERO:
		global_position = global_position.lerp(net_pos, clamp(d * 18.0, 0.0, 1.0))
