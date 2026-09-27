class_name IconFactory
extends RefCounted
## Иконки интерфейса, нарисованные векторно (SVG-разметка прямо в коде) и растеризованные
## во время выполнения через Image.load_svg_from_string — никаких файлов изображений.

static var _cache: Dictionary = {}

const SVG := {
	"tab_air": "<path d='M32 4 L36 20 L36 26 L58 40 L58 45 L36 38 L35 50 L42 56 L42 60 L32 57 L22 60 L22 56 L29 50 L28 38 L6 45 L6 40 L28 26 L28 20 Z' fill='C'/>",
	"tab_ground": "<path d='M32 4 L56 12 L56 30 C56 46 45 56 32 61 C19 56 8 46 8 30 L8 12 Z' fill='none' stroke='C' stroke-width='4.5' stroke-linejoin='round'/><path d='M21 42 L32 20 L43 42' fill='none' stroke='C' stroke-width='4.5' stroke-linecap='round' stroke-linejoin='round'/><circle cx='32' cy='46' r='3.5' fill='C'/>",
	"tab_naval": "<circle cx='32' cy='11' r='5.5' fill='none' stroke='C' stroke-width='4.5'/><line x1='32' y1='17' x2='32' y2='57' stroke='C' stroke-width='4.5'/><line x1='19' y1='26' x2='45' y2='26' stroke='C' stroke-width='4.5' stroke-linecap='round'/><path d='M11 38 C13 52 22 57 32 57 C42 57 51 52 53 38' fill='none' stroke='C' stroke-width='4.5' stroke-linecap='round'/><path d='M5 43 L11 32 L18 42 Z M59 43 L53 32 L46 42 Z' fill='C'/>",
	"fighter": "<path d='M32 3 L36 19 L36 25 L59 40 L59 45 L36 38 L35 50 L43 56 L43 60 L32 57 L21 60 L21 56 L29 50 L28 38 L5 45 L5 40 L28 25 L28 19 Z' fill='C'/>",
	"bomber": "<path d='M32 2 L35.5 13 L35.5 24 L61 45 L61 49 L35.5 40 L34.5 52 L45 58 L45 61 L32 58.5 L19 61 L19 58 L29.5 52 L28.5 40 L3 49 L3 45 L28.5 24 L28.5 13 Z' fill='C'/>",
	"spaag": "<rect x='5' y='42' width='54' height='12' rx='6' fill='C'/><rect x='11' y='32' width='42' height='11' rx='2' fill='C'/><rect x='21' y='22' width='22' height='11' rx='2' fill='C'/><line x1='24' y1='25' x2='46' y2='5' stroke='C' stroke-width='3.5' stroke-linecap='round'/><line x1='36' y1='27' x2='58' y2='7' stroke='C' stroke-width='3.5' stroke-linecap='round'/><circle cx='15' cy='48' r='3' fill='#05090f'/><circle cx='27' cy='48' r='3' fill='#05090f'/><circle cx='39' cy='48' r='3' fill='#05090f'/><circle cx='51' cy='48' r='3' fill='#05090f'/>",
	"sam": "<rect x='3' y='43' width='58' height='11' rx='5.5' fill='C'/><rect x='9' y='34' width='46' height='10' rx='2' fill='C'/><path d='M20 35 L49 10 L54 15 L26 37 Z' fill='C'/><path d='M49 10 L59 3 L54 15 Z' fill='C'/><path d='M28 29 L53 7' stroke='#05090f' stroke-width='1.5'/><circle cx='14' cy='49' r='3' fill='#05090f'/><circle cx='27' cy='49' r='3' fill='#05090f'/><circle cx='40' cy='49' r='3' fill='#05090f'/><circle cx='52' cy='49' r='3' fill='#05090f'/>",
	"boat": "<path d='M3 37 L61 37 L52 50 L11 50 Z' fill='C'/><rect x='23' y='26' width='17' height='11' rx='2' fill='C'/><line x1='33' y1='26' x2='33' y2='13' stroke='C' stroke-width='2.5'/><rect x='44' y='31' width='12' height='5' rx='1' fill='C'/><path d='M6 57 Q19 52 32 57 T58 57' fill='none' stroke='C' stroke-width='2.5' opacity='0.6'/>",
	"warship": "<path d='M2 38 L62 38 L55 49 L9 49 Z' fill='C'/><rect x='20' y='26' width='20' height='12' fill='C'/><rect x='26' y='18' width='8' height='8' fill='C'/><line x1='30' y1='18' x2='30' y2='6' stroke='C' stroke-width='2.5'/><rect x='44' y='31' width='10' height='7' fill='C'/><line x1='8' y1='34' x2='16' y2='31' stroke='C' stroke-width='2.5'/>",
	"target": "<circle cx='32' cy='32' r='22' fill='none' stroke='C' stroke-width='4'/><circle cx='32' cy='32' r='4' fill='C'/><line x1='32' y1='2' x2='32' y2='16' stroke='C' stroke-width='4'/><line x1='32' y1='48' x2='32' y2='62' stroke='C' stroke-width='4'/><line x1='2' y1='32' x2='16' y2='32' stroke='C' stroke-width='4'/><line x1='48' y1='32' x2='62' y2='32' stroke='C' stroke-width='4'/>",
	"radar": "<circle cx='32' cy='32' r='27' fill='none' stroke='C' stroke-width='3'/><circle cx='32' cy='32' r='16' fill='none' stroke='C' stroke-width='3' opacity='0.6'/><path d='M32 32 L32 5 A27 27 0 0 1 55 19 Z' fill='C' opacity='0.7'/><circle cx='44' cy='40' r='3.5' fill='C'/>",
	"pause": "<rect x='16' y='12' width='11' height='40' rx='2' fill='C'/><rect x='37' y='12' width='11' height='40' rx='2' fill='C'/>",
}


static func get_icon(icon_name: String, size: int = 64, color: Color = Color(0.1, 0.9, 1.0)) -> Texture2D:
	var key := "%s|%d|%s" % [icon_name, size, color.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var body: String = SVG.get(icon_name, SVG["target"])
	var hex := "#" + color.to_html(false)
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s</svg>" % body.replace("'C'", "'%s'" % hex)
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(size) / 64.0)
	if err != OK or img.is_empty():
		img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(color, 0.6))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
