property FileSorter : module
property XFile : module
property loader : boot (module loader of application (get "MergePDFLib")) for me

property SorterDelegate : missing value

property _window : missing value
property _source_location_field : missing value
property _new_file_field : missing value
property _direction_chooser_window : missing value
property _row_direction_button : missing value
property _column_direction_button : missing value

property _window_controller : missing value
property _pdf_sorter : missing value
property _target_files : missing value
property _source_location : missing value
property _destination : missing value

on import_script(a_name)
	tell main bundle
		set a_path to path for script a_name extension "scpt"
	end tell
	return load script POSIX file a_path
end import_script

on update_status()
	call method "updateStatus" of my _window_controller
end update_status

on awake from nib theObject
	set a_name to name of theObject
	if a_name is "ProgressWindow" then
		set my _window to theObject
		set my _window_controller to call method "delegate" of theObject
	else if a_name is "SourceLocationField" then
		set my _source_location_field to theObject
	else if a_name is "NewFileField" then
		set my _new_file_field to theObject
	else if a_name is "DirectionChooserWindow" then
		set my _direction_chooser_window to theObject
	else if a_name is "row direction" then
		set my _row_direction_button to theObject
	else if a_name is "column direction " then
		set my _column_direction_button to theObject
	end if
end awake from nib

on will open theObject
	set a_name to name of theObject
	if a_name is "ProgressWindow" then
		set SorterDelegate to import_script("SorterDelegate")
	end if
end will open

on set_chooser_button(a_direction)
	if a_direction is "row direction" then
		set first responder of my _direction_chooser_window to my _row_direction_button
	else
		set first responder of my _direction_chooser_window to my _column_direction_button
	end if
end set_chooser_button

on will_position_sort(a_sorter)
	set a_container to a_sorter's resolve_container()
	tell application "Finder"
		set a_window to container window of a_container
		set a_view to current view of a_window
		if a_view is icon view then
			set viewopt to icon view options of a_window
			set icon_arrangement to arrangement of viewopt
			if icon_arrangement is in {not arranged, snap to grid} then
				set label_position to label position of viewopt
				if label_position is bottom then
					my set_chooser_button("row direction")
				else
					my set_chooser_button("column direction")
				end if
				return true
			end if
			return false
		else
			return false
		end if
	end tell
end will_position_sort

on check_destination(dest_file)
	--log "start check_destination"
	if dest_file's item_exists() then
		display save panel attached to my _window in directory (dest_file's parent_folder()'s as_alias()) with file name (dest_file's item_name())
		return missing value
	end if
	--log "end check_destination"
	return dest_file
end check_destination

on check_canceled()
	set cancel_status to call method "canceled" of my _window_controller
	if cancel_status is 0 then return false
	
	call method "cancelTask" of my _window_controller
	call method "setProcessStarted:" of my _window_controller with parameter 0
	return true
end check_canceled

on merge_pdf(a_pdf_sorter)
	--log "start merge_pdf"
	call method "setProcessStarted:" of my _window_controller with parameter 1
	call method "setCanceled:" of my _window_controller with parameter 0
	call method "updateStatus" of my _window_controller -- Checking files
	set _target_files to a_pdf_sorter's sorted_items()
	if check_canceled() then return false
	if _target_files is {} then
		set a_folder to (a_pdf_sorter's resolve_container())
		set a_folder to POSIX path of a_folder
		call method "noPDFAlert:" of my _window_controller with parameter a_folder
		return false
	end if
	if check_canceled() then return false
	set target_folder to XFile's make_with(a_pdf_sorter's resolve_container())
	set _destination to check_destination(_destination)
	if check_canceled() then return false
	if _destination is not missing value then
		call method "processFiles:to:" of my _window_controller with parameters {_target_files, _destination's posix_path()}
		set a_result to true
	else
		set a_result to false
	end if
	--log "end merge_pdf"
	return a_result
end merge_pdf

on opened theObject
	set a_container to call method "sourceLocation" of my _window_controller
	try
		set my _pdf_sorter to FileSorter's make_with_delegate(SorterDelegate's make_with(a_container))
	on error msg number 777
		activate
		display dialog msg buttons {"OK"} default button "OK" with icon note
		return false
	end try
	set target_folder to XFile's make_with(my _pdf_sorter's resolve_container())
	set source_location to target_folder's posix_path()
	set string value of my _source_location_field to source_location
	call method "setSourceLocation:" of my _window_controller with parameter source_location
	set dest_location to target_folder's parent_folder()
	set my _destination to target_folder's change_path_extension("pdf")
	set string value of my _new_file_field to _destination's normalized_posix_path()
end opened

on panel ended theObject with result withResult
	if withResult is 1 then
		set dest_path to path name of save panel
		call method "processFiles:to:" of my _window_controller with parameters {_target_files, dest_path}
	else
		call method "cancelAction:" of my _window_controller with parameter my _window_controller
		check_canceled()
	end if
end panel ended

on clicked theObject
	set a_name to name of theObject
	if a_name is "OKButton" then
		if will_position_sort(my _pdf_sorter) then
			call method "showDirectionChooser" of my _window_controller
		else
			merge_pdf(_pdf_sorter)
		end if
	else if a_name is in {"column direction", "row direction"} then
		call method "closeDirectionChooser" of my _window_controller
		_pdf_sorter's delegate()'s set_direction_for_position(a_name)
		merge_pdf(_pdf_sorter)
	else if a_name is "Cancel" then
		call method "closeDirectionChooser" of my _window_controller
	end if
end clicked
