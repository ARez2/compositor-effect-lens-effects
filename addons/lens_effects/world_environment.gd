@tool
extends WorldEnvironment

## Attach this script to your WorldEnvironment

@export var sun: DirectionalLight3D
var camera: Camera3D

func _ready() -> void:
	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	else:
		camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	if !sun:
		return
	compositor.compositor_effects[0].sun_color.a = clampf((-camera.global_transform.basis.z).normalized().dot(sun.global_transform.basis.z.normalized()), 0.001, 1.0)
	compositor.compositor_effects[0].sun_position = camera.unproject_position(sun.global_transform.basis.z * maxf(camera.near, 1.0) + camera.global_position)
