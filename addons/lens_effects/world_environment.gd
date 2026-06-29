@tool
extends WorldEnvironment

## Attach this script to your WorldEnvironment

@export var sun: DirectionalLight3D:
	set(v):
		if v != sun:
			sun = v
			update_configuration_warnings()
var compositor_effect: CompositorEffect

func _ready() -> void:
	for effect in compositor.compositor_effects:
		if effect is LensFlareEffect:
			compositor_effect = effect
			break

	if !compositor_effect:
		push_error("No LensFlareEffect was found in the compositor effects array on the WorldEnvironment node!")


func _process(_delta: float) -> void:
	var camera: Camera3D
	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	else:
		camera = get_viewport().get_camera_3d()

	if !sun or !camera or !compositor_effect:
		return
	
	var dir_dot := (-camera.global_transform.basis.z).normalized().dot(sun.global_transform.basis.z.normalized())
	var viewport_size
	if Engine.is_editor_hint():
		viewport_size = EditorInterface.get_editor_viewport_3d().get_visible_rect().size
	else:
		viewport_size = get_viewport().get_visible_rect().size
	compositor_effect.sun_position = camera.unproject_position(sun.global_transform.basis.z * maxf(camera.near, 1.0) + camera.global_position) / viewport_size
	compositor_effect.sun_dir_sign = dir_dot


func _get_configuration_warnings():
	var warnings = []

	if !sun:
		warnings.append("Please select a DirectionalLight3D to use as reference!")

	# Returning an empty array means "no warning".
	return warnings
