class_name TextFormat
## Text formatting shared by the HUD and the end-of-game screens.


## Shows whole seconds as minutes:seconds, e.g. 125 -> "2:05".
static func time(total_seconds: int) -> String:
	return "%d:%02d" % [floori(total_seconds / 60.0), total_seconds % 60]
