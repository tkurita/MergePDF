property _window : missing value
property _status_message_field : missing value
property _progress_indicator : missing value
property _source_location_path_field : missing value
property _new_file_path_field : missing value

property _progress_reports : missing value

on init_with_window(a_window)
	--log "start init_with_window"
	set floating of a_window to true
	set hides when deactivated of a_window to false
	set _window to a_window
	tell user defaults
		set _progress_reports to contents of default entry "ProgressMessages"
	end tell
	set a_result to call method "setFrameUsingName:" of a_window with parameter (name of a_window)
	if a_result is not 1 then
		center a_window
	end if
	--log "end init_with_window"
end init_with_window

on update_status()
	set an_item to first item of _progress_reports
	tell _progress_indicator to increment by |levelIncrement| of an_item
	set content of _status_message_field to (status of an_item)
	set _progress_reports to rest of _progress_reports
end update_status

on awake_from_nib(an_object)
	set a_name to name of an_object
	--log a_name
	if a_name is "StatusMessageField" then
		set _status_message_field to an_object
	else if a_name is "SourceLocationPathField" then
		set _source_location_path_field to an_object
	else if a_name is "NewFilePathField" then
		set _new_file_path_field to an_object
	else if a_name is "ProgressIndicator" then
		set _progress_indicator to an_object
	end if
	--log "end awake_from_nib"
end awake_from_nib

on set_source_location(a_path)
	set content of _source_location_path_field to a_path
end set_source_location

on set_new_file_path(a_path)
	set content of _new_file_path_field to a_path
end set_new_file_path

on show_window()
	--log "show_window"
	show _window
	--animate _progress_indicator
end show_window

on close_window()
	call method "saveFrameUsingName:" of _window with parameter (name of _window)
	hide _window
end close_window