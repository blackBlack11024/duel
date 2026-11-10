extends Node3D
# 第三人稱身體：Boss 與連線對手用。聽 combatant 的事件播動作、噴血。
const M = preload("res://src/mat.gd")
const WM = preload("res://src/wm.gd")
const RigS = preload("res://src/rig.gd")
const St = preload("res://src/combatant.gd").St
var c
var rig
var w_melee: Node3D
var w_gun: Node3D
var aimline: MeshInstance3D
var last_pos = Vector3.ZERO
var glint_seq = -1
var drip_t = 0.0
var stains = 0

func setup(comb, params: Dictionary, melee_id: String, gun_id: String) -> void:
	c = comb
	rig = RigS.new(); add_child(rig); rig.build(params)
	set_weapons(melee_id, gun_id)
	c.ev.connect(_on_ev)
	aimline = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(0.012, 0.012, 1.0); aimline.mesh = bm
	aimline.material_override = M.glow(Color(1, 0.15, 0.1), 3.0); aimline.visible = false; add_child(aimline); aimline.top_level = true
	last_pos = c.global_position

func set_weapons(melee_id: String, gun_id: String) -> void:
	if w_melee: w_melee.queue_free()
	if w_gun: w_gun.queue_free()
	w_melee = null; w_gun = null
	if melee_id != "" and rig.J.has("hand_r"):
		w_melee = WM.make(melee_id); rig.J["hand_r"].add_child(w_melee); w_melee.rotation_degrees = Vector3(-90, 0, 0)
	if gun_id != "" and rig.J.has("hand_l"):
		w_gun = WM.make(gun_id); rig.J["hand_l"].add_child(w_gun); w_gun.rotation_degrees = Vector3(-90, 0, 0); w_gun.scale = Vector3.ONE * 1.25

func muzzle() -> Vector3:
	if w_gun and is_instance_valid(w_gun): return WM.muzzle(w_gun)
	return rig.chest_pos() + c.fwd() * 0.6

func _on_ev(n: String, data) -> void:
	match n:
		"attack":
			rig.play(data.get("anim", "swing_r"), float(data["wu"]), float(data.get("act", 0.14)), float(data.get("rec", 0.5)))
			if data.get("unb", false):
				WM.warn(w_melee if data.get("kind", "melee") != "shot" else w_gun, true); Snd.at("warn", c.global_position, 2.0)
			elif data.get("kind", "melee") == "melee": Snd.at("dodge", c.global_position, -6.0, 0.7)
		"release":
			rig.action["twu"] = rig.action["t"] if rig.action != null else 0.0
		"active":
			WM.warn(w_melee, false); WM.warn(w_gun, false)
			if data.get("kind", "melee") == "melee": Snd.at("swing_heavy" if float(data.get("dmg", 0)) >= 26 else "swing", c.global_position, 0.0, 0.85)
		"state":
			WM.warn(w_melee, false); WM.warn(w_gun, false)
			var s = int(data)
			if s != St.ATTACK: rig.stop()
			rig.pose({St.BLOCK: "guard", St.BROKEN: "broken", St.KNEEL: "broken", St.STUN: "stagger", St.DEAD: "dead", St.RELOAD: "reload", St.DRINK: "watch", St.VICTIM: "broken"}.get(s, ""))
			if s == St.DEAD: rig.dead = true
		"hurt":
			var dir: Vector3 = data.get("dir", Vector3.ZERO)
			var dmg = float(data.get("dmg", 10))
			if data.get("kind", "") != "dot":
				var pos = rig.chest_pos() - dir * 0.2 + Vector3(0, randf_range(-0.3, 0.2), 0)
				Fx.blood(pos, dir + Vector3(0, 0.5, 0), int(clamp(dmg * 1.6, 14, 70)))
				if dmg >= 24 or data.get("heavy", false): Fx.gore(pos, dir, 3)
				Snd.at("hit_flesh", pos, 2.0); Snd.at("splat", pos, -2.0)
				rig.flinch(dir); _stain()
		"blocked", "block":
			if n == "blocked":
				Snd.at("hit_block", c.global_position, 1.0); Fx.sparks(rig.chest_pos() + c.fwd() * 0.5, Color(1, 0.7, 0.3), 10, 5.0)
			rig.pose("guard")
			get_tree().create_timer(0.45).timeout.connect(func(): if is_instance_valid(self) and c.state == St.IDLE: rig.pose(""))
		"parry", "deflect":
			Fx.sparks(rig.chest_pos() + c.fwd() * 0.6, Color(1, 0.9, 0.4), 26, 9.0); Snd.at("parry", c.global_position, 2.0)
		"broken":
			Snd.at("break", c.global_position, 3.0); Fx.sparks(rig.chest_pos(), Color(1, 0.6, 0.2), 30, 8.0)
			for i in 3: Fx.gib(rig.chest_pos(), c.fwd() * 3.0 + Vector3(randf_range(-3, 3), 4, randf_range(-3, 3)), Vector3(0.12, 0.09, 0.03), M.steel())
		"lost_part":
			Fx.gib(rig.chest_pos() + c.fwd() * 0.5, c.fwd() * 2.0 + Vector3(randf_range(-2, 2), 5, randf_range(-2, 2)), Vector3(0.08, 0.08, 0.08), M.glow(Color(1, 0.8, 0.3), 1.0), 25.0)
		"dodge": Snd.at("dodge", c.global_position, -3.0)
		"switch":
			if w_melee: w_melee.visible = c.stance == "melee" or c.is_boss
		"fired":
			Snd.at(c.gun.get("snd", "shot_revolver"), c.global_position, 3.0); Fx.flash(muzzle(), Color(1, 0.7, 0.3), 5.0, 0.08)

func _stain() -> void:
	if stains > 14 or not rig.J.has("chest"): return
	stains += 1
	var j = rig.J[["chest", "spine", "head"][randi() % 3]] if rig.J.has("head") else rig.J["chest"]
	M.ball(j, randf_range(0.04, 0.09), Vector3(randf_range(-0.2, 0.2), randf_range(0, 0.3), -0.14 * float(rig.p.get("bulk", 1.0)) * rig.s), M.blood(), Vector3(1, 1.5, 0.3))

func _process(d: float) -> void:
	if c == null: return
	var v = (c.global_position - last_pos) / max(d, 0.001); v.y = 0; last_pos = c.global_position
	rig.move_speed = lerp(rig.move_speed, v.length() if c.state != St.DODGE else 0.0, clamp(d * 10.0, 0, 1))
	rig.wobble = c.posture / max(1.0, c.posture_max)
	if c.is_boss: rig.set_bar(c.bar_i, c.hp / max(1.0, c.hp_max))
	# 瀕死持續滴血
	if c.hp / max(1.0, c.hp_max) < 0.5 and c.alive():
		drip_t -= d
		if drip_t <= 0:
			drip_t = 0.5 + c.hp / max(1.0, c.hp_max); Fx.pool(c.global_position + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), randf_range(0.08, 0.2))
	# 瞄準線
	var show = c.state == St.ATTACK and c.move.get("kind", "") == "shot" and c.st_t < float(c.move.get("wu", 0)) and c.local
	aimline.visible = show
	if show:
		var a = muzzle(); var b = c.aim_lock
		var len = a.distance_to(b)
		if len > 0.3:
			aimline.global_position = (a + b) * 0.5; aimline.scale = Vector3(1, 1, len)
			aimline.look_at(b, Vector3.UP if abs((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	# 可卸件的反光
	if c.is_boss and c.state == St.ATTACK and c.move.has("part") and not c.parts_off.has(c.move["part"]) and c.target != null and c.target.wrench >= c.target.wrench_need():
		if glint_seq != c.move_seq:
			glint_seq = c.move_seq; Snd.at("ding", c.global_position, 0.0)
			var w = w_gun if c.move.get("kind", "") == "shot" and w_gun else w_melee
			if w == null: w = rig.J.get("chest")
			if w: Fx.sparks(w.global_position, Color(1, 1, 0.8), 6, 1.5)

func can_glint() -> bool:
	return c.is_boss and c.state == St.ATTACK and c.move.has("part") and not c.parts_off.has(c.move["part"]) and c.st_t < float(c.move.get("wu", 0)) + 0.2
