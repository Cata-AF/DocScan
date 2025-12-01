extends FoldableContainer
class_name ICProcessedFile

@export var btn_view : Button
@export var text_edit_commentaries : TextEdit

var preview_file_path: String
var file_xml_path: String
var file_name : String = ""
var docx_file_path: String = ""
var site_code: String = ""
var operator_code: String = ""
var duid: String = ""
var has_image_issues: bool = false
var broken_images_count: int = 0
var missing_images_count: int = 0

const SITES_DUID_CSV_PATH := "res://bin/SITES_DUID.csv"
static var _site_duid_map: Dictionary = {}
static var _site_duid_map_loaded: bool = false

const TOTAL_NBR_OF_APP = "Total Nbr. of Application (FTP UL) Success"
const SITE_CODE_PATTERN = "[A-Z]{1,5}\\d{3,5}"

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

var main: ICMain;
var commentaries: Array[String] = []

signal on_finish_export

func setup(preview_html_path: String, doc_xml_path: String, word_file_path: String, m: ICMain):
	main = m
	file_name = preview_html_path.get_file();
	preview_file_path = preview_html_path
	docx_file_path = word_file_path
	file_xml_path = doc_xml_path
	title = file_name
	site_code = get_site_code_from_filename(word_file_path.get_file())
	operator_code = get_operator_from_filename(file_name)
	duid = get_duid_for_site(site_code)


func validate_integrity():
	# Extract site code if not already set
	if site_code.is_empty():
		site_code = get_site_code_from_filename(docx_file_path.get_file())
	if operator_code.is_empty():
		operator_code = get_operator_from_filename(docx_file_path.get_file())
	if duid.is_empty():
		duid = get_duid_for_site(site_code)

	if get_file_type() == "LTE":
		commentaries = validate_integrity_lte()
	else:
		commentaries = validate_integrity_umts()

	set_commentaries(commentaries)
	broken_images_count = verify_broken_images()
	missing_images_count = summarize_media_counts_by_category()
	has_image_issues = broken_images_count > 0 or missing_images_count > 0
	_update_issue_visuals()

func get_node_deepest_content(xml_node: XMLNode) -> String:
	if len(xml_node.children) > 0:
		return get_node_deepest_content(xml_node.children[0])

	return xml_node.content


func get_site_code_from_filename(n: String) -> String:
	if get_file_type() == "LTE":
		return n.split("LTE")[1].strip_edges().split(" ")[0]

	# UMTS
	return n.split("UMTS")[1].strip_edges().split(" ")[0]


func get_operator_from_filename(n: String) -> String:
	if n.get_file().contains("TEF"):
		return "TEF"
	if n.get_file().contains("TIGO"):
		return "TIGO"
	else:
		return "UNKNOWN"


func get_duid_for_site(site: String) -> String:
	if site.is_empty():
		return ""

	if not _site_duid_map_loaded:
		_load_site_duid_map()

	var key = site.strip_edges().to_upper()
	if _site_duid_map.has(key):
		return str(_site_duid_map[key])
	return ""


func _load_site_duid_map():
	_site_duid_map_loaded = true

	var file = FileAccess.open(SITES_DUID_CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("SITES_DUID.csv not found; DUIDs will be empty")
		return

	while not file.eof_reached():
		var line = file.get_line()
		if line.is_empty():
			continue

		var cols = line.split(";")
		if cols.size() < 2:
			cols = line.split(",")
			if cols.size() < 2:
				continue

		var site = cols[0].replace("\"", "").strip_edges().to_upper()
		var duid_value = cols[1].replace("\"", "").strip_edges()

		if site.is_empty() or duid_value.is_empty():
			continue
		# saltar encabezado
		if site.to_lower().contains("codigo") and duid_value.to_lower().contains("duid"):
			continue

		_site_duid_map[site] = duid_value

	file.close()


func validate_integrity_lte() -> Array[String]:

	var parser : XMLDocument = XML.parse_file(file_xml_path)
	var blocks_xml: XMLNode = parser.root.get_child_by_name("blocks")
	var tables_xml: Array[XMLNode] = blocks_xml.get_children_by_name("Table")

	commentaries = []

	var remaining_low_cluster_avg = 0
	var remaining_high_cluster_avg = 0

	var cluster_values_found = 0

	var last_band = ""
	var intra_freq_found = false
	var volte_call_drop_reported := {}


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
				if row_value == "0":
					commentaries.append("The statics in %s there is no throughput because there was no UL carrier establishment." % last_band)
				elif row_value.is_empty():
					commentaries.append("No information was made or found of statics in %s." % last_band)

			if row_title == CLUSTER_RSRP_AVERAGE:
				if cluster_values_found >= 4: # all values were found
					continue

				if row_value.is_empty():
					commentaries.append("No information was made or found of RSRP in %s." % last_band)
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

				commentaries.append("In %s the RSRP average has %s" % [last_band, label])

			if row_title == CLUSTER_SINR_AVERAGE:
				if row_value.is_empty():
					commentaries.append("No information was made or found of SINR in %s." % last_band)
					continue

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

				commentaries.append("In %s the SINR average has %s" % [last_band, label])

			if row_title == VOLTE_CALL_DROP:
				if last_band.is_empty():
					continue

				if volte_call_drop_reported.has(last_band):
					continue

				var value_text = row_value.replace("%", "")
				if value_text.is_empty():
					commentaries.append("No information was made or found of VoLTE Call Drop in %s." % last_band)
				elif value_text.is_valid_float():
					var value = value_text.to_float()

					if value > 0:
						commentaries.append("In %s present Voice call drop event" % last_band)

					volte_call_drop_reported[last_band] = true

			if row_title == INFRAFREQ_HO:
				if intra_freq_found:
					continue

				var value_text = row_value.replace("%", "")
				if value_text.is_empty():
					commentaries.append("No information was made or found of IntraFreq HO in %s." % last_band)
				elif value_text.is_valid_float():
					intra_freq_found = true
					var value = value_text.to_float()

					if value < 100:
						commentaries.append("In %s present LTE Handover fail event" % last_band)

	return commentaries


func validate_integrity_umts()  -> Array[String]:
	var parser : XMLDocument = XML.parse_file(file_xml_path)
	var blocks_xml: XMLNode = parser.root.get_child_by_name("blocks")
	var tables_xml: Array[XMLNode] = blocks_xml.get_children_by_name("Table")

	commentaries = []

	var found_rscp_avg: bool = false
	var found_ecio_avg: bool = false
	var found_sc_wdma_call_drop: bool = false
	var found_sc_sho_success_rate: bool = false
	var found_sho_success_rate: bool = false

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

			if row_title == RSCP_AVG && !found_rscp_avg:
				var value_text = row_value.replace("%", "")
				found_rscp_avg = true
				if value_text.is_empty():
					commentaries.append("No information was made or found of RSCP.")
				elif value_text.is_valid_float():
					var value = value_text.to_float()
					var label = ""

					if value < -98:
						label = "bad levels"
					elif value >= -98 && value < -85:
						label = "regular levels"
					else:
						label = "good levels"

					commentaries.append("The RSCP average has %s." % label)

			if row_title == ECIO_AVG && !found_ecio_avg:
				var value_text = row_value.replace("%", "")
				found_ecio_avg = true
				if value_text.is_empty():
					commentaries.append("No information was made or found of Ec/Io.")
				elif value_text.is_valid_float():
					var value = value_text.to_float()
					var label = ""

					if value < -14:
						label = "bad levels"
					elif value >= -14 && value < -12:
						label = "normal levels"
					else:
						label = "good levels"

					commentaries.append("The Ec/Io average has %s." % label)

			if row_title == SC_WCDMA_CALL_DROP_RATE && !found_sc_wdma_call_drop:
				var value_text = row_value.replace("%", "")
				found_sc_wdma_call_drop = true
				if value_text.is_empty():
					commentaries.append("No information was made or found of WCDMA call dropped in CS Test")
				elif value_text.is_valid_float():
					var value = value_text.to_float()

					if value > 0:
						commentaries.append("WCDMA call dropped event ocurred in CS Intermediate Call Test.")

			if row_title == SC_SHO_SUCCESS_RATE and not found_sc_sho_success_rate:
				found_sc_sho_success_rate = true
				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					var value = value_text.to_float()

					if value < 100:
						commentaries.append("WCDMA soft handover fail event ocurred in CS Intermediate Call Test.")
				else:
					if value_text.is_empty():
						commentaries.append("No information was made or found of WCDMA SHO in CS Test.")
					else:
						commentaries.append("No valid SC SHO Success Rate value was found.")

			if row_title == SHO_SUCCESS_RATE and not found_sho_success_rate:
				found_sho_success_rate = true

				var value_text = row_value.replace("%", "")
				if value_text.is_valid_float():
					var value = value_text.to_float()

					if value < 100:
						commentaries.append("WCDMA soft handover fail event ocurred in PS Test.")
				else:
					if value_text.is_empty():
						commentaries.append("No information was made or found of WCDMA SHO in PS Test")
	return commentaries


func set_commentaries(comments: Array[String]):
	var missing_info: Array[String] = []
	var normal_comments: Array[String] = []

	for commentary in comments:
		if commentary.begins_with("No information was made or found"):
			missing_info.append(commentary)
		else:
			normal_comments.append(commentary)

	text_edit_commentaries.text = ""

	for i in len(normal_comments):
		var commentary = normal_comments[i]
		text_edit_commentaries.text += commentary

		if i + 1 < len(normal_comments):
			text_edit_commentaries.text += "\n"

	if missing_info.size() > 0:
		if text_edit_commentaries.text.length() > 0:
			text_edit_commentaries.text += "\n\n"
		text_edit_commentaries.text += "NO INFORMATION FOUND\n"
		for i in len(missing_info):
			text_edit_commentaries.text += missing_info[i]
			if i + 1 < len(missing_info):
				text_edit_commentaries.text += "\n"

	# Set commentaries in the html
	const comment_integrity_checked = "Integrity Check Comments"
	var file_data = FileAccess.get_file_as_string(preview_file_path)
	var rx_added_comments = RegEx.create_from_string(comment_integrity_checked)

	# Update header paragraphs before injecting comments
	if get_file_type() == "LTE":
		file_data = apply_lte_paragraph_overrides(file_data)
	else:
		file_data = apply_umts_paragraph_overrides(file_data)
	file_data = apply_title_override(file_data)

	if rx_added_comments.search(file_data) != null:
		file_data = _update_duid_in_existing_comments(file_data)
		var file_existing = FileAccess.open(preview_file_path, FileAccess.WRITE)
		file_existing.store_string(file_data)
		file_existing.close()
		return

	# Update html to add the comments
	var table_html = "<table style=\"border:1px solid black;\">\n"
	table_html += "<tr>\n"
	table_html += "	<th style=\"border:1px solid black; background-color: #ffff00; width: 103px; font-size: 10.5pt; font-weight: bold; text-align: center;\">Site Name</th>\n"
	table_html += "	<th style=\"border:1px solid black; background-color: #ffff00; width: 270px; font-size: 10.5pt; font-weight: bold; text-align: center;\">DUID</th>\n"
	table_html += "</tr>\n"

	table_html += "<tr>\n"
	table_html += "	<td style=\"border:1px solid black; font-size: 10.5pt; text-align: left;\">&nbsp;&nbsp;%s</td>\n" % site_code
	table_html += "	<td style=\"border:1px solid black; font-size: 10.5pt; text-align: left;\">%s</td>\n" % duid
	table_html += "</tr>\n"
	table_html += "</table>\n"

	table_html += "<br/>\n"

	var new_html = "<span style=\"font-size: 12pt; font-weight: bold;\">Site List:</span>\n %s <span style=\"font-size: 12pt; font-weight: bold;\">RF conditions analysis, suggestions and comments:</span>\n" % table_html

	for c in normal_comments:
		new_html += "<p style=\"font-size: 10.5pt;\">-&nbsp;&nbsp;&nbsp;&nbsp; %s</p>\n" % c

	new_html += "</body>"

	file_data += "\n%s" % new_html

	var file = FileAccess.open(preview_file_path, FileAccess.WRITE)
	file.store_string(file_data)
	file.close()


func apply_lte_paragraph_overrides(file_data: String) -> String:
	var rx_p7 = RegEx.create_from_string("<p class=\"paragraph-P7\">.*?</p>")
	var matches = rx_p7.search_all(file_data)

	if matches.size() < 3:
		return file_data

	# Already processed
	if matches[1].get_string(0).find("[CONTRACT NUMBER]") != -1:
		return file_data

	var base_style = "color: #666699; font-family: Arial; font-size: 11pt; font-style: italic; font-weight: bold;"
	var contract_p = "<p class=\"paragraph-P7\" style=\"%s\">[CONTRACT NUMBER]</p>" % base_style
	var id_p = "<p class=\"paragraph-P7\" style=\"%s\">[0001702410300A]</p>" % base_style

	var site_text = site_code
	if site_text.is_empty():
		site_text = "[SITE]"
	elif operator_code.is_empty():
		site_text = "[%s]" % site_code
	else:
		site_text = "[%s %s]" % [site_code, operator_code]

	var site_p = "<p class=\"paragraph-P7\" style=\"%s\">%s</p>" % [base_style, site_text]

	var rebuilt = ""
	var last_index = 0

	for i in len(matches):
		var m = matches[i]
		var start = m.get_start()
		var end = m.get_end()

		rebuilt += file_data.substr(last_index, start - last_index)

		if i == 1:
			rebuilt += contract_p
		elif i == 2:
			rebuilt += id_p
			rebuilt += site_p
		else:
			rebuilt += m.get_string(0)

		last_index = end

	rebuilt += file_data.substr(last_index)

	return rebuilt


func apply_umts_paragraph_overrides(file_data: String) -> String:
	var rx_p8 = RegEx.create_from_string("<p class=\"paragraph-P8\">.*?</p>")
	var rx_p9 = RegEx.create_from_string("<p class=\"paragraph-P9\">.*?</p>")

	var first_p8 = rx_p8.search(file_data)
	if first_p8 == null:
		return file_data

	var next_p9 = rx_p9.search(file_data, first_p8.get_end())
	if next_p9 == null:
		return file_data

	if next_p9.get_string(0).find("[CONTRACT NUMBER]") != -1:
		return file_data

	var base_style = "color: #666699; font-family: Arial; font-size: 11pt; font-style: italic; font-weight: bold;"
	var contract_p = "<p class=\"paragraph-P9\" style=\"%s\">[CONTRACT NUMBER]</p>" % base_style
	var id_p = "<p class=\"paragraph-P9\" style=\"%s\">[0001702410300A]</p>" % base_style

	var start = next_p9.get_start()
	var end = next_p9.get_end()

	return file_data.substr(0, start) + contract_p + id_p + file_data.substr(end)


func apply_title_override(file_data: String) -> String:
	var rx_title = RegEx.create_from_string("<title\\s+xml:lang=\"en-US\">.*?</title>")
	var title_match = rx_title.search(file_data)
	if title_match == null:
		return file_data

	var title_text = build_title_text()
	var replacement = "<title xml:lang=\"en-US\">%s</title>" % title_text

	return file_data.substr(0, title_match.get_start()) + replacement + file_data.substr(title_match.get_end())


func build_title_text() -> String:
	var parts: Array[String] = []

	if site_code.is_empty():
		parts.append("[SITE]")
	else:
		parts.append(site_code)

	var doc_type = get_file_type()
	if doc_type.length() > 0:
		parts.append(doc_type)
	else:
		parts.append("[TYPE]")

	if operator_code.is_empty():
		parts.append("[OPERATOR]")
	else:
		parts.append(operator_code)

	return " ".join(parts)


func _update_duid_in_existing_comments(file_data: String) -> String:
	if duid.is_empty():
		return file_data

	var rx_duid_cell = RegEx.create_from_string("(<th[^>]*>DUID</th>\\s*</tr>\\s*<tr>\\s*<td[^>]*>[^<]*</td>\\s*<td[^>]*>)([^<]*)(</td>)")
	var match = rx_duid_cell.search(file_data)

	if match == null:
		return file_data

	var rebuilt = file_data.substr(0, match.get_start())
	rebuilt += match.get_string(1)
	rebuilt += duid
	rebuilt += match.get_string(3)
	rebuilt += file_data.substr(match.get_end())
	return rebuilt


func _update_issue_visuals():
	self_modulate = Color(1, 0.6, 0.6) if has_image_issues else Color(1, 1, 1)


func verify_broken_images() -> int:
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

		if matches.size() > 8:	# possible broken image
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

	return broken_images


func summarize_media_counts_by_category() -> int:
	var file = FileAccess.open(preview_file_path, FileAccess.READ)
	if file == null:
		return 0

	var sections: Array[Dictionary] = []
	var valid_main_categories = [
		"LTE PS Test High Band",
		"LTE PS Test Low Band",
		"LTE VoLTE Intermediate Call Test High Band",
		"LTE VoLTE Intermediate Call Test Low Band",
		"UMTS Intermediate Call Test",
		"UMTS FTP Test"
	]

	var current_main: String = ""
	var current_title = ""
	var img_count = 0
	var figure_count = 0
	var table_count = 0
	var started = false

	var building_h1 : bool = false
	var building_h2 : bool = false
	var missing_count: int = 0

	while !file.eof_reached():
		var line = file.get_line()

		if line.contains("<h1>"):

			if len(current_main) > 0 and len(current_title) > 0:
				sections.append({
					"main": current_main,
					"title": current_title,
					"imgs": img_count,
					"figures": figure_count,
					"tables": table_count
				})

				img_count = 0
				figure_count = 0
				table_count = 0

			current_main = ""
			building_h1 = true
			continue
		elif line.contains("</h1>"):
			building_h1 = false
			continue

		if line.contains("<h2>"):

			if len(current_main) > 0 and len(current_title) > 0:
				sections.append({
					"main": current_main,
					"title": current_title,
					"imgs": img_count,
					"figures": figure_count,
					"tables": table_count
				})

				img_count = 0
				figure_count = 0
				table_count = 0

			current_title = ""
			building_h2 = true
			started = false
			continue
		elif line.contains("</h2>"):
			if len(current_main) > 0 and len(current_title) > 0:
				started = true
			building_h2 = false
			continue


		if building_h1:
			if line.contains("<"): # It's a tag, skip
				continue

			var is_valid: bool = false

			for category in valid_main_categories:
				if line.contains(category):
					is_valid = true
					break

			if is_valid:
				current_main = line


		if building_h2:
			if line.contains("<"): # It's a tag, skip
				continue

			current_title = line
			continue


		if started:
			# count img_titles an images
			img_count += line.count("<img")
			table_count += line.to_lower().count("<table")

			if line.contains("Serving PCI"):
				if not line.contains("Chart:"):
					figure_count += line.count(" Figure ")
			else:
				figure_count += line.count(" Figure ")


	file.close()

	if sections.size() == 0:
		return 0

	# Set results
	var last_category: String = ""

	text_edit_commentaries.text += "\n\n##### MISSING IMAGES #####\n"

	for section in sections:
		if last_category != section.main:
			last_category = section.main
			text_edit_commentaries.text += "\n--------- %s ---------\n" % last_category.replace("-", " ").to_upper()

		var abnormal_missing = 0
		if section.main == "UMTS FTP Test" and section.title.to_lower().contains("abnormal events"):
			var expected_imgs = 2
			abnormal_missing = expected_imgs - section.imgs
			if abnormal_missing > 0:
				text_edit_commentaries.text += "%s: %d\n" % [section.title, abnormal_missing,]
				missing_count += abnormal_missing

		var diff = section.figures - (section.imgs + section.tables)

		# skip
		if diff == 0:
			continue

		if diff < 0:
			push_warning("Media count mismatch in section \"%s\", figures: %d, imgs: %d, tables: %d, file: %s" % [section["title"], section.figures, section.imgs, section.tables, file_name])
			continue

		text_edit_commentaries.text += "%s: %d\n" % [section.title, diff]
		missing_count += diff

	return missing_count


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


func export_fixed_docx(export_dir: String = "") -> void:
	# Extract file
	var exec = "powershell.exe"

	if ICMain.simulate_windows_on_linux:
		exec = "pwsh" # powershell for linux

	var out_dir = "%s/%s" % [main.temp_dir_path, docx_file_path.get_file().replace(".docx", "")]

	var output = []
	var command = (
		"Remove-Item -Path '%s' -Recurse -Force -ErrorAction Ignore;" % out_dir
		+ "Add-Type -AssemblyName System.IO.Compression.FileSystem;"
		+ "[System.IO.Compression.ZipFile]::ExtractToDirectory('%s', '%s')" % [docx_file_path, out_dir]
	)
	var args = [
		"-Command",
		command
	]

	var err = OS.execute(exec, args, output, true)

	if err != OK:
		push_error("error extracting file: %d, details: %s" % [err, "".join(output)])
		return

	# Fix file
	var document_xml_path = "%s/word/document.xml" % out_dir
	var parser : XMLDocument = XML.parse_file(document_xml_path)
	var document: XMLNode = parser.root.children[0]

	# Add header stuff
	var contract_number_node = XML.parse_str(ICFormats.header_title % "[CONTRACT NUMBER]").root
	var contract_id_node = XML.parse_str(ICFormats.header_title % "[0001702410300A]").root
	var site_id_node = XML.parse_str(ICFormats.header_title % ["[%s %s]" % [site_code, operator_code]]).root

	document.children.insert(5, contract_number_node)
	document.children.insert(6, contract_id_node)

	if get_file_type() == "LTE":
		document.children.insert(7, site_id_node)

	# Add footer table
	var table_title = XML.parse_str(ICFormats.bold_text_format % "Site List:").root
	var table_node = XML.parse_str(ICFormats.table_site_list_format % [site_code, duid]).root
	document.children.append(table_title)
	document.children.append(table_node)

	var jump_line = XML.parse_str(ICFormats.line_entry % " ").root
	document.children.append(jump_line)

	# Add commentaries
	var commentaries_title = XML.parse_str(ICFormats.bold_text_format % "RF conditions analysis, suggestions and comments:").root
	document.children.append(commentaries_title)

	for c in commentaries:
		if c.contains("No information was made or found"):
			continue

		var commentary_node = XML.parse_str(ICFormats.line_entry % ["- %s" % c]).root
		document.children.append(commentary_node)

	# fix empty data
	var data = parser.root.dump_str(true, 0, 0).replace("[ ]", "")

	# Save file
	var file = FileAccess.open(document_xml_path, FileAccess.WRITE)
	file.store_string(data)
	file.close()

	# Repack docx
	var out_fixed_dir = docx_file_path.replace(docx_file_path.get_file(), "")
	var out_fixed_file_name = docx_file_path.get_file().replace(".docx", "_fixed.docx")

	if len(export_dir) > 0:
		out_fixed_dir = export_dir
		out_fixed_file_name = docx_file_path.get_file()

	var out_fixed_path = "%s/%s" % [out_fixed_dir, out_fixed_file_name]

	output = []
	command = "Remove-Item '%s' -ErrorAction Ignore;" % out_fixed_path \
		+ "Add-Type -AssemblyName System.IO.Compression.FileSystem;"  \
		+ "[System.IO.Compression.ZipFile]::CreateFromDirectory('%s', '%s')" % [out_dir, out_fixed_path]
	args = [
		"-Command",
		command
	]

	err = OS.execute(exec, args, output, true)

	if err != OK:
		push_error("error packing file: %d, details: %s" % [err, "".join(output)])
		return

	print("✅ %s fixed" % docx_file_path.get_file())
	call_deferred("finished_export_file")


func finished_export_file():
	on_finish_export.emit()
