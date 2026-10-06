shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 tile_meters = vec3(2.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 read_tile(vec2 uv) {
 // Mirrored repetition is continuous at tile edges, without a fract derivative jump.
 vec2 mirrored = 1.0 - abs(mod(uv, 2.0) - 1.0);
 return texture(surface_texture, mirrored).rgb;
}
void fragment() {
 vec3 p = world_position / tile_meters;
 vec3 weights = pow(abs(normalize(world_normal)), vec3(8.0));
 weights /= max(weights.x + weights.y + weights.z, 0.001);
 ALBEDO = (read_tile(p.zy) * weights.x + read_tile(p.xz) * weights.y + read_tile(p.xy) * weights.z) * tint.rgb;
 ROUGHNESS = 0.88;
 SPECULAR = 0.12;
}
