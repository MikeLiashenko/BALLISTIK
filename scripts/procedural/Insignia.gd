class_name Insignia
extends RefCounted
## Опознавательные знаки (SVG-разметка в коде → растр с мипмапами) для проекционных декалей:
## красная звезда, балочный крест, звезда с полосами, британские и французские круги, хиномару,
## килевой флэш и «акулья пасть».

static var _cache: Dictionary = {}


static func texture(nation: String, kind: String) -> Texture2D:
	var key := "%s|%s" % [nation, kind]
	if _cache.has(key):
		return _cache[key]
	var body := _svg(nation, kind)
	if body == "":
		_cache[key] = null
		return null
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s</svg>" % body
	var img := Image.new()
	if img.load_svg_from_string(svg, 4.0) != OK or img.is_empty():
		_cache[key] = null
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _star(r_out: float, r_in: float, cx: float = 32.0, cy: float = 32.0) -> String:
	var pts := PackedStringArray()
	for i in 10:
		var r := r_out if i % 2 == 0 else r_in
		var a := deg_to_rad(-90.0 + float(i) * 36.0)
		pts.append("%.2f,%.2f" % [cx + cos(a) * r, cy + sin(a) * r])
	return " ".join(pts)


static func _svg(nation: String, kind: String) -> String:
	match nation:
		"su":
			return "<polygon points='%s' fill='#b3121b'/><polygon points='%s' fill='#ffffff'/><polygon points='%s' fill='#c8141f'/>" % [_star(31.0, 12.4), _star(28.5, 11.4), _star(25.0, 10.0)]
		"de":
			if kind == "fin":
				return ""
			return "<path d='M22 6h20v16h16v20H42v16H22V42H6V22h16z' fill='#ffffff'/><path d='M26 10h12v16h16v12H38v16H26V38H10V26h16z' fill='#101010'/>"
		"us":
			if kind == "fin":
				return ""
			return "<rect x='1' y='24' width='62' height='16' fill='#1d2f5e'/><rect x='3' y='26' width='58' height='12' fill='#ffffff'/><circle cx='32' cy='32' r='17' fill='#1d2f5e'/><polygon points='%s' fill='#ffffff'/>" % _star(16.0, 6.4)
		"uk":
			if kind == "fin":
				return "<rect x='14' y='4' width='12' height='56' fill='#c8102e'/><rect x='26' y='4' width='12' height='56' fill='#ffffff'/><rect x='38' y='4' width='12' height='56' fill='#1f3a7a'/>"
			if kind == "fuselage":
				return "<circle cx='32' cy='32' r='31' fill='#f2c418'/><circle cx='32' cy='32' r='27' fill='#1f3a7a'/><circle cx='32' cy='32' r='17' fill='#ffffff'/><circle cx='32' cy='32' r='11' fill='#c8102e'/>"
			return "<circle cx='32' cy='32' r='30' fill='#1f3a7a'/><circle cx='32' cy='32' r='12' fill='#c8102e'/>"
		"jp":
			if kind == "fin":
				return ""
			return "<circle cx='32' cy='32' r='31' fill='#ffffff'/><circle cx='32' cy='32' r='27' fill='#c20f1f'/>"
		"fr":
			return "<circle cx='32' cy='32' r='30' fill='#1f3f94'/><circle cx='32' cy='32' r='20' fill='#ffffff'/><circle cx='32' cy='32' r='10' fill='#d0172b'/>"
		"shark":
			return "<path d='M2 30 Q20 14 62 22 Q40 34 62 44 Q22 50 2 34 Z' fill='#b3121b' stroke='#101010' stroke-width='2'/><path d='M8 30 L12 25 L16 29 L20 22 L24 27 L28 20 L32 25 L36 19 L40 24 L44 19 L48 23 L54 21 L58 24 Z' fill='#ffffff'/><path d='M8 34 L12 39 L16 35 L20 42 L24 37 L28 43 L32 38 L36 44 L40 39 L44 44 L48 40 L54 43 L58 41 Z' fill='#ffffff'/><circle cx='56' cy='16' r='4' fill='#ffffff' stroke='#101010' stroke-width='1.5'/><circle cx='56.5' cy='16' r='2' fill='#101010'/>"
	return ""
