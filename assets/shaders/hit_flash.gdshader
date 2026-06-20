shader_type canvas_item;

// Two independent feedback channels for an entity sprite, driven from code:
//   * warn  — a telegraph glow during an attack wind-up (warm by default).
//   * flash — a blown-to-white hit-flash on taking damage.
// Both mix the sprite toward a colour *before* the vertex COLOR (modulate) is
// applied, so an enemy's tier/skin tint and a death-fade alpha still ride on top.

uniform float warn : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 warn_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = mix(tex.rgb, warn_color.rgb, warn);
	rgb = mix(rgb, vec3(1.0), flash);
	COLOR = vec4(rgb, tex.a) * COLOR;
}
