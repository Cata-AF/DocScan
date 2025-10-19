extends FoldableContainer
class_name ICProcessedFile

@export var btn_view : Button
@export var text_edit_commentaries : TextEdit

var preview_file_path: String
var file_xml_path: String
var file_name : String = ""

const TOTAL_NBR_OF_APP = "Total Nbr. of Application (FTP UL) Success"

# LTE
const CLUSTER_RSRP_AVERAGE = "CLUSTER RSRP Average"
const CLUSTER_SINR_AVERAGE = "CLUSTER SINR Average All(dB)"
const VOLTE_CALL_DROP = "VoLTE Call Drop Rate(%)"
const INFRAFREQ_HO = "IntraFreq HO Success Rate(%)"

# UMTS
const RSCP_AVG = "RSCP avg"
const ECIO_AVG = "EcIo avg"
const SC_WCDMA_CALL_DROP_RATE = "SC WCDMA Call Drop Rate(%)"
const SC_SHO_SUCCESS_RATE = "SC SHO Success Rate(%)"
const SHO_SUCCESS_RATE = "SHO Success Rate(%)"

const LOW_BAND = "Low Band"
const HIGH_BAND = "High Band"

const LOW_BAND_CLUSTER_AVERAGE = "INTERMEDIATE CALL TEST Drive Test Low Band"
const HIGH_BAND_CLUSTER_AVERAGE = "INTERMEDIATE CALL TEST Drive Test High Band"


func setup(preview_html_path: String, doc_xml_path):
	file_name = preview_html_path.get_file();
	preview_file_path = preview_html_path
	file_xml_path = doc_xml_path
	title = file_name


func validate_integrity():

	var commentaries: Array[String] = []

	if get_file_type() == "LTE":
		commentaries = validate_integrity_lte()
	else:
		commentaries = validate_integrity_umts()

	set_commentaries(commentaries)
	verify_broken_images()

func get_node_deepest_content(xml_node: XMLNode) -> String:
	if len(xml_node.children) > 0:
		return get_node_deepest_content(xml_node.children[0])

	return xml_node.content


func validate_integrity_lte() -> Array[String]:

	var parser : XMLDocument = XML.parse_file(file_xml_path)
	var blocks_xml: XMLNode = parser.root.get_child_by_name("blocks")
	var tables_xml: Array[XMLNode] = blocks_xml.get_children_by_name("Table")

	var commentaries: Array[String] = []

	var remaining_low_cluster_avg = 0
	var remaining_high_cluster_avg = 0

	var cluster_values_found = 0

	var last_band = ""
	var intra_freq_found = false

	for i in len(tables_xml):
		var table : XMLNode = tables_xml[i]
		var table_body: XMLNode = table.get_child_by_name("TableBody").get_child_by_name("body")

		for r in len(table_body.children):
			var row : XMLNode = table_body.children[r]

			var row_title = get_node_deepest_content(row.children[0])
			var row_value = get_node_deepest_content(row.children[1])

			#print("%s = %s" % [row_title, row_value])
			# Bands detection
			if row_title.contains(LOW_BAND) || row_value.contains(LOW_BAND):
				last_band = "Low Band"

			if row_title.contains(HIGH_BAND) || row_value.contains(HIGH_BAND):
				last_band = "High Band"

			if row_title.contains(LOW_BAND_CLUSTER_AVERAGE):
				remaining_low_cluster_avg = 2

			if row_title.contains(HIGH_BAND_CLUSTER_AVERAGE):
				remaining_high_cluster_avg = 2

			# Real LTE conditions
			if row_title == TOTAL_NBR_OF_APP:
				if len(row_value) == 0 or row_value == "0":
					commentaries.append("[%s:Statics] No information was made or found." % last_band)

			if row_title == CLUSTER_RSRP_AVERAGE:
				if cluster_values_found >= 4: # all values were found
					continue

				var value: float = row_value.to_float()
				var label: String = ""

				if value < -105:
					label = "low levels"
				elif value >= -105 and value < 100:
					label = "regular levels"
				else:
					label = "good levels"

				if remaining_low_cluster_avg > 0:
					remaining_low_cluster_avg -= 1
					cluster_values_found += 1

				if remaining_high_cluster_avg > 0:
					remaining_high_cluster_avg -= 1
					cluster_values_found += 1

				commentaries.append("[%s:%s] se encuentra en: %s" % [last_band, CLUSTER_RSRP_AVERAGE, label])

			if row_title == CLUSTER_SINR_AVERAGE:
				var value: float = row_value.to_float()
				var label: String = ""

				if value < 0:
					label = "low levels"
				elif value >= 0 and value < 10:
					label = "normal levels"
				else:
					label = "good levels"

				if remaining_low_cluster_avg > 0:
					remaining_low_cluster_avg -= 1
					cluster_values_found += 1

				if remaining_high_cluster_avg > 0:
					remaining_high_cluster_avg -= 1
					cluster_values_found += 1

				commentaries.append("[%s:%s] se encuentra en: %s" % [last_band, CLUSTER_SINR_AVERAGE, label])

			if row_title == VOLTE_CALL_DROP:
				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					var value = value_text.to_float()

					if value > 0:
						commentaries.append("[%s:VOLTE_CALL_DROP_RATE] Voice call drop event ocurred" % last_band)

			if row_title == INFRAFREQ_HO:
				if intra_freq_found:
					continue

				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					intra_freq_found = true
					var value = value_text.to_float()

					if value < 100:
						commentaries.append("[%s:INTRA_FREQ_HO] LTE Handover fail" % last_band)

	return commentaries


func validate_integrity_umts()  -> Array[String]:
	var parser : XMLDocument = XML.parse_file(file_xml_path)
	var blocks_xml: XMLNode = parser.root.get_child_by_name("blocks")
	var tables_xml: Array[XMLNode] = blocks_xml.get_children_by_name("Table")

	var commentaries: Array[String] = []

	var found_rscp_avg: bool = false
	var found_ecio_avg: bool = false
	var found_sc_wdma_call_drop: bool = false

	for i in len(tables_xml):
		var table : XMLNode = tables_xml[i]
		var table_body: XMLNode = table.get_child_by_name("TableBody").get_child_by_name("body")

		for r in len(table_body.children):
			var row : XMLNode = table_body.children[r]

			if len(row.children) < 2:
				continue

			var row_title = get_node_deepest_content(row.children[0])
			var row_value = get_node_deepest_content(row.children[1])

			#print("%s = %s" % [row_title, row_value])

			# Real LTE conditions
			if row_title == TOTAL_NBR_OF_APP:
				if len(row_value) == 0 or row_value == "0":
					commentaries.append("[Statics] No information was made or found.")

			if row_title == RSCP_AVG && !found_rscp_avg:
				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					found_rscp_avg = true

					var value = value_text.to_float()
					var label = ""

					if value < -98:
						label = "bad levels"
					elif value >= -98 && value < -85:
						label = "regular levels"
					else:
						label = "good levels"

					commentaries.append("[%s] %s." % [RSCP_AVG, label])

			if row_title == ECIO_AVG && !found_ecio_avg:
				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					found_ecio_avg = true

					var value = value_text.to_float()
					var label = ""

					if value < -14:
						label = "bad levels"
					elif value >= -14 && value < -12:
						label = "normal levels"
					else:
						label = "good levels"

					commentaries.append("[%s] %s." % [ECIO_AVG, label])

			if row_title == SC_WCDMA_CALL_DROP_RATE && !found_sc_wdma_call_drop:
				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					found_sc_wdma_call_drop = true
					var value = value_text.to_float()

					if value > 0:
						commentaries.append("[%s] WCDMA call dropped event ocurred. (%s%%)" % [SC_WCDMA_CALL_DROP_RATE, value_text])

			if row_title == SC_SHO_SUCCESS_RATE:
				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					var value = value_text.to_float()

					if value < 100:
						commentaries.append("[%s] WCDMA call dropped event ocurred. (%s%%)" % [SC_SHO_SUCCESS_RATE, value_text])

			if row_title == SHO_SUCCESS_RATE:
				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					var value = value_text.to_float()

					if value < 100:
						commentaries.append("[%s] WCDMA call dropped event ocurred. (%s%%)" % [SHO_SUCCESS_RATE, value_text])

	return commentaries


func set_commentaries(commentaries: Array[String]):
	#print("-------------commentaries")
	text_edit_commentaries.text = ""
	for i in len(commentaries):
		var commentary = commentaries[i]
		#print("    %s" % commentary)
		text_edit_commentaries.text += commentary

		if i + 1 < len(commentaries):
			text_edit_commentaries.text += "\n"

	# Set commentaries in the html
	const comment_integrity_checked = "Integrity Check Comments"
	var file_data = FileAccess.get_file_as_string(preview_file_path)
	var rx_added_comments = RegEx.create_from_string(comment_integrity_checked)

	if rx_added_comments.search(file_data) != null:
		return

	# Update html to add the comments
	var new_html = "<h2>Integrity Check Comments</h2>\n"

	for c in commentaries:
		new_html += "<p>- %s</p>\n" % c

	new_html += "</body>"

	file_data = file_data.replace("</body>", new_html)

	var file = FileAccess.open(preview_file_path, FileAccess.WRITE)
	file.store_string(file_data)
	file.close()


func verify_broken_images():
	var url_broken_img = "https://placehold.co/472x302/red/white"
	var rx_imgs = RegEx.create_from_string("<img\\b[^>]*?src=[\"']([^\"']+)[\"'][^>]*?>")
	var rx_imgs_broken_fallback = RegEx.create_from_string(url_broken_img)
	var rx_broken_pattern = RegEx.create_from_string("kAIECAAIGFgMAuVG0SIECAQF5AYPM")

	var file_data = FileAccess.get_file_as_string(preview_file_path)

	var results = rx_imgs.search_all(file_data)
	var broken_images : int = 0

	for img in results:
		var tag = img.get_string(0)
		var src = img.get_string(1)
		var matches := rx_broken_pattern.search_all(src)

		if matches.size() > 10:	# possible broken image
			broken_images += 1
			var src_replaced = tag.replace(src, url_broken_img)
			file_data = file_data.replace(tag, src_replaced)


	# Check if was already checked
	if broken_images == 0:
		broken_images = rx_imgs_broken_fallback.search_all(file_data).size()

	if broken_images > 0:
		text_edit_commentaries.text = "broken images: %d\n%s" % [broken_images, text_edit_commentaries.text]
		var file = FileAccess.open(preview_file_path, FileAccess.WRITE)
		file.store_string(file_data)
		file.close()


func get_file_type() -> String:
	if file_name.to_lower().contains("lte"):
		return "LTE"
	elif file_name.to_lower().contains("umts"):
		return "UMTS"
	else:
		push_error("file type for \"%s\" not found" % file_name)
		return ""


func _on_button_open_in_browser_pressed() -> void:
	OS.shell_open(preview_file_path)
