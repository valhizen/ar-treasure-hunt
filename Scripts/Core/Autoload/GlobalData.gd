# GlobalData.gd - Add as Autoload
extends Node

var spawn_point: String = ""
var player_data: Dictionary = {}

var DEBUG: bool = OS.is_debug_build() and OS.has_feature("editor")
