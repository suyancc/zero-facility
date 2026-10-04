extends ColorRect
const CODE:String="""shader_type canvas_item;
render_mode unshaded;
uniform float strength = 0.0;
uniform float pulse = 0.0;
uniform float subtle = 0.0;
void fragment(){
 vec2 p = abs(UV * 2.0 - 1.0);
 float edge = smoothstep(0.66 - 0.045*pulse*(1.0-subtle), 1.03, max(p.x,p.y));
 float corner = smoothstep(0.85,1.40,length(p));
 float breathing = mix(0.78 + 0.22*pulse, 0.78, subtle);
 float alpha = min(0.43,(edge*0.29+corner*0.14)*strength*breathing);
 vec3 ink = mix(vec3(0.12,0.008,0.018),vec3(0.70,0.035,0.07),edge*(0.60+0.28*pulse*(1.0-subtle)));
 COLOR=vec4(ink,alpha);
}"""
var fx:ShaderMaterial
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader:=Shader.new();shader.code=CODE;fx=ShaderMaterial.new();fx.shader=shader;material=fx
func update_tension(data:Dictionary,enabled:bool,reduced:bool)->void:
	visible=enabled and float(data.intensity)>0.015
	fx.set_shader_parameter("strength",float(data.intensity)*(0.50 if reduced else 1.0))
	fx.set_shader_parameter("pulse",data.pulse)
	fx.set_shader_parameter("subtle",1.0 if reduced else 0.0)

