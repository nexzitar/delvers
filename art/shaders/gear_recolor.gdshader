// Palette-swap for sculpted gear: classifies each texel against three
// reference colors (by chroma, ignoring baked lighting) and remaps to
// the target palette, preserving luminance. One sculpt, many armors.
shader_type spatial;

uniform sampler2D base_tex : source_color, filter_linear_mipmap;
uniform vec3 ref_primary = vec3(0.577, 0.577, 0.577);
uniform vec3 ref_secondary = vec3(0.777, 0.44, 0.44);
uniform vec3 ref_trim = vec3(0.66, 0.66, 0.35);
uniform vec3 col_primary : source_color = vec3(0.33, 0.33, 0.33);
uniform vec3 col_secondary : source_color = vec3(0.33, 0.17, 0.17);
uniform vec3 col_trim : source_color = vec3(0.33, 0.33, 0.17);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
// 0 = keep source luminance; 1 = flat dye (for derived skin-textured
// shells that must become cloth or leather).
uniform float luma_flatten : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 tex = texture(base_tex, UV).rgb;
	vec3 dir = normalize(max(tex, vec3(0.001)));
	float d0 = distance(dir, normalize(ref_primary));
	float d1 = distance(dir, normalize(ref_secondary));
	float d2 = distance(dir, normalize(ref_trim));
	vec3 target = col_primary;
	if (d1 < d0 && d1 <= d2) {
		target = col_secondary;
	} else if (d2 < d0 && d2 < d1) {
		target = col_trim;
	}
	float luma = dot(tex, vec3(0.299, 0.587, 0.114));
	float target_luma = max(dot(target, vec3(0.299, 0.587, 0.114)), 0.05);
	vec3 preserved = clamp(target * (luma / target_luma) * 1.6, vec3(0.0), vec3(1.0));
	vec3 flat_dye = target * (0.55 + luma * 0.8);
	ALBEDO = mix(preserved, flat_dye, luma_flatten);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
