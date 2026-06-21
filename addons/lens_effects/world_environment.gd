@tool
extends WorldEnvironment

## Attach this script to your WorldEnvironment

@export var sun: DirectionalLight3D:
	set(v):
		if v != sun:
			sun = v
			update_configuration_warnings()
var camera: Camera3D

func _ready() -> void:
	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	else:
		camera = get_viewport().get_camera_3d()
	if !camera:
		push_error("No camera has been found in the scene. You need at least 1 camera in order for the lens effect to work!")

func _process(_delta: float) -> void:
	if !sun or !camera:
		return
	
	var dir_dot := (-camera.global_transform.basis.z).normalized().dot(sun.global_transform.basis.z.normalized())
	compositor.compositor_effects[0].sun_position = camera.unproject_position(sun.global_transform.basis.z * maxf(camera.near, 1.0) + camera.global_position)
	
	compositor.compositor_effects[0].sun_dir_sign = dir_dot


func _get_configuration_warnings():
	var warnings = []

	if !sun:
		warnings.append("Please select a DirectionalLight3D to use as reference!")

	# Returning an empty array means "no warning".
	return warnings
