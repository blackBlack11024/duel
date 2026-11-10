extends RefCounted
# 場上物件：手榴彈、地雷、蜂巢、煙、蟲群、鋸片。
const M = preload("res://src/mat.gd")

class Obj extends Node3D:
	var world
	var owner_c
	var kind = ""
	var body: StaticBody3D
	func hitbox(r: float) -> void:
		body = StaticBody3D.new(); body.collision_layer = 4; body.collision_mask = 0
		var cs = CollisionShape3D.new(); var sh = SphereShape3D.new(); sh.radius = r; cs.shape = sh; body.add_child(cs); add_child(body)
		body.set_meta("obj", self)
	func melee_hit(_by, _mv: Dictionary) -> void: pass
	func shot_hit(_by, _dmg: float) -> void: pass
	func remove() -> void:
		if world: world.objs.erase(self)
		queue_free()

class Grenade extends Obj:
	var vel = Vector3.ZERO
	var dmg = 34.0
	var post = 38.0
	var manual = true
	var fuse = 3.0
	var landed = false
	var auto_t = 2.0
	var age = 0.0
	var light: OmniLight3D
	func _ready() -> void:
		kind = "grenade"
		M.ball(self, 0.13, Vector3.ZERO, M.iron()); M.cyl(self, 0.04, 0.08, Vector3(0, 0.13, 0), M.rust())
		light = OmniLight3D.new(); light.light_color = Color(1, 0.2, 0.1); light.omni_range = 2.5; light.light_energy = 0.0; add_child(light)
		hitbox(0.35)
	func _physics_process(d: float) -> void:
		age += d
		light.light_energy = 2.0 * (0.5 + 0.5 * sin(age * (10.0 if landed else 20.0)))
		if not landed:
			vel.y -= 18.0 * d
			var nxt = global_position + vel * d
			var r = world.ray(global_position, nxt + vel.normalized() * 0.15, [], 1)
			if not r.is_empty():
				var n: Vector3 = r["normal"]
				vel = vel.bounce(n) * 0.35; global_position = r["position"] + n * 0.14
				Snd.at("click", global_position, -3.0, 0.6)
				if vel.length() < 2.0 and n.y > 0.6:
					landed = true; vel = Vector3.ZERO
			else: global_position = nxt
			rotation += Vector3(d * 9.0, d * 4.0, 0)
		if not manual:
			fuse -= d
			if fuse <= 0: detonate()
		if age > 14.0: detonate()
	func melee_hit(by, _mv: Dictionary) -> void:
		# 打回去
		var to = by.fwd()
		if by.target != null:
			to = (by.target.global_position - global_position); to.y = 0; to = to.normalized()
		vel = to * 15.0 + Vector3(0, 4.5, 0); landed = false; owner_c = by; manual = false; fuse = 0.9
		Snd.at("hit_block", global_position, 2.0, 1.3); Fx.sparks(global_position, Color(1, 0.8, 0.4), 8, 4.0)
		if not by.is_boss: G.S["prompts"]["bat"] = 9
	func shot_hit(_by, _dmg: float) -> void: detonate()
	func detonate() -> void:
		if is_queued_for_deletion(): return
		world.explode(global_position, 4.0, dmg, post, owner_c); remove()

class Mine extends Obj:
	var armed_t = 1.0
	var trig = -1.0
	var t = 0.0
	var light: OmniLight3D
	func _ready() -> void:
		kind = "mine"
		M.cyl(self, 0.2, 0.07, Vector3(0, 0.035, 0), M.rust(Color(0.3, 0.33, 0.22))); M.cyl(self, 0.03, 0.05, Vector3(0, 0.09, 0), M.glow(Color(1, 0.1, 0.05), 2.0))
		light = OmniLight3D.new(); light.light_color = Color(1, 0.1, 0.05); light.omni_range = 1.6; light.position = Vector3(0, 0.2, 0); add_child(light)
		hitbox(0.4); body.position = Vector3(0, 0.15, 0)
	func _physics_process(d: float) -> void:
		t += d; armed_t -= d
		light.light_energy = 1.5 if fmod(t, 1.2) < 0.12 or trig >= 0 else 0.0
		if trig >= 0:
			trig -= d
			if trig <= 0: detonate()
			return
		if armed_t > 0: return
		for cb in world.combatants():
			if cb == owner_c or not cb.alive(): continue
			if cb.global_position.distance_to(global_position) < 1.7 and cb.global_position.y - global_position.y < 0.6:
				trig = 0.55; Snd.at("ui", global_position, 6.0, 1.5)
	func melee_hit(_by, _mv: Dictionary) -> void: trig = 0.3
	func shot_hit(_by, _dmg: float) -> void: detonate()
	func detonate() -> void:
		if is_queued_for_deletion(): return
		world.explode(global_position + Vector3(0, 0.3, 0), 3.6, 36.0, 40.0, owner_c); remove()

class Hive extends Obj:
	var hp = 30.0
	var life = 0.0
	var radius = 3.6
	var snd: AudioStreamPlayer3D
	var bugs: CPUParticles3D
	var tick = 0.0
	func _ready() -> void:
		kind = "hive"
		M.box(self, Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0), M.wood(Color(0.55, 0.45, 0.25))); M.box(self, Vector3(0.7, 0.06, 0.7), Vector3(0, 0.72, 0), M.rust())
		M.box(self, Vector3(0.3, 0.04, 0.02), Vector3(0, 0.15, -0.31), M.cloth(Color(0.05, 0.04, 0.03)))
		hitbox(0.55); body.position = Vector3(0, 0.4, 0)
		var sb = StaticBody3D.new(); var cs = CollisionShape3D.new(); var sh = BoxShape3D.new(); sh.size = Vector3(0.6, 0.7, 0.6); cs.shape = sh; cs.position = Vector3(0, 0.35, 0); sb.add_child(cs); add_child(sb)
		bugs = CPUParticles3D.new(); bugs.amount = 90; bugs.lifetime = 1.6; bugs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; bugs.emission_sphere_radius = radius * 0.8
		var q = SphereMesh.new(); q.radius = 0.02; q.height = 0.04; q.radial_segments = 4; q.rings = 2; bugs.mesh = q; bugs.material_override = M.cloth(Color(0.08, 0.06, 0.02))
		bugs.gravity = Vector3.ZERO; bugs.initial_velocity_min = 1.0; bugs.initial_velocity_max = 3.0; bugs.spread = 180.0; bugs.position = Vector3(0, 1.2, 0); add_child(bugs)
		snd = AudioStreamPlayer3D.new(); var s = Snd.st("bees")
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD; s.loop_end = int(s.get_length() * s.mix_rate)
		snd.stream = s; snd.unit_size = 4.0; snd.volume_db = -4.0; add_child(snd); snd.play()
	func _physics_process(d: float) -> void:
		if life > 0:
			life -= d
			if life <= 0:
				remove(); return
		tick -= d
		if tick > 0: return
		tick = 0.25
		var smoked = world.in_smoke(global_position)
		bugs.emitting = not smoked
		if smoked: return
		for cb in world.combatants():
			if not cb.alive(): continue
			if cb == owner_c and not cb.parts_off.has("vent"): continue
			if cb.global_position.distance_to(global_position) < radius and not world.in_smoke(cb.global_position):
				cb.take({"dmg": 1.4, "post": 0.0, "kind": "dot", "dir": Vector3.ZERO, "move": "hive"})
				cb.set_meta("bugs", 0.6)
	func melee_hit(by, mv: Dictionary) -> void: _dmg(float(mv.get("dmg", 15)), by)
	func shot_hit(by, dmg: float) -> void: _dmg(dmg, by)
	func _dmg(a: float, by) -> void:
		hp -= a; Snd.at("hit_block", global_position, 0.0, 0.6); Fx.dust(global_position + Vector3(0, 0.5, 0), 6, Color(0.5, 0.4, 0.2, 0.6))
		if hp <= 0:
			for i in 6: Fx.gib(global_position + Vector3(0, 0.4, 0), Vector3(randf_range(-4, 4), randf_range(2, 6), randf_range(-4, 4)), Vector3(0.25, 0.04, 0.2), M.wood(Color(0.55, 0.45, 0.25)))
			if owner_c and owner_c.is_boss and by != owner_c: world.boss_say("hive_broken")
			if not by.is_boss: G.S["prompts"]["hive"] = 9
			remove()

class Smoke extends Obj:
	var radius = 5.0
	var life = 9.0
	var ps: CPUParticles3D
	func _ready() -> void:
		kind = "smoke"
		ps = CPUParticles3D.new(); ps.amount = 60; ps.lifetime = 3.0; ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; ps.emission_sphere_radius = radius * 0.7
		var q = SphereMesh.new(); q.radius = 1.0; q.height = 2.0; q.radial_segments = 8; q.rings = 4; ps.mesh = q; ps.material_override = M.ghost(Color(0.72, 0.7, 0.66, 0.42))
		ps.gravity = Vector3(0, 0.2, 0); ps.initial_velocity_max = 0.5; ps.scale_amount_min = 0.8; ps.scale_amount_max = 1.8; ps.position = Vector3(0, 1.2, 0); add_child(ps)
		Snd.at("smoke", global_position, 2.0)
	func _physics_process(d: float) -> void:
		life -= d
		if life < 1.5: ps.emitting = false
		if life <= 0: remove()

class Swarm extends Obj:
	var tgt
	var life = 7.0
	var ps: CPUParticles3D
	var tick = 0.0
	func _ready() -> void:
		kind = "swarm"
		ps = CPUParticles3D.new(); ps.amount = 70; ps.lifetime = 0.7; ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; ps.emission_sphere_radius = 0.7; ps.local_coords = false
		var q = SphereMesh.new(); q.radius = 0.025; q.height = 0.05; q.radial_segments = 4; q.rings = 2; ps.mesh = q; ps.material_override = M.cloth(Color(0.08, 0.06, 0.02))
		ps.gravity = Vector3.ZERO; ps.initial_velocity_max = 2.5; ps.spread = 180.0; add_child(ps)
		hitbox(0.8)
		var snd = AudioStreamPlayer3D.new(); snd.stream = Snd.st("bees"); snd.pitch_scale = 1.4; snd.unit_size = 3.0; add_child(snd); snd.play()
	func _physics_process(d: float) -> void:
		life -= d
		if life <= 0 or tgt == null or not is_instance_valid(tgt) or world.in_smoke(global_position):
			remove(); return
		var to = tgt.global_position + Vector3(0, 1.3, 0) - global_position
		global_position += to.normalized() * min(to.length(), 5.2 * d)
		tick -= d
		if tick <= 0 and to.length() < 1.3:
			tick = 0.25
			tgt.take({"dmg": 2.2, "post": 2.0, "kind": "dot", "dir": Vector3.ZERO, "move": "swarm"}); tgt.set_meta("bugs", 0.6)
	func melee_hit(_by, _mv: Dictionary) -> void:
		Fx.dust(global_position, 8, Color(0.1, 0.08, 0.03, 0.8)); remove()

class Saw extends Obj:
	var vel = Vector3.ZERO
	var bounces = 3
	var stuck = false
	var dmg = 26.0
	var hit_once = false
	var mesh: MeshInstance3D
	func _ready() -> void:
		kind = "saw"
		mesh = M.cyl(self, 0.16, 0.012, Vector3.ZERO, M.steel(), Vector3.ZERO, -1.0, 10)
		Snd.at("saw", global_position, 2.0)
	func _physics_process(d: float) -> void:
		if stuck:
			if owner_c and is_instance_valid(owner_c) and owner_c.global_position.distance_to(global_position) < 1.8:
				owner_c.gadget_uses += 1; Snd.play("pickup", -4.0); remove()
			return
		mesh.rotation.y += d * 40.0
		var nxt = global_position + vel * d
		var r = world.ray(global_position, nxt, [owner_c], 3)
		if not r.is_empty():
			var col = r["collider"]
			if col == owner_c.target and not hit_once:
				hit_once = true
				owner_c.deal({"dmg": dmg, "post": 18.0, "kind": "bullet", "unb": false, "heavy": false, "dir": vel.normalized(), "move": "saw", "bleed": true})
				global_position = nxt; return
			var n: Vector3 = r["normal"]
			Fx.sparks(r["position"], Color(1, 0.8, 0.4), 8, 5.0); Snd.at("hit_block", r["position"], -2.0, 1.5)
			bounces -= 1
			if bounces <= 0:
				stuck = true; global_position = r["position"] + n * 0.05; return
			vel = vel.bounce(n); global_position = r["position"] + n * 0.1
		else: global_position = nxt

class Prop extends Obj:
	var ptype = "crate"
	var hp = 20.0
	var size = Vector3(0.9, 0.9, 0.9)
	var mat: Material
	func _ready() -> void:
		kind = "prop"
		var sb = StaticBody3D.new(); sb.collision_layer = 1 | 4; sb.set_meta("obj", self); add_child(sb)
		var cs = CollisionShape3D.new(); sb.add_child(cs)
		match ptype:
			"crate":
				size = Vector3(0.9, 0.9, 0.9) * randf_range(0.8, 1.25); mat = M.wood(Color(0.42, 0.3, 0.18)); hp = 22.0
				M.box(self, size, Vector3(0, size.y * 0.5, 0), mat)
				for sx in [-1, 1]: M.box(self, Vector3(0.06, size.y * 1.02, size.z * 1.02), Vector3(sx * size.x * 0.42, size.y * 0.5, 0), M.wood(Color(0.3, 0.2, 0.12)))
				M.box(self, Vector3(size.x * 1.02, 0.06, size.z * 1.02), Vector3(0, size.y * 0.85, 0), M.iron())
			"barrel", "redbarrel":
				size = Vector3(0.7, 1.1, 0.7); hp = 26.0
				mat = M.rust(Color(0.7, 0.12, 0.08)) if ptype == "redbarrel" else M.rust(Color(0.3, 0.36, 0.4))
				M.cyl(self, 0.35, 1.1, Vector3(0, 0.55, 0), mat, Vector3.ZERO, -1.0, 14)
				for hy in [0.2, 0.55, 0.9]: M.cyl(self, 0.365, 0.05, Vector3(0, hy, 0), M.iron(), Vector3.ZERO, -1.0, 14)
				if ptype == "redbarrel": M.box(self, Vector3(0.3, 0.3, 0.02), Vector3(0, 0.6, -0.36), M.glow(Color(1, 0.7, 0.1), 0.6))
			"pot":
				size = Vector3(0.6, 0.8, 0.6); mat = M.concrete(Color(0.55, 0.38, 0.28)); hp = 8.0
				M.cyl(self, 0.2, 0.5, Vector3(0, 0.25, 0), mat, Vector3.ZERO, 0.32, 12); M.cyl(self, 0.32, 0.25, Vector3(0, 0.62, 0), mat, Vector3.ZERO, 0.16, 12)
			"planks":
				size = Vector3(2.4, 1.3, 0.2); mat = M.wood(Color(0.38, 0.27, 0.16)); hp = 16.0
				for i in 5: M.box(self, Vector3(0.42, 1.3 + randf_range(-0.15, 0.15), 0.06), Vector3(-0.96 + i * 0.48, 0.65, 0), mat, Vector3(0, 0, randf_range(-4, 4)))
				M.box(self, Vector3(2.4, 0.1, 0.1), Vector3(0, 0.9, 0.06), M.wood(Color(0.3, 0.2, 0.12)))
		var sh = BoxShape3D.new(); sh.size = size; cs.shape = sh; cs.position = Vector3(0, size.y * 0.5, 0)
	func melee_hit(by, mv: Dictionary) -> void: _dmg(float(mv.get("dmg", 15)), by)
	func shot_hit(by, dmg: float) -> void: _dmg(dmg, by)
	func _dmg(a: float, by) -> void:
		if is_queued_for_deletion(): return
		hp -= a
		var c = global_position + Vector3(0, size.y * 0.5, 0)
		Snd.at("hit_block", c, -2.0, 0.55); Fx.dust(c, 5, Color(0.5, 0.42, 0.3, 0.6))
		if hp > 0:
			rotation.z = randf_range(-0.05, 0.05); return
		for i in 9: Fx.gib(c + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), Vector3(randf_range(-5, 5), randf_range(2, 7), randf_range(-5, 5)), Vector3(randf_range(0.1, 0.4), 0.05, randf_range(0.08, 0.25)), mat, 12.0)
		Fx.dust(c, 16, Color(0.45, 0.38, 0.28, 0.7)); Snd.at("plate", c, 2.0, 0.6); Fx.add_shake(0.15)
		if ptype == "pot":
			# 水。在這裡是錢。
			Fx._parts(c, 40, M.ghost(Color(0.6, 0.85, 1.0, 0.7)), 0.04, 0.8, 5.0, Vector3.UP, 70.0)
			Snd.at("step_water", c, 6.0, 0.8)
		if world and world.arena: world.arena.cheer(0.25)
		var w = world
		remove()
		if ptype == "redbarrel" and w: w.explode(c, 4.2, 38.0, 45.0, by)
