extends RefCounted
# 演出：入場、處決、死亡、過關。鏡頭永遠是玩家的頭。
const St = preload("res://src/combatant.gd").St
const M = preload("res://src/mat.gd")
const PP = preload("res://src/player.gd").P

static func wait(w: Node, s: float) -> void:
	await w.get_tree().create_timer(s).timeout

static func _line(w, i: int) -> float:
	var L = w.bcfg["lines"]["intro"]
	if i >= L.size(): return 0.0
	return w.say(w.bcfg["name"], w.bcfg["voice"], L[i])

static func intro(w) -> void:
	var p = w.player; var pc = w.pctrl; var b = w.boss; var rig = w.body.rig; var L = w.bcfg["lines"]; var id = w.bid
	pc.locked = true; p.set_state(St.CINE); b.set_state(St.CINE)
	Snd.play("gate", -2.0)
	await wait(w, 1.0)
	var gate_n = "第%s閘" % ["一", "二", "三", "四", "五", "六"][D.ORDER.find(id)]
	match id:
		"bao":
			await wait(w, w.laba(L["laba_intro"]) * 0.75)
			b.global_position = p.global_position + p.fwd() * 1.9; b.rotation.y = p.rotation.y + PI
			await wait(w, _line(w, 0))
			rig.pose("lift"); pc.cine = true
			var tw = w.create_tween(); tw.tween_property(pc.cam, "position:y", 2.25, 0.35).set_trans(Tween.TRANS_BACK)
			await tw.finished
			for i in 2:
				var t2 = w.create_tween(); t2.tween_property(pc.cam, "position:y", 2.05, 0.16); t2.tween_property(pc.cam, "position:y", 2.25, 0.16)
				Fx.add_shake(0.3); Snd.play("step", 0.0, 0.7)
				await t2.finished
			var d = _line(w, 1)
			await wait(w, d)
			var t3 = w.create_tween(); t3.tween_property(pc.cam, "position:y", 1.62, 0.12)
			await t3.finished
			Fx.add_shake(0.8); Snd.play("thump", 0.0); rig.pose(""); pc.cine = false
			w.hud.title(gate_n, "老鮑")
			await wait(w, 2.2)
		"xue":
			await wait(w, w.laba(L["laba_intro"]) * 0.75)
			Snd.play("card", 4.0); Fx.add_shake(0.4); Fx.screen_flash.emit(Color(0.95, 0.9, 0.7, 0.5), 0.2)
			var t0 = w.create_tween(); t0.tween_property(p, "pitch", -0.9, 0.3); t0.tween_interval(0.6)
			await t0.finished
			b.global_position = p.global_position + p.fwd() * 9.0 + Vector3(0, 3.2, 0); b.rotation.y = p.rotation.y + PI; rig.pose("hang")
			var t1 = w.create_tween(); t1.tween_property(p, "pitch", 0.32, 0.35)
			await t1.finished
			await wait(w, _line(w, 0)); await wait(w, _line(w, 1) * 0.7)
			rig.pose("")
			var t4 = w.create_tween(); t4.tween_property(b, "global_position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await t4.finished
			Fx.dust(b.global_position, 14); Snd.play("thump", 0.0)
			var t5 = w.create_tween(); t5.tween_property(p, "pitch", 0.0, 0.3)
			w.hud.title(gate_n, "薛快")
			await wait(w, 2.2)
		"ruan":
			await wait(w, w.laba(L["laba_intro"]) * 0.8)
			b.rotation.y = 0.0; rig.pose("feed")
			var tgt = b.global_position + Vector3(0, 0, 5.0)
			var t6 = w.create_tween(); t6.tween_property(p, "global_position", Vector3(tgt.x, p.global_position.y, tgt.z), 3.2)
			await t6.finished
			await wait(w, _line(w, 0))
			var t7 = w.create_tween(); t7.tween_property(b, "rotation:y", PI, 1.2); rig.pose("")
			await wait(w, _line(w, 1)); await wait(w, _line(w, 2))
			w.hud.title(gate_n, "阮金枝")
			await wait(w, 2.2)
		"yaling":
			Snd.play("click", 6.0, 0.5)
			var t8 = w.create_tween(); t8.tween_property(p, "pitch", -1.1, 0.25); t8.tween_interval(0.7); t8.tween_property(p, "pitch", 0.0, 0.4)
			await t8.finished
			await wait(w, w.show_card("你好") + 0.2)
			await wait(w, w.show_card("不要踩") + 0.2)
			await wait(w, w.laba(L["laba_intro"]) * 0.8)
			w.hud.title(gate_n, "啞鈴")
			await wait(w, 2.2)
		"ge":
			await wait(w, w.laba(L["laba_intro"]) * 0.75)
			w.arena.raise_around(p.global_position); Fx.add_shake(0.6)
			await wait(w, 0.9)
			rig.pose("watch")
			await wait(w, _line(w, 0))
			rig.pose("")
			await wait(w, _line(w, 1))
			w.hud.title(gate_n, "葛蘭")
			await wait(w, 2.2)
		"zha":
			b.global_position = Vector3(1.6, 0, -13.5); b.rotation.y = PI; rig.pose("sit")
			var t9 = w.create_tween(); t9.tween_property(p, "global_position", Vector3(1.2, p.global_position.y, -9.5), 5.0)
			await t9.finished
			rig.pose("offer")
			await wait(w, _line(w, 0))
			Snd.play("drink", 0.0); p.hp = p.hp_max
			await wait(w, 1.2)
			rig.pose("sit")
			await wait(w, _line(w, 1)); await wait(w, _line(w, 2))
			rig.pose("")
			await wait(w, 1.0)
			w.hud.title(gate_n, "閘主", 2.0)
			await wait(w, 2.0)
	pc.set_yaw(p.rotation.y)
	p.set_state(St.IDLE); b.set_state(St.IDLE); pc.locked = false; pc.cine = false

# 處決動畫：手部關鍵影格 + 命中時間點
static func _exec_plan(cls: String) -> Dictionary:
	var mi = PP["m_idle"]; var li = PP["l_idle"]; var gi = PP["g_idle"]
	match cls:
		"blunt":
			return {"seq": {"lh": [[0.0, li[0], li[1]], [0.3, Vector3(-0.05, -0.05, -0.85), Vector3(0, 0, 60)], [2.0, Vector3(-0.1, -0.1, -0.7), Vector3(0, 0, 60)], [2.4, li[0], li[1]]],
				"rm": [[0.0, mi[0], mi[1]], [0.55, Vector3(0.5, -0.75, -0.3), Vector3(-120, 0, -20)], [0.72, Vector3(0.1, 0.15, -0.8), Vector3(20, 0, 10)], [1.2, Vector3(0.3, 0.35, -0.3), Vector3(50, 0, 0)], [1.38, Vector3(0.05, -0.45, -0.85), Vector3(-110, 0, 5)], [2.0, Vector3(0.1, -0.4, -0.8), Vector3(-100, 0, 5)], [2.4, mi[0], mi[1]]]},
				"hits": [[0.7, "smash", "head"], [1.38, "smash", "head"]]}
		"blade":
			return {"seq": {"lh": [[0.0, li[0], li[1]], [0.25, Vector3(-0.3, -0.1, -0.7), Vector3(0, 40, 0)], [0.5, Vector3(-0.6, -0.3, -0.4), Vector3(0, 60, 0)], [2.3, li[0], li[1]]],
				"rm": [[0.0, mi[0], mi[1]], [0.5, Vector3(0.65, 0.05, -0.4), Vector3(-10, 0, -80)], [0.66, Vector3(-0.5, -0.25, -0.7), Vector3(-60, 0, 85)], [1.2, Vector3(-0.4, 0.1, -0.5), Vector3(-10, 0, 80)], [1.36, Vector3(0.55, -0.3, -0.7), Vector3(-60, 0, -80)], [1.9, Vector3(0.5, -0.5, -0.5), Vector3(-80, 0, -30)], [2.3, mi[0], mi[1]]]},
				"hits": [[0.62, "slash", "sh_l"], [1.34, "slash", "head"]]}
		"pole":
			return {"seq": {"rm": [[0.0, mi[0], mi[1]], [0.4, Vector3(0.6, -0.6, -0.4), Vector3(-80, 0, -60)], [0.58, Vector3(-0.4, -0.7, -0.7), Vector3(-80, 0, 60)], [1.1, Vector3(0.2, 0.3, -0.4), Vector3(160, 0, 0)], [1.3, Vector3(0.15, -0.5, -0.6), Vector3(175, 0, 0)], [2.0, Vector3(0.15, -0.4, -0.6), Vector3(170, 0, 0)], [2.3, mi[0], mi[1]]]},
				"hits": [[0.56, "sweep", ""], [1.3, "smash", "head"]]}
		"short":
			return {"seq": {"rg": [[0.0, gi[0], gi[1]], [0.3, Vector3(0.3, 0.1, -0.3), Vector3(60, 0, -30)], [0.45, Vector3(0.05, -0.1, -0.8), Vector3(-30, 0, -30)], [0.9, gi[0] + Vector3(0, 0, 0.15), gi[1]], [1.25, Vector3(0.12, -0.2, -0.5), Vector3(0, 0, 0)], [1.32, Vector3(0.12, -0.14, -0.38), Vector3(22, 0, 0)], [2.0, gi[0], gi[1]]]},
				"hits": [[0.45, "smash", ""], [1.27, "shot", "head"]]}
		_:
			return {"seq": {"rg": [[0.0, gi[0], gi[1]], [0.5, Vector3(0.1, -0.12, -0.75), Vector3(-6, 0, 0)], [1.1, Vector3(0.1, -0.12, -0.78), Vector3(-6, 0, 0)], [1.17, Vector3(0.1, -0.06, -0.6), Vector3(16, 0, 0)], [2.0, gi[0], gi[1]]]},
				"hits": [[1.12, "shot", "head"]]}

static func execution(w, att, vic) -> void:
	var story = w.story
	var final = (not story) or vic.state == St.KNEEL
	if att != w.player:
		return
	var pc = w.pctrl
	pc.locked = true; att.set_state(St.EXEC); vic.set_state(St.VICTIM)
	if final and story: Snd.music("")
	var to = vic.global_position - att.global_position; to.y = 0
	pc.set_yaw(atan2(-to.x, -to.z))
	var tw0 = w.create_tween(); tw0.set_parallel()
	tw0.tween_property(att, "pitch", -0.12, 0.2)
	if vic.local or vic.is_boss:
		tw0.tween_property(vic, "global_position", att.global_position + to.normalized() * 1.55, 0.2)
		vic.rotation.y = atan2(to.x, to.z)
	var cls = "blunt"
	if att.stance == "gun": cls = att.gun.get("cls", "short")
	else: cls = att.melee.get("cls", "blunt")
	var plan = _exec_plan(cls)
	pc.play_seq(plan["seq"])
	var rig = w.body.rig
	var tprev = 0.0
	Fx.fov_kick = -6.0
	for h in plan["hits"]:
		await wait(w, h[0] - tprev); tprev = h[0]
		var dir = att.fwd()
		var pos = rig.head_pos() if h[2] == "head" and rig.J.has("head") else rig.chest_pos()
		match h[1]:
			"smash":
				Snd.play("hit_flesh", 4.0, 0.7); Snd.play("splat", 3.0)
			"slash":
				Snd.play("swing_heavy", 0.0, 1.3); Snd.play("splat", 4.0, 1.2)
			"sweep":
				Snd.play("swing_heavy", 0.0); Snd.play("hit_flesh", 2.0)
			"shot":
				Snd.play(att.gun.get("snd", "shot_revolver"), 3.0); Fx.flash(pos, Color(1, 0.8, 0.4), 8.0, 0.1); pc.gun_kick = 1.5
		Fx.gore(pos, dir + Vector3(0, 0.6, 0), 8); Fx.blood(pos, -dir + Vector3(0, 0.8, 0), 60); Fx.gush(rig.J.get("chest", rig), Vector3(0, 0.3, -0.1), 1.2, 1.5)
		Fx.hitstop(0.11); Fx.add_shake(0.9); Fx.screen_blood.emit(1.0); pc.blood_on_hands(); rig.flinch(dir); Fx.fov_kick = 5.0
		if final and h == plan["hits"][plan["hits"].size() - 1]:
			if h[2] != "" and rig.J.has(h[2]): rig.sever(h[2], dir * 4.0 + Vector3(randf_range(-2, 2), 6, 0))
			if rig.J.has("head") and h[2] != "head": rig.sever("head", dir * 3.0 + Vector3(0, 6, 0))
			if cls == "blade" and rig.J.has("sh_r"): rig.sever("sh_r", dir * 2.0 + Vector3(3, 4, 0))
			rig.pose("dead"); rig.dead = true
			for i in 6: Fx.pool(vic.global_position + Vector3(randf_range(-1.5, 1.5), 0.3, randf_range(-1.5, 1.5)), randf_range(0.5, 1.2))
		elif not final and h == plan["hits"][plan["hits"].size() - 1] and h[2] != "head":
			pass
	await wait(w, 0.75)
	G.S["prompts"]["interact"] = int(G.S["prompts"].get("interact", 0)) + 1
	if not att.gun.is_empty():
		att.ammo = int(att.gun["mag"])
	att.wrench = min(3, att.wrench + 1)
	if final:
		if vic.is_boss or vic.local:
			vic.set_state(St.DEAD); vic.ev.emit("dead", "")
	else:
		vic.impulse = to.normalized() * 9.0
		vic.next_bar()
	att.set_state(St.IDLE); att.invuln_t = 0.6; pc.locked = false

static func death(w) -> void:
	var p = w.player; var pc = w.pctrl; var b = w.boss
	pc.locked = true; pc.cine = true
	var rig = w.body.rig
	if b.local and b.alive() and b.state != St.KNEEL:
		b.set_state(St.CINE)
		var to = p.global_position - b.global_position; to.y = 0
		b.rotation.y = atan2(-to.x, -to.z)
		if to.length() > 2.6:
			var tw = w.create_tween(); tw.tween_property(b, "global_position", p.global_position - to.normalized() * 2.2, 0.35)
		rig.play("overhead", 0.45, 0.15, 1.0)
		await wait(w, 0.47)
	Snd.play("hit_flesh", 5.0, 0.6); Snd.play("splat", 5.0); Fx.screen_blood.emit(1.0); Fx.screen_blood.emit(1.0); Fx.add_shake(1.2); Fx.hitstop(0.12)
	Fx.blood(p.eye() + p.aim_dir() * 0.5, Vector3.UP, 60)
	var tw2 = w.create_tween(); tw2.set_parallel()
	tw2.tween_property(pc.cam, "position", Vector3(0.2, 0.22, 0.3), 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw2.tween_property(pc.cam, "rotation", Vector3(0.35, pc.cam.rotation.y + 0.3, 1.35), 0.5)
	await tw2.finished
	Snd.play("thump", 0.0, 0.7); Snd.play("heartbeat", 3.0)
	for i in 5: Fx.pool(p.global_position + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.8, 0.8)), randf_range(0.4, 0.9))
	await wait(w, 0.5)

static func win(w, killed: bool) -> void:
	var L = w.bcfg["lines"]
	await wait(w, 0.8)
	if L["laba_win"] != "": await wait(w, w.laba(L["laba_win"]))
	Snd.play("gate", 3.0); Fx.add_shake(0.5)
	# 閘開了，頭上漏水
	var ps = CPUParticles3D.new(); ps.amount = 220; ps.lifetime = 2.2; ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; ps.emission_box_extents = Vector3(w.arena.half.x, 0.2, w.arena.half.y)
	var q = BoxMesh.new(); q.size = Vector3(0.02, 0.5, 0.02); ps.mesh = q; ps.material_override = M.ghost(Color(0.7, 0.9, 1.0, 0.5)); ps.gravity = Vector3(0, -30, 0)
	w.add_child(ps); ps.position = Vector3(0, 14, 0)
	Snd.ambience("amb_water", -6.0)
	w.hud.title("", "開閘", 2.6)
	await wait(w, 3.4)
