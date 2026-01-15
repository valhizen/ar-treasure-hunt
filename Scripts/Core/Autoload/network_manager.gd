extends Node
## NetworkManager - Handles all HTTP communication with backend server
## AutoLoad Singleton

#region Signals
signal request_completed(response: Dictionary)
signal request_failed(error: String)
signal connection_status_changed(is_online: bool)
#endregion

#region Configuration
## Your backend server URL (change this!)
@export var base_url: String = "https://arthbackend.valhizen.dev/api"

## For local development
const LOCAL_URL: String = "http://localhost:3000/api"

## Use local server in debug builds
@export var use_local_in_debug: bool = false

## Request timeout in seconds
@export var timeout_seconds: float = 30.0
#endregion

#region State
var is_online: bool = false
var auth_token: String = ""
var current_user: Dictionary = {}
#endregion

#region Node References
var http_request: HTTPRequest
#endregion

func _ready() -> void:
	# Create HTTP request node
	http_request = HTTPRequest.new()
	http_request.timeout = timeout_seconds
	add_child(http_request)
	
	# Determine which URL to use
	if OS.is_debug_build() and use_local_in_debug:
		base_url = LOCAL_URL
	
	print("[NetworkManager] Initialized. Server: %s" % base_url)


#region Public API Methods
func set_auth_token(token: String) -> void:
	"""Set authentication token for requests"""
	auth_token = token
	print("[NetworkManager] Auth token set")


func clear_auth() -> void:
	"""Clear authentication"""
	auth_token = ""
	current_user = {}


func get_headers() -> PackedStringArray:
	"""Get headers for requests"""
	var headers = PackedStringArray([
		"Content-Type: application/json"
	])
	
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer %s" % auth_token)
	
	return headers
#endregion

#region HTTP Request Methods
func api_get(endpoint: String) -> Dictionary:
	"""Make GET request to API"""
	var url = base_url + endpoint
	
	var new_request = HTTPRequest.new()
	add_child(new_request)
	
	var error = new_request.request(url, get_headers(), HTTPClient.METHOD_GET)
	
	if error != OK:
		new_request.queue_free()
		return {"success": false, "error": "Request failed to start"}
	
	var result = await new_request.request_completed
	new_request.queue_free()
	
	return _parse_response(result)


func api_post(endpoint: String, data: Dictionary) -> Dictionary:
	"""Make POST request to API"""
	var url = base_url + endpoint
	var json_body = JSON.stringify(data)
	
	var new_request = HTTPRequest.new()
	add_child(new_request)
	
	var error = new_request.request(url, get_headers(), HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		new_request.queue_free()
		return {"success": false, "error": "Request failed to start"}
	
	var result = await new_request.request_completed
	new_request.queue_free()
	
	return _parse_response(result)


func api_put(endpoint: String, data: Dictionary) -> Dictionary:
	"""Make PUT request to API"""
	var url = base_url + endpoint
	var json_body = JSON.stringify(data)
	
	var new_request = HTTPRequest.new()
	add_child(new_request)
	
	var error = new_request.request(url, get_headers(), HTTPClient.METHOD_PUT, json_body)
	
	if error != OK:
		new_request.queue_free()
		return {"success": false, "error": "Request failed to start"}
	
	var result = await new_request.request_completed
	new_request.queue_free()
	
	return _parse_response(result)


func _parse_response(result: Array) -> Dictionary:
	"""Parse HTTP response"""
	var response_code = result[1]
	var body = result[3]
	
	if response_code == 0:
		is_online = false
		connection_status_changed.emit(false)
		return {"success": false, "error": "Could not connect to server"}
	
	is_online = true
	connection_status_changed.emit(true)
	
	# Parse JSON body
	var json = JSON.new()
	var body_string = body.get_string_from_utf8()
	
	if body_string.is_empty():
		if response_code >= 200 and response_code < 300:
			return {"success": true, "data": {}}
		else:
			return {"success": false, "error": "Server error: %d" % response_code}
	
	var parse_error = json.parse(body_string)
	
	if parse_error != OK:
		return {"success": false, "error": "Invalid response from server"}
	
	var data = json.data
	
	if response_code >= 200 and response_code < 300:
		return {"success": true, "data": data}
	else:
		var error_msg = data.get("message", data.get("error", "Unknown error"))
		return {"success": false, "error": error_msg, "code": response_code}
#endregion

#region Utility
func check_connection() -> bool:
	"""Check if server is reachable"""
	var result = await api_get("/health")
	is_online = result.success
	connection_status_changed.emit(is_online)
	return is_online
#endregion
