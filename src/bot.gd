extends RefCounted
# 測試用：自動操作玩家。skill 0..1 決定彈反成功率與反應。
const St = preload("res://src/combatant.gd").St
var skill = 0.6
var decided = -1
var will_parry = false
var will_block = false
var hold_block = 0.0
var stats = {"parry": 0, "hurt": 0, "exec": 0, "disarm": 0}

func think(c, pc, d: float) -> void:
	var b = c.target
	var it = c.intent
	it["mv"] = Vector2.ZERO; it["alt"] = false; it["attack_held"] = false; it["sprint"] = false
	if b == null or not c.alive(): return
	var to = b.global_position - c.global_position; to.y = 0
	var dist = to.length()
	pc.yaw = atan2(-to.x, -to.z); c.pitch = 0.0
	if (b.state == St.BROKEN or b.state == St.KNEEL):
		if dist > 2.6: it["mv"] = Vector2(0, 1)
		else:
			it["interact"] = true; stats["exec"] += 1
		return
	if c.stance != "melee":
		it["switch"] = true; return
	if c.hp < c.hp_max * 0.4 and c.flasks > 0 and dist > 4.5 and b.state != St.ATTACK:
		it["drink"] = true; return
	hold_block -= d
	if b.state == St.ATTACK and b.st_t < float(b.move.get("wu", 0)) + 0.05:
		if decided != b.move_seq:
			decided = b.move_seq; will_parry = randf() < skill * 0.7; will_block = randf() < 0.3 + 0.5 * skill
		var left = float(b.move.get("wu", 0)) - b.st_t
		var kind = b.move.get("kind", "melee")
		var threat = (kind == "melee" and dist < float(b.move.get("reach", 2.5)) + 1.5) or kind == "shot"
		if kind == "fn":
			if b.move.get("fn", "") in ["disarm"] and left < 0.3: it["mv"] = Vector2(0, -1); it["dodge"] = left < 0.25 and c.state == St.IDLE
			elif dist < 3.0: it["attack"] = true
			else: it["mv"] = Vector2(0, 1)
			return
		if c.wrench >= c.wrench_need() and b.move.has("part") and not b.parts_off.has(b.move["part"]) and dist < 3.0 and randf() < skill:
			it["core"] = true; return
		if threat:
			if b.move.get("unb", false):
				if left < 0.28 and c.state == St.IDLE and will_parry:
					it["mv"] = Vector2(1, -0.5); it["dodge"] = true
				elif not will_parry: it["mv"] = Vector2(0, -1)
				return
			if will_parry:
				if left < 0.09:
					it["alt"] = true; hold_block = 0.3
			elif will_block:
				if left < 0.3: hold_block = 0.4
			elif dist < 2.6 and c.stam > 25 and c.state == St.IDLE: it["attack"] = true
			return
	if hold_block > 0:
		it["alt"] = true; return
	if dist > 2.3: it["mv"] = Vector2(0.2, 1)
	elif c.stam > 25 and c.state == St.IDLE: it["attack"] = true
