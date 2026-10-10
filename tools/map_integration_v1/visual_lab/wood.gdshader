shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint:source_color=vec4(.43,.36,.28,1.0);
uniform bool floor_boards=false;
uniform bool existing_boards=false;
varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){local_pos=VERTEX;local_normal=NORMAL;world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=abs(local_normal.x)>.65?local_pos.zy:local_pos.xy;
 if(abs(local_normal.y)>.65)p=local_pos.zx;
 if(floor_boards || existing_boards)p=world_pos.zx;
 float row=floor(p.x/.25);
 float shift=hash(vec2(row,7.0))*1.8;
 float board=floor((p.y+shift)/1.8);
 vec2 grain_uv=vec2(p.x*100.0+noise(vec2(p.y*.8,row))*.65,p.y*.8);
 float fine=noise(grain_uv);
 float soft=noise(vec2(p.x*23.0,p.y*.5));
 float fade=1.0-smoothstep(.4,1.8,length(fwidth(grain_uv)));
 vec3 col=tint.rgb*(.96+soft*.06+(fine-.5)*.12*fade);
 if(floor_boards){
  vec2 q=fract(vec2(p.x/.25,(p.y+shift)/1.8));
  float edge=min(min(q.x,1.0-q.x)*.25,min(q.y,1.0-q.y)*1.8);
  float aa=max(fwidth(edge),.0005);
  float seam=1.0-smoothstep(.001-aa,.003+aa,edge);
  col*=.94+hash(vec2(row,board))*.12;
  col*=1.0-seam*.32;
 }
 ALBEDO=col;ROUGHNESS=.82;SPECULAR=.16;
}
