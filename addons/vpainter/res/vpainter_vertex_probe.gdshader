shader_type spatial;
render_mode unshaded;


uniform float outline_width : hint_range(0.0, 10.0, 0.1) = 5.0;

uniform vec4 base_color : source_color = vec4(1.0);

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

void fragment()
{
	float basic_fresnel = fresnel(outline_width, NORMAL, VIEW);
	basic_fresnel = step(0.5, basic_fresnel);
	ALBEDO = mix(COLOR.rgb, vec3(0.0), basic_fresnel);
}