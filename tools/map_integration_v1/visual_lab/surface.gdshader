shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint: source_color = vec4(0.5,0.25,0.17,1.0);
uniform int finish = 0;
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 uv=abs(wn.y)>.65?wp.xz:(abs(wn.x)>.65?wp.zy:wp.xy);
 float grain=noise(uv*110.0);
 vec3 col=tint.rgb;
 if(finish==0){
  vec2 b=uv/vec2(.42,.18);b.x+=mod(floor(b.y),2.0)*.5;
  vec2 cell=floor(b);vec2 q=fract(b);
  float edge=min(min(q.x,1.0-q.x)*.42,min(q.y,1.0-q.y)*.18);
  float aa=max(fwidth(edge),.001);
  float mortar=1.0-smoothstep(.006-aa,.01+aa,edge);
  col*=.94+hash(cell)*.12;
  col=mix(col,vec3(.32,.30,.26),mortar*.65);
  col*=mix(.86,1.0,smoothstep(0.0,1.2,wp.y));
 }else if(finish==1){
  vec2 q=fract(uv/1.25);float edge=min(min(q.x,1.0-q.x),min(q.y,1.0-q.y));
  float joint=1.0-smoothstep(.003,.008+fwidth(edge),edge);
  col*=.95+noise(uv*2.0)*.08;col*=1.0-joint*.18;
 }else if(finish==2){
  col*=.94+noise(uv*.6)*.10;col*=.95+grain*.1;
 }else if(finish==3){
  col*=.985+noise(uv*12.0)*.03;
 }else if(finish==4){
  vec2 p=uv*30.0;vec2 base=floor(p);vec2 f=fract(p);float nearest=2.0;vec2 nearest_cell=vec2(0);
  for(int x=-1;x<=1;x++){for(int y=-1;y<=1;y++){
   vec2 o=vec2(float(x),float(y));vec2 cell=base+o;
   vec2 point=o+vec2(hash(cell),hash(cell+17.3));float dist=length(point-f);
   if(dist<nearest){nearest=dist;nearest_cell=cell;}
  }}
  float fade=clamp(length(fwidth(p)),0.0,1.0);
  col*=mix((.72+hash(nearest_cell)*.4)*(1.0-smoothstep(.35,.7,nearest)*.25),.88,fade);
 }else if(finish==5){col*=.85+noise(uv*18.0)*.25;}
 else if(finish==6){col*=.9+noise(uv*7.0)*.2;}
 else if(finish==7){
  vec2 q=fract(uv/vec2(.6,.3));float joint=1.0-smoothstep(.005,.025+fwidth(q.y),q.y);
  col*=.92+noise(uv*5.0)*.12;col*=1.0-joint*.18;
 }else{col*=.98+noise(uv*14.0)*.04;}
 ALBEDO=col*(.99+grain*.02);ROUGHNESS=.94;SPECULAR=.08;
}
