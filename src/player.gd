extends Node3D
# 本機玩家：輸入 → intent、攝影機、第一人稱手與武器。
const M = preload("res://src/mat.gd")
const WM = preload("res://src/wm.gd")
const St = preload("res://src/combatant.gd").St
var c                       # combatant
var cam: Camera3D
var vm: Node3D
var rm: Node3D              # 近戰手
var rg: Node3D              # 槍手
var lh: Node3D              # 左手（護板＝血量）
var wm_melee: Node3D
var wm_gun: Node3D
var plates = []
var nuts = []
var pips = []
var brass = []
var locked = false          # 演出中鎖定輸入
var cine = false            # 演出中攝影機由外部控制
var yaw = 0.0
var recoil = 0.0
var tilt = 0.0
var bob = 0.0
var act = {}                # 目前動作 {wu, hit, t, twu, tact}
var seq = {}                # 腳本動畫 holder -> [[t,pos,rot]...]
var seq_t = 0.0
var tgt = {}
var hurt_t = 0.0
var step_t = 0.0
var pad_look = Vector2.ZERO
var using_pad = false
var gun_kick = 0.0
var parry_kick = 0.0
var sway = Vector2.ZERO

const P = {
	"m_idle": [Vector3(0.36, -0.36, -0.62), Vector3(-25, 0, 12)],
	"m_block": [Vector3(0.06, -0.2, -0.5), Vector3(-12, 0, 68)],
	"m_low": [Vector3(0.4, -0.9, -0.4), Vector3(-60, 0, 20)],
	"swing_r": [[Vector3(0.6, -0.08, -0.42), Vector3(-10, 0, -72)], [Vector3(-0.4, -0.34, -0.62), Vector3(-62, 0, 82)]],
	"swing_l": [[Vector3(-0.32, -0.08, -0.5), Vector3(-10, 0, 78)], [Vector3(0.55, -0.34, -0.56), Vector3(-62, 0, -78)]],
	"overhead": [[Vector3(0.26, 0.18, -0.34), Vector3(38, 0, 5)], [Vector3(0.14, -0.5, -0.72), Vector3(-104, 0, 5)]],
	"thrust": [[Vector3(0.32, -0.26, -0.28), Vector3(-80, 0, 0)], [Vector3(0.08, -0.2, -1.05), Vector3(-88, 0, 0)]],
	"g_idle": [Vector3(0.24, -0.24, -0.52), Vector3(0, 4, 0)],
	"g_aim": [Vector3(0.0, -0.105, -0.42), Vector3(0, 0, 0)],
	"g_low": [Vector3(0.3, -0.8, -0.3), Vector3(-50, 0, 0)],
	"g_reload": [Vector3(0.16, -0.36, -0.4), Vector3(35, 0, -40)],
	"l_idle": [Vector3(-0.36, -0.4, -0.5), Vector3(8, -14, 10)],
	"l_gun": [Vector3(-0.3, -0.46, -0.44), Vector3(4, -10, 12)],
	"l_low": [Vector3(-0.4, -0.9, -0.3), Vector3(0, 0, 0)],
	"l_drink": [Vector3(-0.08, -0.12, -0.3), Vector3(70, -30, 30)],
	"l_reach": [Vector3(-0.02, -0.08, -0.95), Vector3(0, 0, 0)],
	"l_twist": [Vector3(-0.1, -0.2, -0.6), Vector3(10, 0, 120)],
	"l_block": [Vector3(-0.2, -0.26, -0.42), Vector3(30, -30, 30)],
}

func setup(comb) -> void:
	c = comb; c.ctrl = self
	cam = Camera3D.new(); add_child(cam); cam.position = Vector3(0, 1.62, 0); cam.fov = float(G.opt("fov")); cam.near = 0.03; cam.far = 300.0; cam.current = true
	var al = AudioListener3D.new(); cam.add_child(al); al.current = true
	vm = Node3D.new(); cam.add_child(vm)
	rm = _arm(1); rg = _arm(1); lh = _arm(-1)
	for h in [rm, rg, lh]: vm.add_child(h)
	_left_extras()
	rebuild_weapons()
	rm.position = P["m_low"][0]; rg.position = P["g_low"][0]; lh.position = P["l_low"][0]
	c.ev.connect(_on_ev)
	yaw = c.rotation.y

func _arm(side: int) -> Node3D:
	var h = Node3D.new()
	var sk = M.skin(Color(0.62, 0.48, 0.4))
	M.box(h, Vector3(0.085, 0.1, 0.11), Vector3(0, -0.02, 0.03), sk)
	M.cap(h, 0.05, 0.5, Vector3(0.04 * side, -0.1, 0.32), sk, Vector3(70, -8 * side, 0))
	M.cyl(h, 0.058, 0.2, Vector3(0.05 * side, -0.16, 0.5), M.cloth(Color(0.3, 0.22, 0.15)), Vector3(70, -8 * side, 0))
	M.cyl(h, 0.054, 0.05, Vector3(0.012 * side, -0.045, 0.12), M.cloth(Color(0.15, 0.1, 0.08)), Vector3(70, -8 * side, 0))
	return h

func _left_extras() -> void:
	# 前臂護板＝血量；手腕螺帽＝扳手計；水壺刻度＝剩餘口數
	for i in 5:
		var pl = M.box(lh, Vector3(0.075, 0.016, 0.07), Vector3(-0.02 - i * 0.003, -0.03 - i * 0.022, 0.18 + i * 0.075), M.steel(), Vector3(-20, 0, 0))
		plates.append(pl)
	for i in 3:
		var n = M.cyl(lh, 0.02, 0.016, Vector3(-0.045 + i * 0.045, 0.035, 0.075), M.iron(), Vector3(0, 0, 0), -1.0, 6)
		nuts.append(n)
	var fl = M.cyl(lh, 0.045, 0.13, Vector3(0.07, -0.08, 0.26), M.rust(Color(0.35, 0.4, 0.3)), Vector3(70, 0, 0)); fl.name = "flask"
	for i in 4:
		var pp = M.box(lh, Vector3(0.012, 0.012, 0.02), Vector3(0.115, -0.05 - i * 0.008, 0.2 + i * 0.03), M.glow(Color(0.4, 0.8, 1.0), 1.2))
		pips.append(pp)

func rebuild_weapons() -> void:
	if wm_melee: wm_melee.queue_free()
	if wm_gun: wm_gun.queue_free()
	wm_melee = WM.make(c.melee.get("id", "laoban"), c.melee, c.world.mods_of(c, c.melee.get("id", "")) if c.world else {})
	rm.add_child(wm_melee); wm_melee.position = Vector3(0, -0.02, 0)
	for b in brass: b.queue_free()
	brass.clear()
	if not c.gun.is_empty():
		wm_gun = WM.make(c.gun["id"], c.gun, c.world.mods_of(c, c.gun["id"]) if c.world else {})
		rg.add_child(wm_gun); wm_gun.position = Vector3(0, 0.02, -0.02)
		for i in min(12, int(c.gun["mag"])):
			var br = M.cyl(rg, 0.008, 0.03, Vector3(-0.035, 0.085, 0.06 - i * 0.022), M.rust(Color(0.85, 0.65, 0.25)), Vector3(90, 0, 0))
			brass.append(br)
	else: wm_gun = null

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not locked:
		using_pad = false
		var s = G.mouse_sens * float(G.opt("sens")) * (0.6 if c.aiming else 1.0)
		yaw -= e.relative.x * s; c.pitch = clamp(c.pitch - e.relative.y * s, -1.45, 1.45)
		sway += e.relative * 0.0004
	elif e is InputEventJoypadButton or (e is InputEventJoypadMotion and abs(e.axis_value) > 0.5): using_pad = true
	elif e is InputEventKey or e is InputEventMouseButton: using_pad = false

var bot = null
func think(d: float) -> void:
	if locked: return
	if bot != null:
		bot.think(c, self, d); c.rotation.y = yaw; return
	var it = c.intent
	it["mv"] = Vector2(Input.get_axis("mv_l", "mv_r"), Input.get_axis("mv_b", "mv_f")).limit_length(1.0)
	var lx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X); var ly = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(lx) > 0.15 or abs(ly) > 0.15:
		yaw -= lx * 3.2 * d; c.pitch = clamp(c.pitch - ly * 2.4 * d, -1.45, 1.45)
	c.rotation.y = yaw
	it["attack_held"] = Input.is_action_pressed("attack"); it["alt"] = Input.is_action_pressed("alt"); it["sprint"] = Input.is_action_pressed("dodge")
	for k in ["attack", "dodge", "switch", "gadget", "core", "core2", "interact", "jump"]:
		if Input.is_action_just_pressed(k): it[k] = true
	if Input.is_action_just_pressed("alt"): it["alt_pressed"] = true
	if Input.is_action_just_pressed("reload"):
		if c.stance == "gun": it["reload"] = true
		else: it["drink"] = true
	if Input.is_action_just_pressed("drink") and c.stance == "melee": it["drink"] = true

func set_yaw(y: float) -> void:
	yaw = y; c.rotation.y = y

func _on_ev(n: String, data) -> void:
	match n:
		"attack":
			var a = P.get(data.get("anim", "swing_r"), P["swing_r"])
			act = {"wu": a[0], "hit": a[1], "t": 0.0, "twu": float(data["wu"]), "tact": float(data["act"]), "hold": false}
			Snd.play("dodge", -14.0, 1.4)
		"charge":
			act = {"wu": P["overhead"][0], "hit": P["overhead"][1], "t": 0.0, "twu": 99.0, "tact": 0.14, "hold": true}
		"release":
			act["twu"] = act.get("t", 0.0)
		"active":
			Snd.play("swing_heavy" if data.get("heavy", false) else "swing", -4.0)
			Fx.fov_kick = -2.0 if data.get("heavy", false) else -0.6
		"fired":
			gun_kick = 1.0; recoil += deg_to_rad(float(data["recoil"])) * 0.5
			Snd.play(c.gun.get("snd", "shot_revolver"), -1.0)
			Fx.add_shake(0.12 + float(data["recoil"]) * 0.02)
			if c.world: Fx.flash(c.world.muzzle_pos(c), Color(1, 0.75, 0.4), 5.0 * float(data["flash"]), 0.07)
			Fx.screen_flash.emit(Color(1, 0.9, 0.7, 0.12 * float(data["flash"])), 0.08)
		"empty": Snd.play("click", -4.0)
		"jam": Snd.play("click", 0.0, 0.6)
		"reload": Snd.play("lever" if c.gun.get("id", "") == "guahao" else "reload", -3.0)
		"switch": Snd.play("card", -8.0)
		"drink": Snd.play("drink", -2.0)
		"dodge": Snd.play("dodge", -5.0)
		"parry":
			parry_kick = 1.0; Snd.play("parry", 1.0); Fx.slowmo(0.3, 0.12); Fx.fov_kick = 4.0; Fx.add_shake(0.25)
			Fx.screen_flash.emit(Color(1, 1, 1, 0.25), 0.15)
			if c.world: Fx.sparks(c.eye() + c.aim_dir() * 0.9, Color(1, 0.85, 0.3), 30, 9.0)
			if c.wrench >= c.wrench_need(): Snd.play("ratchet", -2.0)
		"deflect":
			parry_kick = 1.0; Snd.play("deflect", 2.0); Fx.slowmo(0.3, 0.1); Fx.add_shake(0.3)
			if c.world: Fx.sparks(c.eye() + c.aim_dir() * 0.8, Color(1, 0.9, 0.6), 24, 10.0)
		"blocked":
			Snd.play("hit_block", 0.0); Fx.add_shake(0.35); parry_kick = 0.5
			if c.world: Fx.sparks(c.eye() + c.aim_dir() * 0.8, Color(0.8, 0.3, 0.2), 8, 5.0)
		"hurt":
			hurt_t = 0.35; tilt += randf_range(-0.07, 0.07) + 0.05; Fx.add_shake(0.45)
			Snd.play("hurt", 0.0); Fx.hitstop(0.05)
			Fx.screen_blood.emit(clamp(float(data.get("dmg", 10)) / 35.0, 0.2, 1.0))
		"dealt":
			var out = data["out"]; var info = data["info"]
			if info["kind"] == "melee":
				if out == "hit": Fx.hitstop(0.09 if info.get("heavy", false) else 0.045); Fx.add_shake(0.3 if info.get("heavy", false) else 0.12)
				elif out == "parry": Snd.play("parry", -2.0, 0.8); Fx.add_shake(0.4)
		"disarm_try":
			seq = {"lh": [[0.0, P["l_idle"][0], P["l_idle"][1]], [0.16, P["l_reach"][0], P["l_reach"][1]], [0.34, P["l_twist"][0], P["l_twist"][1]], [0.6, P["l_idle"][0], P["l_idle"][1]]]}; seq_t = 0.0
		"disarm_ok":
			Snd.play("disarm", 3.0); Fx.slowmo(0.2, 0.3); Fx.add_shake(0.3)
		"disarm_fail", "nocore": Snd.play("click", -6.0, 0.7)
		"mods": if data != null: Snd.play("disarm", 0.0, 0.8)

func play_seq(sq: Dictionary) -> void:
	seq = sq; seq_t = 0.0

func _process(d: float) -> void:
	if c == null: return
	var rd = d
	# 攝影機
	recoil = lerp(recoil, 0.0, clamp(d * 7.0, 0, 1)); tilt = lerp(tilt, 0.0, clamp(d * 6.0, 0, 1))
	if not cine:
		var sh = Fx.shake
		cam.rotation = Vector3(c.pitch + recoil + randf_range(-1, 1) * sh * 0.03, randf_range(-1, 1) * sh * 0.03, tilt + randf_range(-1, 1) * sh * 0.02)
		var hs = Vector2(c.velocity.x, c.velocity.z).length()
		if c.is_on_floor() and hs > 0.5:
			bob += d * hs * 1.9; step_t -= d * hs
			if step_t <= 0:
				step_t = 2.6; Snd.play("step_water" if c.water > 0 else "step", -12.0)
		var by = sin(bob * 2.0) * 0.03 * min(1.0, hs / 4.0)
		var crouch = -0.5 if c.state == St.BROKEN else (-0.25 if c.state == St.DODGE else 0.0)
		cam.position = cam.position.lerp(Vector3(sin(bob) * 0.02, 1.62 + by + crouch, 0), clamp(d * 12.0, 0, 1))
		var f = float(G.opt("fov")) + Fx.fov_kick
		if c.stance == "gun" and c.aiming: f -= 22.0 if c.world and c.world.mods_of(c, c.gun.get("id", "")).get("sight", "") == "optic" else 12.0
		if c.intent["sprint"] and hs > 5.0: f += 5.0
		cam.fov = lerp(cam.fov, f, clamp(d * 10.0, 0, 1))
	_vm(rd)
	_diegetic()

func _vm(d: float) -> void:
	var melee_s = c.stance == "melee"
	var tm = P["m_idle"] if melee_s else P["m_low"]
	var tg = P["g_low"] if melee_s else (P["g_aim"] if c.aiming else P["g_idle"])
	var tl = P["l_idle"] if melee_s else P["l_gun"]
	var rate = 12.0
	match c.state:
		St.BLOCK:
			tm = P["m_block"]; tl = P["l_block"]; rate = 22.0
		St.RELOAD, St.JAM: tg = P["g_reload"]
		St.DRINK:
			tl = P["l_drink"]; tm = P["m_low"]
		St.BROKEN, St.DEAD, St.VICTIM:
			tm = P["m_low"]; tg = P["g_low"]; tl = P["l_low"]
		St.STUN: tm = [P["m_idle"][0] + Vector3(0.1, -0.15, 0.1), Vector3(-40, 0, 40)]
	if c.draw_t > 0 and not melee_s: tg = [tg[0] + Vector3(0, -0.25 * min(1.0, c.draw_t * 4.0), 0), tg[1] + Vector3(-30 * min(1.0, c.draw_t * 4.0), 0, 0)]
	if not act.is_empty() and c.state == St.ATTACK:
		act["t"] += d
		var t = act["t"]
		if t < act["twu"]:
			tm = act["wu"]; rate = 3.0 / max(0.08, min(0.5, act["twu"])) + 4.0
			if act.get("hold", false): tm = [tm[0] + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.006 * min(2.0, t * 3.0), tm[1]]
		elif t < act["twu"] + act["tact"] + 0.08:
			tm = act["hit"]; rate = 38.0
		else: rate = 7.0
	elif c.state != St.ATTACK: act = {}
	# 慣性擺動
	sway = sway.lerp(Vector2.ZERO, clamp(d * 8.0, 0, 1))
	var sw = Vector3(-sway.x, sway.y, 0) + Vector3(sin(bob) * 0.008, abs(cos(bob)) * 0.008, 0)
	var breathe = Vector3(0, sin(Time.get_ticks_msec() * 0.002) * 0.004, 0)
	var shake_v = Vector3.ZERO
	if c.stam < 15.0: shake_v = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004
	gun_kick = lerp(gun_kick, 0.0, clamp(d * 12.0, 0, 1)); parry_kick = lerp(parry_kick, 0.0, clamp(d * 10.0, 0, 1))
	var a = clamp(rate * d, 0.0, 1.0)
	rm.position = rm.position.lerp(tm[0] + sw + breathe + shake_v + Vector3(0, 0, 0.12) * parry_kick, a); rm.rotation_degrees = rm.rotation_degrees.lerp(tm[1], a)
	rg.position = rg.position.lerp(tg[0] + sw * 0.7 + breathe + Vector3(0, 0.02, 0.09) * gun_kick, clamp(14.0 * d, 0, 1)); rg.rotation_degrees = rg.rotation_degrees.lerp(tg[1] + Vector3(14, 0, 0) * gun_kick, clamp(14.0 * d, 0, 1))
	lh.position = lh.position.lerp(tl[0] + sw * 0.8 + breathe, clamp(12.0 * d, 0, 1)); lh.rotation_degrees = lh.rotation_degrees.lerp(tl[1], clamp(12.0 * d, 0, 1))
	# 腳本動畫覆寫
	if not seq.is_empty():
		seq_t += d
		var done = true
		for hn in seq:
			var h = {"rm": rm, "rg": rg, "lh": lh}[hn]
			var ks = seq[hn]
			if seq_t < ks[ks.size() - 1][0]: done = false
			for i in range(ks.size() - 1):
				if seq_t >= ks[i][0] and seq_t < ks[i + 1][0]:
					var u = (seq_t - ks[i][0]) / max(0.001, ks[i + 1][0] - ks[i][0]); u = u * u * (3.0 - 2.0 * u)
					h.position = ks[i][1].lerp(ks[i + 1][1], u); h.rotation_degrees = ks[i][2].lerp(ks[i + 1][2], u)
		if done: seq = {}

func _diegetic() -> void:
	var fr = c.hp / max(1.0, c.hp_max)
	for i in 5:
		plates[i].visible = fr > i * 0.2 + 0.001
	var need = c.wrench_need()
	for i in 3:
		nuts[i].visible = i < need
		nuts[i].material_override = M.glow(Color(1.0, 0.75, 0.2), 2.5 if c.wrench >= need else 1.0) if i < c.wrench else M.iron()
	for i in 4: pips[i].visible = i < c.flasks
	for i in brass.size(): brass[i].visible = i < c.ammo
	if wm_melee:
		var mm = wm_melee.get_node_or_null("warn")
		if mm: mm.visible = true

func blood_on_hands() -> void:
	for h in [rm, lh]:
		M.ball(h, 0.05, Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(0.0, 0.2)), M.blood(), Vector3(1, 0.4, 1.6))
