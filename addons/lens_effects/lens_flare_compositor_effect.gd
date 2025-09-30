@tool
extends BaseCompositorEffect
class_name LensFlareEffect

## Path to your GLSL compute shader
@export_file_path("*.glsl") var ShaderPath := "res://addons/lens_effects/lens_flares.glsl":
	set(v):
		ShaderPath = v
		_initialize_render()
		settings_dirty = true

## Projected position of the sun in screen coordinates. Usually gets set by code.
var sun_position = Vector2():
	set(v):
		sun_position = v
		settings_dirty = true
## 1.0 if looking at the sun, -1.0 else. Usually gets set by code.
var sun_dir_sign := 1.0
## Color of the sun, lens flares and god rays. Use the alpha to control strength
@export var sun_color = Color("423563"):
	set(v):
		sun_color = v
		settings_dirty = true
@export_group("Sun Settings", "Effect_")
## How bright the center of the sun is
@export var Effect_Multiplier := 3.593:
	set(v):
		Effect_Multiplier = v
		settings_dirty = true
## Controls the blending of the center and the lens flares around it
@export var Effect_Easing := 0.576:
	set(v):
		Effect_Easing = clampf(v, 0.0, 10.0)
		settings_dirty = true
@export_group("Anamorphic flares", "Anamorphic_")
@export var Anamorphic_Threshold := 0.5:
	set(v):
		Anamorphic_Threshold = v
		settings_dirty = true
## Strength of the anamorphic lens flare
@export var Anamorphic_Intensity := 400.0:
	set(v):
		Anamorphic_Intensity = v
		settings_dirty = true
## How much the anamorphic flare is stretched horizontally
@export var Anamorphic_Stretch := 0.44:
	set(v):
		Anamorphic_Stretch = v
		settings_dirty = true
## Brightness of the anamorphic flare
@export var Anamorphic_Brightness := 0.574:
	set(v):
		Anamorphic_Brightness = v
		settings_dirty = true
@export_group("God rays")
## The higher, the longer the shadow cast by the godrays
@export_range(0.0, 1.0, 0.001) var Decay := 0.99:
	set(v):
		Decay = v
		settings_dirty = true
## Together with Decay it controls the length of the god rays
@export_range(0.0, 1.0, 0.001) var Density := 0.99:
	set(v):
		Density = v
		settings_dirty = true
## Basically strength of the godray effect. The higher the darker the shadow cast by them.
@export var Weight := 0.022:
	set(v):
		Weight = v
		settings_dirty = true
## Very important setting. Controls how many radial blur samples are taken. Higher values increase the quality/ resolution of the god rays at the cost of performance. 
@export_range(1, 1000, 1) var SampleCount := 15:
	set(v):
		SampleCount = v
		settings_dirty = true


# Set 0 (already defined in BaseCompositorEffect)
# Scene data UBO = 0
# Color image = 1

# Set 1
const EFFECT_DATA_UBO_BINDING := 0

var context := &"Context"

var shader : RID
var shader_pipeline : RID

var effect_data_ubo : RID
var effect_data_ubo_uniform : RDUniform

var settings_dirty := false


# Called from _init().
func _initialize_resource() -> void:
	# access_resolved_color = true
	# access_resolved_depth = true
	# needs_normal_roughness = true
	pass


# Called on render thread after _init().
func _initialize_render() -> void:
	shader = create_shader(ShaderPath)


# Called at beginning of _render_callback(), after updating render variables
# and after _render_size_changed().
# Use this function to setup textures or uniforms.
func _render_setup() -> void:
	if not effect_data_ubo.is_valid() or settings_dirty:
		update_or_recreate_global_uniform_buffer()
		create_shader_pipeline()
	if not rd.compute_pipeline_is_valid(shader_pipeline):
		create_shader_pipeline()


# Called for each view. Run the compute shaders from here.
func _render_view(p_view : int) -> void:
	var scene_uniform_set : Array[RDUniform] = [
		get_scene_data_ubo(),
		get_color_image_uniform(p_view),
		get_depth_sampler_uniform(p_view, nearest_sampler),
		get_color_sampler_uniform(p_view, nearest_sampler)
	]
	var df_uniform_set : Array[RDUniform] = [effect_data_ubo_uniform]
	
	var uniform_sets : Array[Array] = [
		scene_uniform_set,
		df_uniform_set
	]

	run_compute_shader(
	 	"Lens Flares",
	 	shader,
	 	shader_pipeline,
	 	uniform_sets,
	 )


# Called before _render_setup() if `render_size` has changed.
func _render_size_changed() -> void:
	# Clear all textures under this context.
	# This will trigger creation of new textures.
	render_scene_buffers.clear_context(context)
	settings_dirty = true


# func create_textures() -> void:
	# texture_image = create_simple_texture(
	# 		context,
	# 		texture,
	# 		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
	# )

	# texture_image_uniform = get_image_uniform(texture_image, TEXTURE_IMAGE_BINDING)


func create_global_uniform_buffer() -> void:
	if effect_data_ubo.is_valid():
		free_rid(effect_data_ubo)

	var data := get_global_uniform_data()
	effect_data_ubo = create_uniform_buffer(data)
	
	effect_data_ubo_uniform = get_uniform_buffer_uniform(effect_data_ubo, EFFECT_DATA_UBO_BINDING)
	settings_dirty = false


## IMPORTANT: Order must match EffectData (struct) UBO layouts in the glsl shaders.
## Vector4's must come first or they get misaligned if the smaller 4-byte variables
## are not in groups of 4 (16 bytes).
func get_global_uniform_data() -> Array:
	var pos = sun_position
	return [
		sun_color, # vec4
		pos.x,
		pos.y,
		sun_dir_sign,
		Anamorphic_Threshold,
		Anamorphic_Intensity,
		Anamorphic_Stretch,
		Anamorphic_Brightness,
		Effect_Multiplier,
		Effect_Easing,
		Decay,
		Density,
		Weight,
		float(SampleCount)
	]


## Tries to update the existing effect_data_ubo but if that throws an error,
## it recreates it
func update_or_recreate_global_uniform_buffer():
	if !effect_data_ubo.is_valid():
		create_global_uniform_buffer()
		return
	var data := get_global_uniform_data()
	var update_err := update_uniform_buffer(effect_data_ubo, data)
	if update_err:
		create_global_uniform_buffer()
		return
	effect_data_ubo_uniform = get_uniform_buffer_uniform(effect_data_ubo, EFFECT_DATA_UBO_BINDING)
	settings_dirty = false



func create_shader_pipeline():
	if rd.compute_pipeline_is_valid(shader_pipeline):
		rd.free_rid(shader_pipeline)
	shader_pipeline = create_pipeline(shader)
