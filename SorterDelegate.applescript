--global ProgressWindowController

on is_pdf(info_record)
	--log "start is_pdf"
	if file type of info_record is "PDF " then
		return true
	else if type identifier of info_record is "com.adobe.pdf" then
		return true
	else if name extension of info_record is "pdf" then
		return true
	end if
	return false
end is_pdf

on is_image(info_record)
	--log "start is_image"
	return type identifier of info_record is in {"public.jpeg", "public.png", "public.tiff", "com.apple.pict", "com.microsoft.bmp"}
end is_image

on resolve_container()
	if my _target_container is "Insertion Location" then
		error number -1708 -- continue FileSorter's resolve_container()
	else
		return POSIX file (my _target_container)
	end if
end resolve_container

on resolve_info(an_alias)
	set info_rec to info for an_alias
	if (folder of info_rec) then
		set info_rec to missing value
	else
		if alias of info_rec then
			tell application "Finder"
				set an_original to original item of an_alias as alias
			end tell
			set info_rec to resolve_info(an_original)
		end if
	end if
	return info_rec
end resolve_info

on target_items_at(a_location)
	--log "start target_items_at of SorterDelegate"
	--ProgressWindowController's set_source_location(POSIX path of a_location)
	--ProgressWindowController's update_status()
	tell application "Finder"
		set a_list to every item of a_location
	end tell
	set pdf_list to {}
	repeat with an_item in a_list
		set an_alias to an_item as alias
		set info_rec to resolve_info(an_alias)
		if info_rec is not missing value then
			if is_pdf(info_rec) or is_image(info_rec) then
				set end of pdf_list to an_alias
			end if
		end if
	end repeat
	--log "end target_items_at of SorterDelegate"
	--ProgressWindowController's update_status()
	return pdf_list
end target_items_at

on set_direction_for_position(a_direction)
	set my _direction_for_position to a_direction
end set_direction_for_position

on is_rowwise_for_iconview(view_options)
	--set a_direction to contents of default entry "DirectionForPosition" of user defaults
	return my _direction_for_position is "row direction"
end is_rowwise_for_iconview

on make_with(a_container)
	script SorterDelegate
		property _target_container : a_container
		property _direction_for_position : missing value
	end script
	
	return SorterDelegate
end make_with