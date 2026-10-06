shader_type spatial;
render_mode cull_back;
uniform vec4 tint : source_color = vec4(0.455, 0.376, 0.290, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),f.x),f.y);
}
void fragment() {
    // Cylinder UVs: long irregular fissures, with a low-frequency mottled base.
    float bend = (noise(UV*vec2(12.0,18.0))-.5)*4.0;
    float phase = UV.x * 100.53096 + bend;
    float fade = 1.0 - smoothstep(0.3, 1.5, fwidth(phase));
    float ridge = sin(phase) * 0.5 + 0.5;
    float cracks = pow(1.0 - ridge, 7.0) * fade;
    float grain = sin(UV.x * 301.5929 + sin(UV.y * 43.0)) * fade;
    float mottling = sin(UV.y * 11.0 + sin(UV.x * 25.1327));
    float flakes = noise(UV*vec2(65.0,45.0));
    float patches = noise(UV*vec2(18.0,16.0));
    ALBEDO = tint.rgb * (0.64 + flakes*.35 + patches*.40 + ridge * 0.10 * fade - cracks * 0.34 + grain * 0.04 + mottling * 0.04);
    NORMAL_MAP = normalize(vec3(cos(phase) * 0.20 * fade, (flakes-.5)*0.18 * fade, 1.0)) * 0.5 + 0.5;
    ROUGHNESS = 0.95;
}
