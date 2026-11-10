extends Node
# 場景切換器。所有場景都由程式建構。
var cur: Node = null
var fade: ColorRect

func _ready() -> void:
	G.main = self
	var cl = CanvasLayer.new(); cl.layer = 100; add_child(cl)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 1); fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(fade)
	var args = OS.get_cmdline_user_args()
	if args.has("--test"):
		fade.color.a = 0.0
		var t = load("res://src/test.gd").new(); add_child(t); return
	go("hub")

func go(kind: String, arg = null) -> void:
	var tw = create_tween(); tw.tween_property(fade, "color:a", 1.0, 0.25 if cur else 0.0)
	await tw.finished
	_swap(kind, arg)
	await get_tree().create_timer(0.15).timeout
	create_tween().tween_property(fade, "color:a", 0.0, 0.5)

func _swap(kind: String, arg) -> void:
	Engine.time_scale = 1.0
	if cur: cur.queue_free(); cur = null
	var n: Node
	match kind:
		"hub":
			n = load("res://src/hub.gd").new(); n.arg = arg
		"fight": n = load("res://src/fight.gd").new(); n.cfg = arg
		"ending": n = load("res://src/ending.gd").new(); n.which = arg
	n.name = kind; add_child(n); cur = n
