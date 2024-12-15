shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;


group_uniforms base_material;
group_uniforms base_material.maps;
uniform sampler2D texture_albedo_base : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_roughness_base : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_normal_base : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_height_base : source_color,filter_linear_mipmap,repeat_enable;

group_uniforms base_material.settings;
uniform vec4 albedo_base : source_color = vec4(1.0);
uniform float normal_scale_base : hint_range(-16,16) = 1.0;
uniform float specular_base = 0.5;
uniform float blend_softness1:hint_range(0.01, 1.0) = 0.025;

group_uniforms base_material.uv;
varying vec2 uv_base;
uniform vec3 uv_base_scale = vec3(1.0);
uniform vec3 uv_base_offset = vec3(0.0);


group_uniforms red_material;
group_uniforms red_material.maps;
uniform sampler2D texture_albedo_r : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_roughness_r : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_normal_r : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_height_r : source_color,filter_linear_mipmap,repeat_enable;

group_uniforms red_material.settings;
uniform vec4 albedo_r : source_color = vec4(1.0);
uniform float normal_scale_r : hint_range(-16,16) = 1.0;
uniform float specular_r = 0.5;
uniform float blend_softness2:hint_range(0.01, 1.0) = 0.025;

group_uniforms red_material.uv;
varying vec2 uv_r;
uniform vec3 uv_r_scale = vec3(1.0);
uniform vec3 uv_r_offset = vec3(0.0);

group_uniforms green_material;
group_uniforms green_material.maps;
uniform sampler2D texture_albedo_g : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_roughness_g : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_normal_g : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_height_g : source_color,filter_linear_mipmap,repeat_enable;

group_uniforms green_material.settings;
uniform vec4 albedo_g : source_color = vec4(1.0);
uniform float normal_scale_g : hint_range(-16,16) = 1.0;
uniform float specular_g = 0.5;
uniform float blend_softness3:hint_range(0.01, 1.0) = 0.025;

group_uniforms green_material.uv;
varying vec2 uv_g;
uniform vec3 uv_g_scale = vec3(1.0);
uniform vec3 uv_g_offset = vec3(0.0);

group_uniforms blue_material;
group_uniforms blue_material.maps;
uniform sampler2D texture_albedo_b : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_roughness_b : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_normal_b : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_height_b : source_color,filter_linear_mipmap,repeat_enable;

group_uniforms blue_material.settings;
uniform vec4 albedo_b : source_color = vec4(1.0);
uniform float normal_scale_b : hint_range(-16,16) = 1.0;
uniform float specular_b = 0.5;

group_uniforms blue_material.uv;
varying vec2 uv_b;
uniform vec3 uv_b_scale = vec3(1.0);
uniform vec3 uv_b_offset = vec3(0.0);


void vertex() {
	uv_base = UV*uv_base_scale.xy + uv_base_offset.xy;
	uv_r = UV*uv_r_scale.xy + uv_r_offset.xy;
	uv_g = UV*uv_g_scale.xy + uv_g_offset.xy;
	uv_b = UV*uv_b_scale.xy + uv_b_offset.xy;
}

vec3 heightblend(vec3 input1, float height1, vec3 input2, float height2, float softness){
	float height_start = max(height1, height2) - softness;
	float level1 = max(height1 - height_start, 0);
	float level2 = max(height2 - height_start, 0);

	return ((input1 * level1) + (input2 * level2)) / (level1 + level2);
}

float heightblendf(float input1, float height1, float input2, float height2, float softness){
	float height_start = max(height1, height2) - softness;
	float level1 = max(height1 - height_start, 0);
	float level2 = max(height2 - height_start, 0);

	return ((input1 * level1) + (input2 * level2)) / (level1 + level2);
}

vec3 heightlerp(vec3 input1, float height1, vec3 input2, float height2,float softness, float t ){
	t = clamp(t, 0.0 , 1.0);
    return heightblend(input1, height1 * (1.0 - t), input2, height2 * t, softness);
}

float heightlerpf(float input1, float height1, float input2, float height2,float softness, float t ){
	t = clamp(t, 0.0 , 1.0);
    return heightblendf(input1, height1 * (1.0 - t), input2, height2 * t, softness);
}

void fragment() {
	vec3 m1 = texture(texture_height_base, uv_base).rgb;
	vec3 m2 = texture(texture_height_r, uv_r).rgb;
	vec3 m3 = texture(texture_height_g, uv_g).rgb;
	vec3 m4 = texture(texture_height_b, uv_b).rgb;

	vec3 a1 = texture(texture_albedo_base, uv_base).rgb * albedo_base.rgb;
	vec3 a2 = texture(texture_albedo_r, uv_r).rgb * albedo_r.rgb;
	vec3 a3 = texture(texture_albedo_g, uv_g).rgb * albedo_g.rgb;
	vec3 a4 = texture(texture_albedo_b, uv_b).rgb * albedo_b.rgb;

	vec3 r1 = texture(texture_roughness_base, uv_base).rgb;
	vec3 r2 = texture(texture_roughness_r, uv_r).rgb;
	vec3 r3 = texture(texture_roughness_g, uv_g).rgb;
	vec3 r4 = texture(texture_roughness_b, uv_b).rgb;

	vec3 n1 = texture(texture_normal_base, uv_base).rgb;
	vec3 n2 = texture(texture_normal_r, uv_r).rgb;
	vec3 n3 = texture(texture_normal_g, uv_g).rgb;
	vec3 n4 = texture(texture_normal_b, uv_b).rgb;

	vec3 m_blend1 = heightlerp(m1.rgb, m1.r, m2.rgb, m2.r, blend_softness1, COLOR.r);
	vec3 m_blend2 = heightlerp(m_blend1.rgb, m_blend1.r, m3.rgb, m3.r, blend_softness2, COLOR.g);
	vec3 m_blend3 = heightlerp(m_blend2.rgb, m_blend2.r, m4.rgb, m4.r, blend_softness3, COLOR.b);

	vec3 r_blend = heightlerp(r1.rgb, m1.r, r2.rgb, m2.r, blend_softness1, COLOR.r);
	r_blend = heightlerp(r_blend.rgb, m_blend1.r, r3.rgb, m3.r, blend_softness2, COLOR.g);
	r_blend = heightlerp(r_blend.rgb, m_blend2.r, r4.rgb, m4.r, blend_softness3, COLOR.b);

	vec3 a_blend = heightlerp(a1.rgb, m1.r, a2.rgb, m2.r, blend_softness1, COLOR.r);
	a_blend = heightlerp(a_blend.rgb, m_blend1.r, a3.rgb, m3.r, blend_softness2, COLOR.g);
	a_blend = heightlerp(a_blend.rgb, m_blend2.r, a4.rgb, m4.r, blend_softness3, COLOR.b);

	vec3 n_blend = heightlerp(n1.rgb, m1.r, n2.rgb, m2.r, blend_softness1, COLOR.r);
	n_blend = heightlerp(n_blend.rgb, m_blend1.r, n3.rgb, m3.r, blend_softness2, COLOR.g);
	n_blend = heightlerp(n_blend.rgb, m_blend2.r, n4.rgb, m4.r, blend_softness3, COLOR.b);

	float nd_blend = heightlerpf(normal_scale_base, m1.r, normal_scale_r, m2.r, blend_softness1, COLOR.r);
	nd_blend = heightlerpf(nd_blend, m_blend1.r, normal_scale_g, m3.r, blend_softness2, COLOR.g);
	nd_blend = heightlerpf(nd_blend, m_blend2.r, normal_scale_b, m4.r, blend_softness3, COLOR.b);

	float s_blend = heightlerpf(specular_base, m1.r, specular_r, m2.r, blend_softness1, COLOR.r);
	s_blend = heightlerpf(s_blend, m_blend1.r, specular_g, m3.r, blend_softness2, COLOR.g);
	s_blend = heightlerpf(s_blend, m_blend2.r, specular_b, m4.r, blend_softness3, COLOR.b);

	ALBEDO = a_blend.rgb;
	NORMAL_MAP = n_blend.rgb;
	vec3 roughness_texture_channel = vec3(1.0,0.0,0.0);
	ROUGHNESS = dot(r_blend, roughness_texture_channel);
	SPECULAR = s_blend;
	NORMAL_MAP_DEPTH = nd_blend;
}
