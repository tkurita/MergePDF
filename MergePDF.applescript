property loader : proxy_with({autocollect:true}) of application (get "MergePDFLib")

on load(a_name)
	return loader's load(a_name)
end load

property FileSorter : load("FileSorter")
property TemporaryItem : load("TemporaryItem")
property XFile : TemporaryItem's XFile
--property StringEngine : StringEngine of PathAnalyzer of XFile
property UniqueNamer : XFile's UniqueNamer
property PlainText : load("PlainText")

property appController : missing value
property UtilityHandlers : missing value
property PDFController : missing value
property DefaultsManager : missing value
property SorterDelegate : missing value
property ProgressWindowController : missing value
property MainScript : me

property _image_suffixes : {".png", ".jpg", ".jpeg", ".tiff"}
property _pdf_suffixes : {".pdf", ".ai"}
property _acrobat_version : missing value
property _pdf_sorter : missing value

property _direction_chooser_window : missing value

on import_script(a_name)
	tell main bundle
		set a_path to path for script a_name extension "scpt"
	end tell
	return load script POSIX file a_path
end import_script

on launched
	prepare_merging("Insertion Location")
end launched

on open a_list
	repeat with an_item in a_list
		if (an_item as Unicode text) ends with ":" then
			tell application "Finder"
				open an_item
			end tell
			prepare_merging(an_item)
		end if
	end repeat
	return true
end open

on will open theObject
	activate
	center theObject
	set a_direction to DefaultsManager's value_with_default("DirectionForPosition", "column direction")
	set first responder of theObject to button a_direction of theObject
end will open

on clicked theObject
	set a_name to name of theObject
	hide window of theObject
	if a_name is not "Cancel" then
		set contents of default entry "DirectionForPosition" of user defaults to a_name
		merge_pdf(_pdf_sorter)
	end if
	quit
end clicked

on will finish launching theObject
	set appController to call method "sharedAppController" of class "AppController"
	set UtilityHandlers to import_script("UtilityHandlers")
	set PDFController to import_script("PDFController")
	set DefaultsManager to import_script("DefaultsManager")
	set SorterDelegate to import_script("SorterDelegate")
	set ProgressWindowController to import_script("ProgressWindowController")
end will finish launching

on awake from nib theObject
	set a_class to class of theObject
	if a_class is in {window, panel} then
		set a_name to name of theObject
		if a_name is "DirectionChooserWindow" then
			set _direction_chooser_window to theObject
		else if a_name is "ProgressWindow" then
			ProgressWindowController's init_with_window(theObject)
		end if
	else if a_class is text field then
		set a_tag to tag of theObject
		if a_tag is 1 then
			ProgressWindowController's awake_from_nib(theObject)
			
		end if
	else
		set a_name to name of theObject
		if a_name is "ProgressIndicator" then
			ProgressWindowController's awake_from_nib(theObject)
		end if
	end if
	
end awake from nib

on will_position_sort(a_sorter)
	set a_container to a_sorter's resolve_container()
	tell application "Finder"
		set a_window to container window of a_container
		set a_view to current view of a_window
		if a_view is icon view then
			set icon_arrangement to arrangement of icon view options of a_window
			if icon_arrangement is in {not arranged, snap to grid} then
				return true
			end if
		else
			return false
		end if
	end tell
end will_position_sort

on prepare_merging(a_container)
	tell application "Adobe Acrobat Professional"
		set _acrobat_version to (version as string)
	end tell
	
	try
		set _pdf_sorter to FileSorter's make_with_delegate(SorterDelegate's make_with(a_container))
	on error msg number 777
		activate
		display dialog msg buttons {"OK"} default button "OK" with icon note
		return false
	end try
	
	if will_position_sort(_pdf_sorter) then
		show _direction_chooser_window
	else
		merge_pdf(_pdf_sorter)
		if ((count (windows whose visible is true)) is 0) then
			quit
		end if
	end if
end prepare_merging

on merge_pdf_to(dest_file, pdf_list)
	--log "start merge_pdf_to"
	call method "activateAppOfIdentifer:" of class "SmartActivate" with parameter "com.adobe.Acrobat.Pro"
	
	ProgressWindowController's update_status()
	set pdf_controllers to {}
	repeat with a_file in pdf_list
		set end of pdf_controllers to PDFController's make_with(a_file)
	end repeat
	
	pdf_controllers's item 1's open_pdf()
	tell application "Adobe Acrobat Professional"
		set a_doc to a reference to active doc
	end tell
	
	save_pdf_as(a_doc, dest_file)
	set new_doc_name to dest_file's item_name()
	
	tell application "Adobe Acrobat Professional"
		set new_doc to a reference to active doc
		set total_pages to count every page of new_doc
	end tell
	
	--make Bookmark for first page
	add_bookmark(new_doc, pdf_controllers's item 1's bookmark_name(), 1)
	ProgressWindowController's update_status()
	--insert every pages
	repeat with a_pdf_controller in (rest of pdf_controllers)
		my insert_pages_at_end(new_doc, a_pdf_controller)
		
		--make bookmark
		add_bookmark(new_doc, a_pdf_controller's bookmark_name(), total_pages + 1)
		set total_pages to total_pages + (a_pdf_controller's page_count())
		
	end repeat
	
	tell application "Adobe Acrobat Professional"
		create thumbs new_doc
		
		set view mode of new_doc to pages and bookmarks
		save new_doc
	end tell
	
	call method "activateAppOfIdentifer:" of class "SmartActivate" with parameter "com.apple.finder"
	tell application "Finder"
		reveal (dest_file's as_alias())
	end tell
	TemporaryItem's clear()
	beep
	--log "end merge_pdf_to"
	return true
end merge_pdf_to

on merge_pdf(a_pdf_sorter)
	--log "start merge_pdf"
	ProgressWindowController's show_window()
	set pdf_list to a_pdf_sorter's sorted_items()
	if pdf_list is {} then
		set a_folder to (a_pdf_sorter's resolve_container())
		set a_folder to POSIX path of a_folder
		--set no_found_msg to localized string "notFoundPDFs"
		ProgressWindowController's close_window()
		--display alert no_found_msg message (UtilityHandlers's localized_string("Location :", {a_folder}))
		call method "noPDFAlert:" of appController with parameter a_folder
		return false
	end if
	
	set target_folder to XFile's make_with(a_pdf_sorter's resolve_container())
	set dest_location to target_folder's parent_folder()
	set dest_file to target_folder's change_path_extension(".pdf")
	set dest_file to check_destination(dest_file)
	if dest_file is not missing value then
		ProgressWindowController's set_new_file_path(dest_file's posix_path())
		set a_result to merge_pdf_to(dest_file, pdf_list)
	else
		set a_result to false
	end if
	ProgressWindowController's close_window()
	--log "end merge_pdf"
	return a_result
end merge_pdf

on is_file_busy(a_path)
	set is_busy to busy status of (info for (alias a_path))
	if not is_busy then
		try
			set theResult to do shell script "lsof -F c " & quoted form of POSIX path of a_path
			--set processName to text 2 thru -1 of paragraph 2 of theResult
			set is_busy to true
		end try
	end if
	return is_busy
end is_file_busy

(*!= close_in_acrobat
Acrobat で開かれているファイルを閉じる。

== Result
とにかくファイルを閉じることに成功したら ture。
Acrobat で開いているファイルが見つからなかったり、起動していないときは false。
*)
on close_in_acrobat(a_path)
	set a_result to false
	tell application "Adobe Acrobat Professional"
		repeat with ith from 1 to count documents
			set an_alias to file alias of document ith
			if (an_alias as Unicode text is a_path) then
				close document ith saving "No"
				set a_result to true
				exit repeat
			end if
		end repeat
	end tell
	return a_result
end close_in_acrobat

on check_destination(dest_file)
	--log "start check_destination"
	if dest_file's item_exists() then
		activate
		set a_msg to localized string "chooseNewLocationMessage"
		try
			set new_file to (choose file name default name (dest_file's item_name()) with prompt a_msg & " :" default location (dest_file's parent_folder()'s as_alias()))
			--log (newdest_file as Unicode text)
		on error msg number errnum
			set dest_file to missing value
			if errnum is not -128 then
				error msg number errnum
			end if
			return dest_file
		end try
		
		set new_file to XFile's make_with(new_file)
		if new_file's item_exists() then
			set a_path to new_file's hfs_path()
			if is_file_busy(a_path) then
				if not close_in_acrobat(a_path) then
					try
						display dialog (UtilityHandler's localized_string("fileIsBusyMessage", {a_path}) & (localized string "changeNewLocationMessage"))
						set new_file to check_destination(new_file)
					on error
						set new_file to missing value
					end try
				end if
			end if
		end if
		set dest_file to new_file
	end if
	--log "end check_destination"
	return dest_file
end check_destination

on save_pdf_as(a_doc, dest_file)
	--log "start save_pdf_as"
	tell application "Adobe Acrobat Professional"
		save a_doc to file (dest_file's hfs_path()) -- conveting into unicode text is required
	end tell
end save_pdf_as

on insert_pages_at_end(a_doc, a_pdf_controller)
	set a_pdf_path to quoted form of (a_pdf_controller's posix_path())
	--set a_pdf_path to StringEngine's plain_text(a_pdf_path)
	set a_pdf_path to PlainText's do(a_pdf_path)
	set end_page to (a_pdf_controller's page_count()) - 1
	set a_command to "var lastPage = this.numPages-1;this.insertPages(lastPage," & a_pdf_path & ",0," & end_page & ");"
	--log a_command
	tell application "Adobe Acrobat Professional"
		tell a_doc
			do script a_command
		end tell
	end tell
end insert_pages_at_end

on add_bookmark(a_doc, a_bookmark_name, dest_page)
	set a_bookmark_name to do shell script "echo '" & a_bookmark_name & "'|iconv -f UTF-8 -t UTF-16"
	tell application "Adobe Acrobat Professional"
		tell a_doc
			make new PDBookmark at end
			tell PDBookmark -1
				set name to a_bookmark_name
				set destination page number to dest_page
			end tell
		end tell
	end tell
end add_bookmark





