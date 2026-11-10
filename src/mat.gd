extends RefCounted
# 材質工廠（快取）。全部程序化，三平面貼圖，不需要 UV。
static var cache = {}
static var ntex = {}

static func noise(kind: String) -> Texture2D:
	if ntex.has(kind): return ntex[kind]
	var n = FastNoiseLite.new(); var t = NoiseTexture2D.new(); t.width = 256; t.height = 256; t.seamless = true
	match kind:
		"grime":
			n.frequency = 0.012; n.fractal_octaves = 5
			var g = Gradient.new(); g.set_color(0, Color(0.45, 0.42, 0.4)); g.set_color(1, Color(1, 1, 1)); t.color_ramp = g
		"rust":
			n.frequency = 0.03; n.fractal_octaves = 4; n.noise_type = FastNoiseLite.TYPE_CELLULAR
			var g2 = Gradient.new(); g2.set_color(0, Color(0.35, 0.2, 0.12)); g2.set_color(1, Color(1, 0.95, 0.9)); t.color_ramp = g2
		"bump":
			n.frequency = 0.04; n.fractal_octaves = 5; t.as_normal_map = true; t.bump_strength = 6.0
		"fine":
			n.frequency = 0.15; n.fractal_octaves = 3; t.as_normal_map = true; t.bump_strength = 3.0
	t.noise = n; ntex[kind] = t; return t

static func mk(key: String, col: Color, rough: float, metal: float, tex: String = "", bump: String = "", scale: float = 0.5) -> StandardMaterial3D:
	var k = key + str(col)
	if cache.has(k): return cache[k]
	var m = StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough; m.metallic = metal
	if tex != "":
		m.albedo_texture = noise(tex); m.uv1_triplanar = true; m.uv1_scale = Vector3.ONE * scale
	if bump != "":
		m.normal_enabled = true; m.normal_texture = noise(bump); m.uv1_triplanar = true; m.uv1_scale = Vector3.ONE * scale
	cache[k] = m; return m

static func concrete(c: Color = Color(0.5, 0.48, 0.45)) -> Material: return mk("conc", c, 0.95, 0.0, "grime", "bump", 0.25)
static func rust(c: Color = Color(0.5, 0.3, 0.18)) -> Material: return mk("rust", c, 0.75, 0.55, "rust", "bump", 0.8)
static func steel(c: Color = Color(0.62, 0.64, 0.66)) -> Material: return mk("steel", c, 0.32, 0.95, "grime", "fine", 1.5)
static func iron(c: Color = Color(0.2, 0.2, 0.22)) -> Material: return mk("iron", c, 0.5, 0.85, "grime", "fine", 1.2)
static func skin(c: Color) -> Material: return mk("skin", c, 0.55, 0.0, "grime", "fine", 2.0)
static func cloth(c: Color) -> Material: return mk("cloth", c, 1.0, 0.0, "grime", "bump", 2.0)
static func wood(c: Color = Color(0.4, 0.27, 0.16)) -> Material: return mk("wood", c, 0.8, 0.0, "rust", "fine", 1.0)
static func mud() -> Material: return mk("mud", Color(0.36, 0.3, 0.24), 1.0, 0.0, "rust", "bump", 0.15)
static func blood() -> Material:
	if cache.has("blood"): return cache["blood"]
	var m = StandardMaterial3D.new(); m.albedo_color = Color(0.42, 0.01, 0.01); m.roughness = 0.12; m.metallic = 0.3
	cache["blood"] = m; return m
static func glow(c: Color, e: float = 3.0) -> Material:
	var k = "glow" + str(c) + str(e)
	if cache.has(k): return cache[k]
	var m = StandardMaterial3D.new(); m.albedo_color = c; m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = e
	cache[k] = m; return m
static func ghost(c: Color) -> Material:
	var m = StandardMaterial3D.new(); m.albedo_color = c; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; return m
static func water() -> Material:
	if cache.has("water"): return cache["water"]
	var m = StandardMaterial3D.new(); m.albedo_color = Color(0.08, 0.16, 0.18, 0.82); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04; m.metallic = 0.6; m.normal_enabled = true; m.normal_texture = noise("bump"); m.uv1_triplanar = true; m.uv1_scale = Vector3.ONE * 0.2
	cache["water"] = m; return m

# ---- 幾何小工具 ----
static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); var b = BoxMesh.new(); b.size = size; mi.mesh = b; mi.material_override = mat
	parent.add_child(mi); mi.position = pos; mi.rotation_degrees = rot; return mi
static func cyl(parent: Node, r: float, h: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, r2: float = -1.0, seg: int = 12) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); var c = CylinderMesh.new(); c.top_radius = r if r2 < 0 else r2; c.bottom_radius = r; c.height = h; c.radial_segments = seg; c.rings = 1
	mi.mesh = c; mi.material_override = mat; parent.add_child(mi); mi.position = pos; mi.rotation_degrees = rot; return mi
static func ball(parent: Node, r: float, pos: Vector3, mat: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); var s = SphereMesh.new(); s.radius = r; s.height = r * 2; s.radial_segments = 14; s.rings = 8
	mi.mesh = s; mi.material_override = mat; parent.add_child(mi); mi.position = pos; mi.scale = sc; return mi
static func cap(parent: Node, r: float, h: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); var c = CapsuleMesh.new(); c.radius = r; c.height = max(h, r * 2.01); c.radial_segments = 10; c.rings = 4
	mi.mesh = c; mi.material_override = mat; parent.add_child(mi); mi.position = pos; mi.rotation_degrees = rot; return mi
static func solid(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, layer: int = 1) -> StaticBody3D:
	var sb = StaticBody3D.new(); parent.add_child(sb); sb.position = pos; sb.rotation_degrees = rot; sb.collision_layer = layer
	var cs = CollisionShape3D.new(); var sh = BoxShape3D.new(); sh.size = size; cs.shape = sh; sb.add_child(cs)
	box(sb, size, Vector3.ZERO, mat); return sb
