shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform int tile = 0;
uniform vec3 tile_meters = vec3(2.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 read_tile(vec2 uv) {
 vec2 cell = vec2(float(tile % 3), float(tile / 3));
 vec2 inset = mix(vec2(0.006), vec2(0.994), fract(uv));
 return texture(atlas, (cell + inset) / 3.0).rgb;
}
void fragment() {
 vec3 p = world_position / tile_meters;
 vec3 weights = pow(abs(normalize(world_normal)), vec3(8.0));
 weights /= max(weights.x + weights.y + weights.z, 0.001);
 ALBEDO = (read_tile(p.zy) * weights.x + read_tile(p.xz) * weights.y + read_tile(p.xy) * weights.z) * tint.rgb;
 ROUGHNESS = 0.88;
 SPECULAR = 0.12;
}
