shader_type canvas_item;

uniform vec4 orb_color : source_color = vec4(0.88, 0.16, 0.19, 1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.42;

void fragment() {
    vec2 centered_uv = UV * 2.0 - vec2(1.0);
    float radius = length(centered_uv);
    float disc_alpha = 1.0 - smoothstep(0.92, 1.0, radius);
    float rim = smoothstep(0.72, 0.88, radius) * (1.0 - smoothstep(0.88, 0.98, radius));
    float inner_shine = pow(max(0.0, 1.0 - radius), 2.2);
    float halo = 1.0 - smoothstep(0.18, 0.98, radius);
    vec3 lit_color = orb_color.rgb * (0.66 + inner_shine * 0.72);
    lit_color += vec3(1.0) * (rim * 0.20 + halo * glow_strength * 0.16);
    COLOR = vec4(lit_color, disc_alpha * orb_color.a);
}
