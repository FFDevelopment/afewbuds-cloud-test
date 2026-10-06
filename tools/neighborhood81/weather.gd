extends RefCounted
var world: Node3D
var material: ShaderMaterial
var moon: DirectionalLight3D
var cloud_seconds := 0.0
var sun_direction := Vector3.RIGHT
var daylight := 1.0
func setup(owner_node: Node3D) -> void:
	world=owner_node
	material=ShaderMaterial.new()
	material.shader=load("res://scripts/weather.gdshader")
	var sky := Sky.new()
	sky.radiance_size=Sky.RADIANCE_SIZE_64
	sky.sky_material=material
	sky.process_mode=Sky.PROCESS_MODE_REALTIME
	world.outdoor_environment.background_mode=Environment.BG_SKY
	world.outdoor_environment.sky=sky
	moon=DirectionalLight3D.new()
	moon.name="NeighborhoodMoonlight"
	moon.shadow_enabled=false
	moon.light_color=Color("a6badd")
	world.add_child(moon)
	update(0.0)
func update(delta: float) -> void:
	if not world.host._simulation_blocked(): cloud_seconds+=delta
	var angle: float = (world.host.game_time_minutes-360.0)/1440.0*TAU
	sun_direction=Vector3(cos(angle),sin(angle),-0.18).normalized()
	daylight=smoothstep(-0.16,0.16,sun_direction.y)
	var twilight := (1.0-smoothstep(0.04,0.24,absf(sun_direction.y)))*smoothstep(-0.22,0.04,sun_direction.y)
	material.set_shader_parameter("sun_direction",sun_direction)
	material.set_shader_parameter("daylight",daylight)
	material.set_shader_parameter("twilight",twilight)
	material.set_shader_parameter("cloud_time",cloud_seconds)
	world.outdoor_sun.look_at(world.outdoor_sun.global_position-sun_direction,Vector3.UP)
	world.outdoor_sun.light_energy=maxf(0.0,sun_direction.y)*0.65
	world.outdoor_sun.light_color=Color("fff2d8").lerp(Color("ff9b58"),twilight)
	world.outdoor_sun.visible=sun_direction.y> -0.12
	moon.look_at(moon.global_position+sun_direction,Vector3.UP)
	moon.light_energy=maxf(0.0,-sun_direction.y)*0.075
	moon.visible=sun_direction.y<0.0
	world.outdoor_environment.ambient_light_color=Color("8797b7").lerp(Color("c6d0d1"),daylight)
	world.outdoor_environment.ambient_light_energy=lerpf(0.17,0.38,daylight)
	for lamp in world.lamps: lamp.light_energy=lerpf(0.8,0.0,smoothstep(0.1,0.75,daylight))
