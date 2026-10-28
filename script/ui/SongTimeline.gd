class_name SongTimeline
extends TextureProgressBar


func _ready() -> void:
	TimingEngine.time_updated.connect(_on_time_updated)
	max_value = 1.0
	value = 0.0
	_create_blank_textures()


func _create_blank_textures() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	texture_under = tex
	texture_progress = tex


func _on_time_updated(time_sec: float) -> void:
	if ChartParser.get_duration_seconds() > 0.0:
		value = time_sec / ChartParser.get_duration_seconds()
