extends Node
class_name ICMain

@export var download_requements_panel : Panel
@export var btn_download_requirements : Button
@export var img_loading : TextureRect
@export var scene_processed_file : PackedScene
@export var scene_site_container : PackedScene
@export var processed_files_container : VBoxContainer
@export var files_dropped_list : ItemList
@export var label_download_progress : Label
@export var label_docx_converter : Label
@export var file_dialog : FileDialog

@export var panel_processed_files : Panel
@export var label_files_processed : Label
@export var progress_bar_processed_files : ProgressBar
@export var use_threads : CheckButton
@export var btn_export_all_sites : Button

var bin_path_format = "%s/bin"
var temp_dir_path_format = "%s/temp"

var bin_path = ""
var temp_dir_path = ""

var pandoc_version = "3.8.2"

var docx_files: PackedStringArray = []
var processed_files: Array[ICProcessedFile] = []
var files_to_export: Array[ICProcessedFile] = []
var sites_containers : Array[ICSiteContainer] = []

var active_threads : Array[Thread] = []

var files_processed: int = 0
var files_exported: int = 0

var download_running : bool = false
var last_download_result

var sites_to_export : Array[String] = []

######## DEBUG ########
const simulate_windows_on_linux: bool = false
#######################

func _ready() -> void:
	bin_path = bin_path_format % get_working_dir_path()
	temp_dir_path = temp_dir_path_format  % get_working_dir_path()

	# Clean up temp dir
	if DirAccess.dir_exists_absolute(temp_dir_path) and not OS.has_feature("editor"):
		OS.move_to_trash(temp_dir_path)

	print("bin_path -> %s" % bin_path)
	print("temp_dir_path -> %s" % temp_dir_path)

	btn_export_all_sites.visible = false
	get_window().files_dropped.connect(_on_window_files_dropped)
	_validate_requirements()


func _validate_requirements():
	img_loading.visible = false
	label_download_progress.visible = false
	var has_pandoc = FileAccess.file_exists(get_pandoc_path())
	var has_converter = FileAccess.file_exists(get_docx_to_html_converter_path())
	label_docx_converter.visible = not has_converter
	download_requements_panel.visible = not has_pandoc or not has_converter


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

	await get_tree().create_timer(.1).timeout
	await _prepare_requirements()
	btn_download_requirements.disabled = false
	img_loading.visible = false


func _prepare_requirements():
	var zip_path = get_pandoc_compressed_file_path();

	if not DirAccess.dir_exists_absolute(bin_path):
		DirAccess.make_dir_absolute(bin_path)

		var file = FileAccess.open("%s/.gdignore" % bin_path, FileAccess.WRITE)
		file.close()

	# Download pandoc
	if not FileAccess.file_exists(zip_path):
		var url = get_pandoc_download_url()
		var req = HTTPRequest.new()

		print("⚙️ Downloading Pandoc from url: %s" % url)

		req.download_file = zip_path
		add_child(req)

		download_running = true
		label_download_progress.visible = true
		req.request(url)
		req.request_completed.connect(_on_download_finish)

		while download_running:
			await get_tree().process_frame
			var progress : float = float(req.get_downloaded_bytes()) / float(req.get_body_size())
			label_download_progress.text = "%f %%" % (progress * 100)

		label_download_progress.visible = false

		if last_download_result[0] != OK:
			push_error("❌ Error trying to make the request to download pandoc, err %d" % last_download_result[0])
			return

		if last_download_result[1] != HTTPClient.RESPONSE_OK:
			push_error("❌ Error response %d" % last_download_result[1])
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

	_validate_requirements()


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


func get_docx_to_html_converter_path():
	if OS.get_name() == "Linux":
		return "%s/docx_to_html" % bin_path

	# Windows
	return "%s/docx_to_html.exe" % bin_path



func _on_button_process_pressed() -> void:
	var total_files := len(docx_files)

	if not FileAccess.file_exists(get_pandoc_path()) or total_files == 0:
		return

	btn_export_all_sites.visible = false

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

	_on_finish_process_all_files()


func process_file(docx_file_path: String, is_using_threads: bool):
	var file_name = docx_file_path.get_file()

	var file_path = docx_file_path
	var source_docx_global_path = ProjectSettings.globalize_path("%s/%s" % [temp_dir_path, file_name.replace(" ", "_")])
	var out_html_path = source_docx_global_path.replace(".docx", ".html")
	var out_xml_path = source_docx_global_path.replace(".docx", ".xml")

	var processed_file : ICProcessedFile

	# hack to make "finally" statements
	while true:
		print("processing %s" % docx_file_path.get_file())

		var output : Array = []

		var docx_file_global_path = "%s" % file_path if OS.get_name() == "Windows" else "%s" % file_path
		var out_xml_file = out_xml_path if OS.get_name() == "Windows" else "\"%s\"" % out_xml_path
		var docx_source_path = docx_file_global_path

		if simulate_windows_on_linux:
			OS.execute("winepath", ["-w", docx_source_path], output)
			docx_source_path = "".join(output).replace("\n", "")

		# conver docx to html & xml
		print("⚙️ converting %s to html" % file_name)
		var exec = get_docx_to_html_converter_path()
		var args : Array[String] = [
			docx_file_global_path,
			out_html_path
		]

		var err = OS.execute(exec, args, output, true)

		if err != OK or len(output) > 0 and (output[0] as String).contains("Error: "):
			push_error("error [%d] converting file to html \nfile: %s, \nfile_path: %s \n %s" % [err, file_name, docx_file_global_path, "".join(output)])
			print_rich("[color=red]%s[/color]" % "".join(output))
			break

		print("⚙️ converting %s to xml" % file_name)
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
		processed_file.setup(out_html_path, out_xml_path, docx_file_global_path, self)
		processed_file.validate_integrity()

		# ⚠️⚠️⚠️ prevent infinite loop ⚠️⚠️⚠️
		break

	if is_using_threads:
		call_deferred("on_finish_process_file", processed_file)
	else:
		on_finish_process_file(processed_file)

	print("💫 [%s] %s converted to html & xml" % [processed_file.site_code, file_name])


func on_finish_process_file(processed_file: ICProcessedFile):
	files_processed += 1
	label_files_processed.text = "%d/%d" % [files_processed, len(docx_files)]
	progress_bar_processed_files.value = (float(files_processed) / len(docx_files)) * 100

	processed_files_container.add_child(processed_file)
	processed_files.append(processed_file)


func _on_finish_process_all_files():
	var sites_id = []

	for site in sites_containers:
		site.queue_free()

	sites_containers = []

	# Generate sites containers
	for file in processed_files:
		if not sites_id.has(file.site_code):
			sites_id.append(file.site_code)

	for site_id in sites_id:
		var container = scene_site_container.instantiate() as ICSiteContainer
		container.title = site_id
		container.on_press_export_all.connect(_on_press_export_all)
		sites_containers.append(container)
		processed_files_container.add_child(container)

	# Order sites
	for file in processed_files:
		var container_idx = 0

		for i in len(sites_containers):
			if sites_containers[i].title == file.site_code:
				container_idx = i
				break

		file.reparent(sites_containers[container_idx].container)

	btn_export_all_sites.text = "Export all (%d) sites..." % len(sites_containers)
	btn_export_all_sites.visible = true


func _on_button_analize_files_pressed() -> void:
	for file in processed_files:
		file.validate_integrity()


func _on_button_export_all_sites_pressed() -> void:
	sites_to_export = []

	for site in sites_containers:
		sites_to_export.append(site.title)

	file_dialog.popup_centered()


func _on_press_export_all(container: ICSiteContainer):
	sites_to_export = [container.title]
	file_dialog.popup_centered()


func _export_file_sites_to_dir(dir: String):
	files_to_export = []

	for site in sites_to_export:
		for f in processed_files:
			if f.site_code == site:
				files_to_export.append(f)

	if len(sites_to_export)	> 1:
		for site in sites_containers:
			var out_dir = "%s/%s" % [dir, site.title]

			if not DirAccess.dir_exists_absolute(out_dir):
				DirAccess.make_dir_absolute(out_dir)

	files_exported = 0
	panel_processed_files.visible = true
	label_files_processed.text = "0/%d" % len(files_to_export)
	progress_bar_processed_files.value = 0

	# Convert files
	for f in files_to_export:

		var out_dir = dir

		if len(sites_to_export) > 1:
			out_dir = "%s/%s" % [out_dir, f.site_code]

		if not use_threads.button_pressed:
			f.export_fixed_docx(out_dir)
			await get_tree().process_frame
			continue

		var th = Thread.new()
		active_threads.append(th)
		th.start(f.export_fixed_docx.bind(out_dir))

	# wait for active tasks if active
	if use_threads.button_pressed:
		while files_processed < len(files_to_export):
			await get_tree().process_frame

	label_files_processed.text = "%d/%d" % [len(files_to_export), len(files_to_export)]
	progress_bar_processed_files.value = 100
	await get_tree().create_timer(.5).timeout
	panel_processed_files.visible = false

	# Open dir
	OS.shell_open(dir)


func _on_finish_export_file():
	files_exported += 1
	label_files_processed.text = "%d/%d" % [files_exported, len(files_to_export)]
	progress_bar_processed_files.value = (float(files_exported) / len(files_to_export)) * 100


func _on_close_requested() -> void:
	for t in active_threads:
		t.wait_to_finish()


func get_working_dir_path():
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").trim_suffix("/")

	return OS.get_executable_path().replace("/%s" % OS.get_executable_path().get_file(), "")


func _on_download_finish(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	download_running = false
	last_download_result = [result, response_code, headers, body]
