shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_burley,specular_schlick_ggx,unshaded,ambient_light_disabled,fog_disabled;

uniform vec4 albedo : source_color;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

void fragment() {
	float depth_tex = textureLod(depth_texture,SCREEN_UV,0.0).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,depth_tex,1.0);
	world_pos.xyz /= world_pos.w;
	float prox = clamp(1.0-smoothstep(world_pos.z, world_pos.z+0.5, VERTEX.z),0.0,1.0);
	float n = dot(NORMAL, VIEW);
	float edge = pow(1.0 - n, 4.0);
	ALBEDO = clamp(albedo.rgb * texture(albedo_tex, vec2(edge)).rgb - prox, -0.5, 1.0);
	ALPHA *= clamp(max(edge, prox*0.5), 0.0, 1.0)*albedo.a;
}
