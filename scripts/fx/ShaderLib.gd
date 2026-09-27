class_name ShaderLib
extends RefCounted
## Исходники шейдеров окружения (рельеф, вода, небо, облака, растительность). Шейдеры компилируются
## один раз и переиспользуются всеми материалами.

static var _cache: Dictionary = {}


static func get_shader(key: String) -> Shader:
	if _cache.has(key):
		return _cache[key]
	var s := Shader.new()
	match key:
		"terrain":
			s.code = TERRAIN
		"water":
			s.code = WATER
		"sky":
			s.code = SKY
		"cloud":
			s.code = CLOUD
		"foliage":
			s.code = FOLIAGE
		"aircraft":
			s.code = AIRCRAFT
		"prop_disc":
			s.code = PROP_DISC
	_cache[key] = s
	return s


static func material(key: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = get_shader(key)
	return m


const TERRAIN := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_macro : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D noise_detail : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_detail : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D cloud_shadow : repeat_disable, filter_linear;
uniform vec4 cloud_params = vec4(13500.0, 1400.0, 0.0, 0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 c_grass;
uniform vec3 c_grass2;
uniform vec3 c_dry;
uniform vec3 c_forest;
uniform vec3 c_dirt;
uniform vec3 c_rock;
uniform vec3 c_rock2;
uniform vec3 c_sand;
uniform vec3 c_snow;
uniform vec3 c_fields[5];
uniform float snow_line = 700.0;
uniform float field_angle = 0.3;
uniform float detail_fade = 2600.0;

varying vec3 wpos;
varying vec4 vmask;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vmask = COLOR;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = clamp(1.0 - wn.y, 0.0, 1.0);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(detail_fade * 0.35, detail_fade, dist);
	vec2 p = wpos.xz;
	float macro = texture(noise_macro, p / 3100.0).r;
	float mid = texture(noise_macro, p / 610.0 + vec2(0.37, 0.71)).r;
	float fine = texture(noise_detail, p / 53.0).r;
	float micro = mix(0.5, texture(noise_detail, p / 8.3 + vec2(0.13, 0.59)).r, near);

	vec3 grass = mix(c_grass, c_grass2, smoothstep(0.3, 0.72, macro));
	grass = mix(grass, c_dry, clamp(vmask.b * smoothstep(0.2, 0.85, mid) * 1.25, 0.0, 1.0));
	vec3 col = grass * (0.84 + 0.3 * fine) * (0.93 + 0.14 * micro);

	float fm = smoothstep(0.32, 0.62, vmask.g);
	if (fm > 0.001) {
		float ca = cos(field_angle);
		float sa = sin(field_angle);
		vec2 q = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
		float row_h = 150.0;
		float row = floor(q.y / row_h);
		float w = 110.0 + 170.0 * hash12(vec2(row, 7.0));
		float shift = hash12(vec2(row, 3.0));
		vec2 cell = vec2(floor(q.x / w + shift), row);
		float h = hash12(cell);
		if (h > 0.16) {
			int idx = int(floor(hash12(cell + 17.3) * 4.999));
			vec3 fc = c_fields[idx];
			float along = hash12(cell + 5.1) > 0.5 ? q.x : q.y;
			float furrow = sin(along * 1.9) * 0.5 + 0.5;
			fc *= 0.9 + 0.14 * furrow * near;
			fc *= 0.88 + 0.24 * fine;
			vec2 local = vec2(fract(q.x / w + shift) * w, fract(q.y / row_h) * row_h);
			float edge_d = min(min(local.x, w - local.x), min(local.y, row_h - local.y));
			float fw = max(fwidth(edge_d), 0.001);
			float border = 1.0 - smoothstep(2.5 - fw, 2.5 + fw, edge_d);
			fc = mix(fc, c_forest * 1.15, border * 0.75);
			col = mix(col, fc, fm);
		}
	}
	col = mix(col, c_forest * (0.78 + 0.44 * fine), vmask.r * 0.93);
	float dirt_w = smoothstep(0.64, 0.82, fine * 0.6 + mid * 0.5) * (1.0 - vmask.r) * 0.55;
	dirt_w = max(dirt_w, vmask.a * (0.3 + 0.25 * fine));
	col = mix(col, c_dirt * (0.85 + 0.3 * micro), dirt_w);
	float sand_w = 1.0 - smoothstep(1.8, 3.4 + fine * 2.6, wpos.y);
	vec3 sand = c_sand * (0.9 + 0.2 * micro);
	sand = mix(sand * 0.68, sand, smoothstep(0.05, 0.9, wpos.y));
	col = mix(col, sand, sand_w);
	float rock_w = smoothstep(0.24, 0.4, slope + (fine - 0.5) * 0.16);
	float strata_x = wpos.y * 0.21 + mid * 6.0;
	float strata_aa = 1.0 - smoothstep(0.15, 0.5, fwidth(strata_x));
	float strata = mix(0.5, sin(strata_x) * 0.5 + 0.5, strata_aa * 0.8);
	vec3 rock = mix(c_rock, c_rock2, clamp(strata * 0.5 + fine * 0.6 - 0.1, 0.0, 1.0)) * (0.84 + 0.3 * micro);
	col = mix(col, rock, rock_w);
	float snow_w = smoothstep(snow_line - 50.0, snow_line + 70.0, wpos.y + (mid - 0.5) * 160.0) * (1.0 - smoothstep(0.42, 0.6, slope));
	col = mix(col, c_snow * (0.93 + 0.07 * micro), snow_w);
	if (wpos.y < -0.5) {
		col = mix(col, c_sand * 0.45, 0.5);
	}
	vec2 cs_uv = (p + sun_dir.xz / max(sun_dir.y, 0.12) * (cloud_params.y - wpos.y)) / (2.0 * cloud_params.x) + 0.5;
	float cshadow = texture(cloud_shadow, cs_uv).r * cloud_params.w;
	ALBEDO = col * (1.0 - cshadow);
	float rough = mix(mix(0.93, 0.8, rock_w), 0.5, snow_w);
	ROUGHNESS = mix(rough, 0.32, sand_w * (1.0 - smoothstep(0.1, 1.0, wpos.y)));
	SPECULAR = 0.3;
	vec2 nd = texture(normal_detail, p / 21.0).xy * 2.0 - 1.0;
	nd += (texture(normal_detail, p / 4.7 + vec2(0.5)).xy * 2.0 - 1.0) * 0.55 * near;
	float strength = (0.28 + rock_w * 0.9 + snow_w * 0.1) * (0.35 + 0.65 * near);
	vec3 pn = normalize(wn + vec3(nd.x, 0.0, nd.y) * strength);
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
}
"""

const WATER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D height_map : repeat_disable, filter_linear;
uniform float world_half = 13500.0;
uniform sampler2D wave_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D cloud_shadow : repeat_disable, filter_linear;
uniform vec4 cloud_params = vec4(13500.0, 1400.0, 0.0, 0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 deep_color : source_color = vec3(0.02, 0.1, 0.16);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.3, 0.3);
uniform vec3 foam_color : source_color = vec3(0.88, 0.93, 0.95);
uniform float wave_strength = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	vec2 huv = p / (2.0 * world_half) + 0.5;
	float th = -300.0;
	if (huv.x > 0.0 && huv.y > 0.0 && huv.x < 1.0 && huv.y < 1.0) {
		th = texture(height_map, huv).r;
	}
	float depth = max(-th, 0.0);
	float t = TIME;
	float far = smoothstep(150.0, 4500.0, dist);
	vec2 n1 = texture(wave_normal, p / 61.0 + t * vec2(0.011, 0.006)).xy * 2.0 - 1.0;
	vec2 n2 = texture(wave_normal, p / 23.0 + t * vec2(-0.009, 0.014)).xy * 2.0 - 1.0;
	vec2 n3 = texture(wave_normal, p / 310.0 + t * vec2(0.003, -0.004)).xy * 2.0 - 1.0;
	vec2 n4 = texture(wave_normal, p / 6.5 + t * vec2(0.021, 0.028)).xy * 2.0 - 1.0;
	vec2 slope = n1 * 0.55 + n2 * 0.4 + n3 * 0.45 + n4 * 0.3 * (1.0 - far);
	slope *= mix(0.34, 0.12, far) * wave_strength * mix(0.3, 1.0, smoothstep(0.0, 6.0, depth));
	vec3 wn = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	float shallow_k = exp(-depth / 7.5);
	vec3 col = mix(deep_color, shallow_color, shallow_k);
	float fn = texture(foam_noise, p / 9.0 + t * 0.015).r;
	float fn2 = texture(foam_noise, p / 3.1 - t * 0.02).r;
	float shore = 1.0 - smoothstep(0.0, 1.4, depth);
	float bands = smoothstep(0.55, 1.0, sin(depth * 3.2 - t * 1.6 + fn * 4.0) * 0.5 + 0.5) * (1.0 - smoothstep(0.0, 4.5, depth));
	float foam = clamp(shore * smoothstep(0.3, 0.65, fn) + bands * smoothstep(0.4, 0.8, fn2) * 0.8, 0.0, 1.0);
	float caps = smoothstep(0.8, 0.93, texture(foam_noise, p / 41.0 + t * 0.008).r * 0.7 + fn2 * 0.3) * (1.0 - far) * 0.3 * wave_strength;
	foam = max(foam, caps) * (1.0 - far * 0.7);
	vec2 cs_uv = (p + sun_dir.xz / max(sun_dir.y, 0.12) * cloud_params.y) / (2.0 * cloud_params.x) + 0.5;
	float cshadow = texture(cloud_shadow, cs_uv).r * cloud_params.w;
	ALBEDO = mix(col, foam_color, foam) * (1.0 - cshadow * 0.55);
	ROUGHNESS = mix(0.03 + far * 0.07, 0.75, foam);
	SPECULAR = 0.5 * (1.0 - cshadow * 0.5);
}
"""

const SKY := """
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.15, 0.33, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.63, 0.74, 0.87);
uniform vec3 ground_color : source_color = vec3(0.35, 0.4, 0.44);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.82);
uniform float sun_size = 0.8;
uniform float sky_energy = 1.0;
uniform sampler2D cloud_tex : repeat_enable, filter_linear_mipmap;
uniform float cloud_amount = 0.4;
uniform vec3 cloud_tint : source_color = vec3(1.0);

void sky() {
	vec3 d = EYEDIR;
	vec3 sd = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	float mu = dot(d, sd);
	float h = max(d.y, 0.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.48));
	float sun_low = 1.0 - smoothstep(0.0, 0.5, sd.y);
	float glow = pow(max(mu, 0.0), 5.0) * (0.22 + 0.5 * sun_low) + pow(max(mu, 0.0), 42.0) * 0.7;
	col += sun_color * glow * (1.0 - 0.6 * h);
	col += horizon_color * pow(1.0 - h, 10.0) * 0.18;
	if (d.y < 0.0) {
		col = mix(horizon_color * 0.96 + sun_color * glow * 0.4, ground_color, smoothstep(0.0, 0.18, -d.y));
	} else {
		vec2 uv = d.xz / (d.y + 0.07) * 0.32;
		float n = texture(cloud_tex, uv * 0.55 + vec2(0.13, 0.41)).r * 0.62 + texture(cloud_tex, uv * 1.9 + vec2(0.3)).r * 0.38;
		float cov = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.28, n) * smoothstep(0.0, 0.14, d.y);
		vec3 ccol = mix(cloud_tint * 0.72, cloud_tint * 1.08, clamp(n * 1.3 - 0.2, 0.0, 1.0)) * (0.75 + 0.3 * h);
		ccol += sun_color * (pow(max(mu, 0.0), 10.0) * 0.8 + sun_low * 0.25);
		col = mix(col, ccol, cov * 0.8);
	}
	if (!AT_CUBEMAP_PASS) {
		float disc = smoothstep(cos(radians(sun_size)), cos(radians(sun_size * 0.6)), mu);
		col += sun_color * disc * 26.0;
	}
	COLOR = col * sky_energy;
}
"""

const CLOUD := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D puff_noise : repeat_enable, filter_linear_mipmap;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.9);
uniform vec3 lit_color : source_color = vec3(1.0);
uniform vec3 shade_color : source_color = vec3(0.55, 0.6, 0.7);
uniform float density = 0.92;
uniform float near_fade = 140.0;

varying vec4 cdata;
varying vec3 wcenter;

void vertex() {
	cdata = INSTANCE_CUSTOM;
	wcenter = MODEL_MATRIX[3].xyz;
	float wsize = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(wsize, 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	vec2 nuv = UV * 0.85 + cdata.x * vec2(3.17, 5.31);
	float n = texture(puff_noise, nuv).r;
	float n2 = texture(puff_noise, nuv * 2.4 + vec2(0.5, 0.2) + TIME * 0.002).r;
	float shape = 1.0 - smoothstep(0.3, 1.0, r + (n - 0.5) * 0.6 + (n2 - 0.5) * 0.25);
	if (shape <= 0.002) {
		discard;
	}
	vec3 nv = normalize(vec3(uv.x, -uv.y, sqrt(max(1.0 - min(r * r, 1.0), 0.0)) + 0.2));
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz);
	float lambert = clamp(dot(nw, sun_dir) * 0.55 + 0.45, 0.0, 1.0);
	float hgt = cdata.y;
	float light = clamp(lambert * 0.65 + hgt * 0.55 - 0.08 + (n2 - 0.5) * 0.2, 0.0, 1.0);
	vec3 col = mix(shade_color, lit_color, light) * cdata.z;
	vec3 view_dir = normalize(wcenter - CAMERA_POSITION_WORLD);
	float fwd = pow(max(dot(view_dir, sun_dir), 0.0), 7.0);
	col += sun_color * fwd * (1.0 - shape) * 1.2;
	col += sun_color * 0.08 * lambert;
	float d = length(VERTEX);
	float alpha = shape * density * smoothstep(near_fade * 0.25, near_fade, d);
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
"""

const FOLIAGE := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform float wind = 1.0;

varying vec3 vcol;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.013 + origin.z * 0.017;
	float bend = max(VERTEX.y, 0.0);
	float s = sin(TIME * 1.1 + phase) * 0.6 + sin(TIME * 2.3 + phase * 1.7) * 0.25;
	VERTEX.x += s * bend * 0.011 * wind * COLOR.a;
	VERTEX.z += s * bend * 0.007 * wind * COLOR.a;
	vcol = pow(COLOR.rgb, vec3(2.2)) * INSTANCE_CUSTOM.rgb;
}

void fragment() {
	ALBEDO = vcol;
	ROUGHNESS = 0.88;
	SPECULAR = 0.2;
	BACKLIGHT = vcol * 0.35;
}
"""

## Окраска самолёта: камуфляж в пространстве модели, нижняя поверхность, нос/кок и опознавательные
## элементы команды, панельные линии и заклёпки по развёртке (UV в метрах), износ кромок и копоть.
## UV2.x — доля хорды (крылья), UV2.y — тип детали: 0 фюзеляж, 1 крыло, 2 стабилизатор, 3 киль,
## 4 капот, 5 кок винта, 6 мотогондола.
const AIRCRAFT := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 camo_a : source_color = vec3(0.45, 0.47, 0.5);
uniform vec3 camo_b : source_color = vec3(0.3, 0.33, 0.36);
uniform vec3 camo_c : source_color = vec3(0.0);
uniform vec3 under_color : source_color = vec3(0.62, 0.68, 0.74);
uniform vec3 id_color : source_color = vec3(0.2, 0.6, 1.0);
uniform vec3 nose_color : source_color = vec3(0.9, 0.75, 0.1);
uniform int pattern = 1;
uniform float pattern_scale = 1.0;
uniform float use_under = 1.0;
uniform vec2 nose_range = vec2(-1000.0, -1000.0);
uniform vec2 band_range = vec2(1000.0, 1000.0);
uniform float tip_start = 1000.0;
uniform float metallic_base = 0.0;
uniform float roughness_base = 0.55;
uniform float wear = 0.4;
uniform vec4 exhaust = vec4(0.0);
uniform float panel_scale = 1.0;

varying vec3 mpos;
varying vec3 mnrm;
varying vec2 muv;
varying vec2 mpart;

void vertex() {
	mpos = VERTEX;
	mnrm = NORMAL;
	muv = UV;
	mpart = UV2;
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

float line_aa(float x, float period, float width) {
	float d = abs(fract(x / period + 0.5) - 0.5) * period;
	float fw = max(fwidth(x), 0.0005);
	return 1.0 - smoothstep(width - fw, width + fw, d);
}

float at_aa(float x, float pos, float width) {
	float fw = max(fwidth(x), 0.0005);
	return 1.0 - smoothstep(width - fw, width + fw, abs(x - pos));
}

vec2 splinter(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float second = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash31(vec3(i + g, 1.0)), hash31(vec3(i + g, 7.0)));
			vec2 r = g + o - f;
			float d = max(abs(r.x * 0.8 + r.y * 0.6), abs(r.x * 0.6 - r.y * 0.8));
			if (d < best) {
				second = best;
				best = d;
				id = hash31(vec3(i + g, 3.0));
			} else if (d < second) {
				second = d;
			}
		}
	}
	return vec2(id, second - best);
}

void fragment() {
	int part = int(mpart.y + 0.5);
	vec3 base = camo_a;
	vec3 sp = mpos * pattern_scale;
	if (pattern == 1) {
		float n = fbm(sp * 0.2 + vec3(3.1, 0.0, 1.7));
		base = mix(camo_a, camo_b, smoothstep(0.47, 0.52, n));
		if (length(camo_c) > 0.01) {
			float n2 = fbm(sp * 0.26 + vec3(11.0, 5.0, 2.0));
			base = mix(base, camo_c, smoothstep(0.56, 0.6, n2));
		}
	} else if (pattern == 2) {
		vec2 s = splinter(sp.xz * 0.32);
		base = s.x < 0.5 ? camo_a : camo_b;
		if (length(camo_c) > 0.01 && s.x > 0.8) {
			base = camo_c;
		}
	} else if (pattern == 3) {
		float n = fbm(sp * 0.9 + vec3(5.0));
		float side = smoothstep(0.35, 0.8, abs(mnrm.x));
		base = mix(camo_a, camo_b, smoothstep(0.5, 0.55, fbm(sp * 0.22)) * (1.0 - side * 0.7));
		base = mix(base, camo_b * 0.92, smoothstep(0.56, 0.62, n) * side);
	} else if (pattern == 4) {
		vec2 cell = floor(muv / vec2(0.62 * panel_scale, 0.55 * panel_scale));
		float t = hash31(vec3(cell, mpart.y));
		base = camo_a * (0.9 + 0.2 * t);
	} else if (pattern == 5) {
		float n = fbm(sp * 0.15 + vec3(2.0, 0.0, 9.0));
		float band = sin(sp.z * 0.55 + sp.x * 0.35 + n * 5.0);
		base = mix(camo_a, camo_b, smoothstep(-0.08, 0.08, band));
	}
	float under_k = smoothstep(-0.05, -0.3, mnrm.y + (fbm(mpos * 0.9) - 0.5) * 0.1);
	if (part == 3) {
		under_k = 0.0;
	}
	base = mix(base, under_color, under_k * use_under);
	if (mpos.z > nose_range.x && mpos.z < nose_range.y && (part == 0 || part == 4)) {
		base = nose_color;
	}
	if (part == 5) {
		base = id_color;
	}
	if ((part == 0 || part == 6) && mpos.z > band_range.x && mpos.z < band_range.y) {
		base = id_color * 0.9;
	}
	if ((part == 1 || part == 2) && abs(mpos.x) > tip_start) {
		base = mix(base, id_color, 0.9);
	}
	float lines = 0.0;
	float rivets = 0.0;
	if (part == 0 || part == 4 || part == 6) {
		lines = max(line_aa(muv.x, 0.64 * panel_scale, 0.008), line_aa(muv.y, 0.58 * panel_scale, 0.007) * 0.7);
		float rv = line_aa(muv.x + 0.035, 0.64 * panel_scale, 0.01) * line_aa(muv.y, 0.06, 0.013);
		rivets = rv;
	} else if (part >= 1 && part <= 3) {
		lines = line_aa(muv.x, 0.52 * panel_scale, 0.007) * 0.55;
		lines = max(lines, at_aa(mpart.x, 0.14, 0.004) * 0.8);
		lines = max(lines, at_aa(mpart.x, 0.68, 0.005));
		rivets = line_aa(muv.x + 0.03, 0.52 * panel_scale, 0.009) * line_aa(muv.y, 0.055, 0.012);
	}
	float dirt = fbm(mpos * 2.4 + vec3(4.0));
	vec3 col = base * (1.0 - wear * 0.2 * smoothstep(0.45, 0.8, dirt));
	col *= 1.0 - wear * 0.1 * (fbm(mpos * 7.0) - 0.4);
	if (part >= 1 && part <= 3) {
		float chip = smoothstep(0.035, 0.0, mpart.x) * smoothstep(0.55, 0.7, fbm(mpos * 9.0)) * wear;
		col = mix(col, vec3(0.62, 0.63, 0.64), chip);
	}
	if (exhaust.w > 0.5 && part == 0) {
		float along = (mpos.z - exhaust.x) / max(exhaust.y - exhaust.x, 0.01);
		float band = 1.0 - smoothstep(0.08, 0.35 + along * 0.25, abs(mpos.y - exhaust.z));
		float soot = step(0.0, along) * (1.0 - smoothstep(0.6, 1.0, along)) * band * step(0.3, abs(mnrm.x));
		col = mix(col, vec3(0.06, 0.055, 0.05), soot * (0.55 + 0.35 * fbm(mpos * 5.0)));
	}
	col *= 1.0 - lines * 0.32 - rivets * 0.12;
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_base + lines * 0.12 + (dirt - 0.5) * 0.12, 0.08, 1.0);
	METALLIC = metallic_base;
	SPECULAR = 0.5;
}
"""

## Диск вращающегося винта: полупрозрачный круг со «стробоскопическими» тенями лопастей и жёлтыми законцовками.
const PROP_DISC := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 blade_color : source_color = vec3(0.05, 0.05, 0.05);
uniform vec3 tip_color : source_color = vec3(0.95, 0.78, 0.12);
uniform float blades = 3.0;
uniform float spin = 1.3;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	if (r > 1.0) {
		discard;
	}
	float a = atan(uv.y, uv.x);
	float ghost = pow(abs(cos((a + TIME * spin) * blades * 0.5)), 18.0);
	float body = (0.07 + 0.16 * ghost) * smoothstep(1.0, 0.93, r) * smoothstep(0.1, 0.22, r);
	float tip = smoothstep(0.86, 0.9, r) * (1.0 - smoothstep(0.96, 1.0, r));
	ALBEDO = mix(blade_color, tip_color, tip);
	ALPHA = clamp(body + tip * 0.22, 0.0, 1.0);
}
"""
