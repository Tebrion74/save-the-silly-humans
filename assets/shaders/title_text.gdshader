shader_type canvas_item;
// Build 011 title lettering: vertical 3-stop gradient on the (white) glyph
// fill, a moving diagonal shine, and dark outline/shadow left as-is.
uniform vec4 top_color : source_color = vec4(1.0, 0.97, 0.6, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.72, 0.18, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.92, 0.28, 0.12, 1.0);
uniform float text_top = 0.0;
uniform float text_bottom = 100.0;
uniform float shine_x = -1000.0;
uniform float shine_width = 46.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	float lum = max(c.r, max(c.g, c.b));
	float t = clamp((local_pos.y - text_top) / max(text_bottom - text_top, 1.0), 0.0, 1.0);
	vec3 g = t < 0.5 ? mix(top_color.rgb, mid_color.rgb, t * 2.0) : mix(mid_color.rgb, bottom_color.rgb, (t - 0.5) * 2.0);
	// pixel-ish banding for that 32-bit look
	float band = step(0.5, fract(local_pos.y / 4.0)) * 0.05;
	vec3 fill = g * (1.0 - band);
	float d = abs((local_pos.x + local_pos.y * 0.6) - shine_x);
	float shine = smoothstep(shine_width, 0.0, d) * 0.75;
	fill = mix(fill, vec3(1.0), shine);
	c.rgb = mix(c.rgb, fill * lum, step(0.55, lum));
	COLOR = c;
}
