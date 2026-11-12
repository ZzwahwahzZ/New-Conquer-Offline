shader_type canvas_item;
render_mode unshaded;
uniform float hp_fill : hint_range(0.0, 1.0) = 1.0;
uniform float mp_fill : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float circle_mask = 1.0 - smoothstep(0.965, 0.995, radius);
	if (circle_mask < 0.002) discard;
	float left_half = 1.0 - step(0.5, UV.x);
	float right_half = step(0.5, UV.x);
	float hp_active = step(1.0 - clamp(hp_fill, 0.0, 1.0), UV.y);
	float mp_active = step(1.0 - clamp(mp_fill, 0.0, 1.0), UV.y);
	vec3 hp_color = mix(vec3(0.12,0.018,0.035), vec3(0.94,0.12,0.18), hp_active);
	vec3 mp_color = mix(vec3(0.012,0.045,0.16), vec3(0.10,0.48,1.0), mp_active);
	vec3 color = (hp_color * left_half + mp_color * right_half) * (0.72 + 0.28 * (1.0 - UV.y));
	float outer_gold = smoothstep(0.82,0.845,radius) * (1.0 - smoothstep(0.945,0.975,radius));
	float inner_gold = smoothstep(0.775,0.795,radius) * (1.0 - smoothstep(0.815,0.835,radius));
	float seam = (1.0 - smoothstep(0.008,0.022,abs(UV.x-0.5))) * (1.0 - smoothstep(0.76,0.84,radius));
	vec3 gold = vec3(0.98,0.73,0.30);
	vec3 bright_gold = vec3(1.0,0.91,0.63);
	color = mix(color,gold,clamp(outer_gold*0.88+inner_gold*0.72,0.0,1.0));
	color = mix(color,bright_gold,seam*0.92);
	vec2 glint_a = (UV-vec2(0.27,0.19))*vec2(3.0,4.0);
	vec2 glint_b = (UV-vec2(0.73,0.19))*vec2(3.0,4.0);
	float glint = max(exp(-dot(glint_a,glint_a)*7.0),exp(-dot(glint_b,glint_b)*7.0));
	color += vec3(0.28,0.24,0.16)*glint;
	COLOR = vec4(color,circle_mask);
}