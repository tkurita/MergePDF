property _appController : missing value


on open a_list
	--log "start open"
	repeat with an_item in a_list
		if (an_item as Unicode text) ends with ":" then
			tell application "Finder"
				open an_item
			end tell
			process_location(an_item)
		end if
	end repeat
	return true
end open

on will finish launching theObject
	--log "will finish launching"
	set _appController to call method "sharedAppController" of class "AppController"
end will finish launching

on choose menu item theObject
	set can choose directories of open panel to true
	set can choose files of open panel to false
	set title of open panel to "Choose a folder containing PDF/image files"
	set a_result to display open panel
	if a_result is 0 then return
	set a_list to path names of open panel
	set an_item to item 1 of a_list
	process_location(item 1 of a_list)
end choose menu item

on process_location(a_container)
	--log "start process_location"
	call method "processFolder:" of _appController with parameter a_container
end process_location
