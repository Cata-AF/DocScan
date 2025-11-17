extends Node

@export var download_requements_panel : Panel
@export var btn_download_requirements : Button
@export var img_loading : TextureRect
@export var scene_processed_file : PackedScene
@export var processed_files_container : VBoxContainer
@export var files_dropped_list : ItemList

@export var panel_processed_files : Panel
@export var label_files_processed : Label
@export var progress_bar_processed_files : ProgressBar
@export var use_threads : CheckButton

var bin_path_format = "%s/bin"
var temp_dir_path_format = "%s/temp"

var bin_path = ""
var temp_dir_path = ""

var pandoc_version = "3.8.2"

var docx_files: PackedStringArray = []
var processed_files: Array[ICProcessedFile] = []

var active_threads : Array[Thread] = []

var files_processed: int = 0

func _ready() -> void:
	bin_path = bin_path_format % get_working_dir_path()
	temp_dir_path = temp_dir_path_format  % get_working_dir_path()

	print("bin_path -> %s" % bin_path)
	print("temp_dir_path -> %s" % temp_dir_path)

	get_window().files_dropped.connect(_on_window_files_dropped)
	_validate_requirements()


func _validate_requirements():
	img_loading.visible = false
	download_requements_panel.visible = not FileAccess.file_exists(get_pandoc_path())


func _on_window_files_dropped(files: PackedStringArray) -> void:
	docx_files.clear()

	files_dropped_list.clear()

	for file_path in files:
		if file_path.contains(".docx"):
			docx_files.append(file_path)
			#files_dropped_list.add_item(file_path)
			files_dropped_list.add_item(file_path.get_file())

	#DisplayServer.window_request_attention()
	DisplayServer.window_move_to_foreground()


func _on_button_download_pressed() -> void:
	btn_download_requirements.disabled = true
	img_loading.visible = true
	await _prepare_requirements()
	btn_download_requirements.disabled = false
	img_loading.visible = false


func _prepare_requirements():

	var zip_path = get_pandoc_compressed_file_path();

	if not DirAccess.dir_exists_absolute(bin_path):
		DirAccess.make_dir_absolute(bin_path)

	# Download pandoc
	if not FileAccess.file_exists(zip_path):
		var url = get_pandoc_download_url()
		var req = HTTPRequest.new()

		print("⚙️ Downloading Pandoc from url: %s" % url)

		req.download_file = zip_path
		add_child(req)
		req.request(url)

		var result = await req.request_completed

		if result[0] != OK:
			push_error("❌ Error trying to make the request to download pandoc, err %d" % result[0])
			return

		if result[1] != HTTPClient.RESPONSE_OK:
			push_error("❌ Error response %d" % result[1])
			return

		print("✅ Pandoc has been succesfully downloaded at: ", ProjectSettings.globalize_path(req.download_file))

	# Extract pandoc
	if not FileAccess.file_exists(get_pandoc_path()):

		var exit_code
		var output = []

		if OS.get_name() == "Linux":
			exit_code = OS.execute("tar", [
				"-xzf", ProjectSettings.globalize_path(zip_path),
				"-C", ProjectSettings.globalize_path(bin_path)
			], output, true)
		else:
			exit_code = OS.execute("powershell.exe", [
				"Expand-Archive",
				"-Path", "'%s'" % ProjectSettings.globalize_path(zip_path),
				"-DestinationPath", "'%s'" % ProjectSettings.globalize_path(bin_path),
				"-Force"
			], output, true)

		if exit_code != OK:
			push_error("❌ Failed to extract (exit code: %d), output:\n%s" % [exit_code, "".join(output)])
			return

		print("✅ Successfully extracted pandoc")

	download_requements_panel.visible = false


func get_pandoc_download_url():
	if OS.get_name() == "Linux":
		return "https://github.com/jgm/pandoc/releases/download/%s/pandoc-%s-linux-amd64.tar.gz" % [pandoc_version, pandoc_version]

	return "https://github.com/jgm/pandoc/releases/download/%s/pandoc-%s-windows-x86_64.zip" % [pandoc_version, pandoc_version]


func get_pandoc_compressed_file_path():
	if OS.get_name() == "Linux":
		return "%s/pandoc.tar.gz" % bin_path

	return "%s/pandoc.zip" % bin_path


func get_pandoc_path():
	if OS.get_name() == "Linux":
		return "%s/pandoc-%s/bin/pandoc" % [bin_path, pandoc_version]

	# Windows
	return "%s/pandoc-%s/pandoc.exe" % [bin_path, pandoc_version]


func _on_button_process_pressed() -> void:
	var total_files := len(docx_files)

	if not FileAccess.file_exists(get_pandoc_path()) or total_files == 0:
		return

	panel_processed_files.visible = true
	label_files_processed.text = "0/%d" % total_files
	progress_bar_processed_files.value = 0

	await get_tree().create_timer(.2).timeout

	var dir = DirAccess.open(get_working_dir_path())

	if not dir.dir_exists("temp"):
		dir.make_dir("temp")
		var file = FileAccess.open("%s/.gdignore" % get_working_dir_path(), FileAccess.WRITE)
		file.close()

	# Clear converted files container
	for f in processed_files:
		if f != null:
			f.queue_free()

	processed_files.clear()
	files_processed = 0

	# Convert files
	for file in docx_files:
		if not use_threads.button_pressed:
			process_file(file, false)
			await get_tree().process_frame
			continue

		var th = Thread.new()
		active_threads.append(th)
		th.start(process_file.bind(file, use_threads.button_pressed))

	# wait for active tasks if active
	if use_threads.button_pressed:
		while files_processed < len(docx_files):
			await get_tree().process_frame


	label_files_processed.text = "%d/%d" % [total_files, total_files]
	progress_bar_processed_files.value = 100
	await get_tree().create_timer(.5).timeout
	panel_processed_files.visible = false


func process_file(docx_file_path: String, is_using_threads: bool):
	var file_name = docx_file_path.get_file()

	var file_path = docx_file_path
	var out_file = ProjectSettings.globalize_path("%s/%s" % [temp_dir_path, file_name.replace(" ", "_")])
	out_file = out_file.replace(".docx", ".html")
	var out_xml_path = out_file.replace(".html", ".xml")

	var processed_file : ICProcessedFile

	# hack to make "finally" statements
	while true:
		print("processing %s" % docx_file_path.get_file())

		var output : Array = []

		var docx_file_global_path = "%s" % file_path if OS.get_name() == "Windows" else "%s" % file_path
		var out_html_file = out_file if OS.get_name() == "Windows" else "\"%s\"" % out_file
		var out_xml_file = out_xml_path if OS.get_name() == "Windows" else "\"%s\"" % out_xml_path

		# conver docx to html & xml
		var err = OS.execute(ProjectSettings.globalize_path(get_pandoc_path()), [
			docx_file_global_path,
			"-t", "html",
			"-o", out_html_file,
			"--embed-resources",
			"--standalone"
		], output, true)

		if err != OK:
			push_error("error converting file to html \nfile: %s, \nfile_path: %s \n %s" % [file_name, docx_file_global_path, "".join(output)])
			break

		err = OS.execute(ProjectSettings.globalize_path(get_pandoc_path()), [
			docx_file_global_path,
			"-o", out_xml_file,
			"--embed-resources",
			"--standalone"
		], output, true)

		if err != OK:
			push_error("error converting file to xml %s -> %s" % [file_name, "".join(output)])
			break

		processed_file = scene_processed_file.instantiate() as ICProcessedFile
		processed_file.setup(out_file, out_xml_path)
		processed_file.validate_integrity()

		# ⚠️⚠️⚠️ prevent infinite loop ⚠️⚠️⚠️
		break

	if is_using_threads:
		call_deferred("on_finish_process_file", processed_file)
	else:
		on_finish_process_file(processed_file)

	print("💫 %s converted to html & xml" % file_name)


func on_finish_process_file(processed_file: ICProcessedFile):
	files_processed += 1
	label_files_processed.text = "%d/%d" % [files_processed, len(docx_files)]
	progress_bar_processed_files.value = (float(files_processed) / len(docx_files)) * 100

	processed_files_container.add_child(processed_file)
	processed_files.append(processed_file)


func _on_button_analize_files_pressed() -> void:
	for file in processed_files:
		file.validate_integrity()


func _on_close_requested() -> void:
	for t in active_threads:
		t.wait_to_finish()


func get_working_dir_path():
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").trim_suffix("/")

	return OS.get_executable_path().replace("/%s" % OS.get_executable_path().get_file(), "")
