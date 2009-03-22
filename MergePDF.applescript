property _appController : missing value

on launched
	--log "launched"
	--do shell script "syslog -l 5 -s 'start launched'"
	if ((count windows) < 1) then
		process_location("Insertion Location")
	end if
end launched

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


on process_location(a_container)
	--log "start process_location"
	call method "processFolder:" of _appController with parameter a_container
end process_location
