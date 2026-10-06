shader_type sky;
uniform vec3 sun_direction = vec3(1.0,0.1,0.0);
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform float cloud_time = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p) {
	float value=0.0,weight=0.55;
	for(int i=0;i<4;i++){value+=weight*noise(p);p=mat2(vec2(1.6,1.2),vec2(-1.2,1.6))*p;weight*=0.5;}
	return value;
}
void sky() {
	vec3 ray=normalize(EYEDIR);
	float height=clamp(ray.y,0.0,1.0);
	vec3 night=mix(vec3(0.025,0.035,0.075),vec3(0.005,0.012,0.035),pow(height,0.4));
	vec3 day=mix(vec3(0.73,0.84,0.92),vec3(0.12,0.36,0.69),pow(height,0.45));
	vec3 color=mix(night,day,daylight);
	float sunset_side=pow(max(dot(ray.xz,normalize(sun_direction.xz)),0.0),4.0);
	color+=vec3(0.68,0.22,0.045)*twilight*exp(-height*5.0)*(0.25+0.75*sunset_side);
	vec2 star_uv=vec2(atan(ray.z,ray.x),asin(clamp(ray.y,-1.0,1.0)))*260.0;
	float star=step(0.997,hash(floor(star_uv)))*pow(max(0.0,1.0-length(fract(star_uv)-0.5)*2.0),8.0);
	color+=vec3(star)*(1.0-daylight)*smoothstep(0.02,0.2,ray.y);
	float sun_dot=dot(ray,sun_direction);
	color+=vec3(1.0,0.72,0.36)*pow(max(sun_dot,0.0),100.0)*0.38;
	color+=mix(vec3(1.0,0.39,0.10),vec3(1.0,0.96,0.82),daylight)*smoothstep(0.99990,0.99996,sun_dot)*2.2;
	float moon_dot=dot(ray,-sun_direction);
	float moon=smoothstep(0.99990,0.99996,moon_dot);
	float crater=0.78+0.22*noise(ray.xz*1600.0);
	color+=vec3(0.70,0.77,0.87)*moon*crater*(1.0-daylight*0.75);
	vec2 cloud_uv=ray.xz/max(ray.y,0.08)*1.4+vec2(cloud_time*0.009,cloud_time*0.003);
	float cloud=smoothstep(0.47,0.70,fbm(cloud_uv))*smoothstep(0.01,0.15,ray.y);
	vec3 cloud_color=mix(vec3(0.055,0.067,0.10),vec3(0.91,0.93,0.94),daylight);
	cloud_color=mix(cloud_color,vec3(0.89,0.48,0.26),twilight*0.65);
	cloud_color*=0.80+0.20*fbm(cloud_uv+vec2(0.12,0.04));
	color=mix(color,cloud_color,cloud*0.94);
	if(ray.y<0.0) color=mix(color,mix(vec3(0.025,0.03,0.045),vec3(0.32,0.39,0.38),daylight),smoothstep(0.0,0.15,-ray.y));
	COLOR=color;
}
