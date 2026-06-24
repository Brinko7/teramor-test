extends RefCounted
class_name CameraFit

## Fits a follow-camera's zoom to a scene's map so the hi-fi 1280x720 (1:1) viewport
## never shows void around an undersized old-scale map. Native 1:1 (zoom 1.0, the
## crispest — sprite pixels map 1:1 to screen) whenever the map already covers the
## view; only maps SMALLER than the viewport zoom in to *cover* it (a mild fractional
## upscale on those few, still far better than the old global downsample). Call AFTER
## the camera's limits are set so the cover math matches the clamp bounds.
static func fit(cam: Camera2D, map_size: Vector2i) -> void:
	if cam == null or map_size.x <= 0 or map_size.y <= 0:
		return
	var vw := float(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)))
	var vh := float(int(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	var z := maxf(1.0, maxf(vw / float(map_size.x), vh / float(map_size.y)))
	cam.zoom = Vector2(z, z)
