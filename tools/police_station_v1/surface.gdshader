shader_type spatial;
render_mode world_vertex_coords;
uniform vec4 tint:source_color=vec4(1.0);
uniform int finish=0;
varying vec3 at;
float noise(vec3 p){return fract(sin(dot(floor(p),vec3(12.9898,78.233,37.719)))*43758.5453);}
void vertex(){at=VERTEX;}
void fragment(){
 float grain=noise(at*160.0)-.5;
 float value=1.0+grain*.055;
 if(finish==1){
  float fiber=sin(at.x*140.0+sin(at.z*3.0)*2.5+sin(at.z*12.0)*.5);
  value=.92+fiber*.055+grain*.045;
 }
 if(finish==2){
  float fleck=noise(at*105.0);
  value=fleck>.965?.73:(fleck<.04?1.09:.98+grain*.07);
 }
 ALBEDO=tint.rgb*value;
 ROUGHNESS=finish==1?.68:.86;
}
