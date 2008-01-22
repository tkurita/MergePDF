property loader : proxy_with({autocollect:true}) of application (get "MergePDFLib")

on load(a_name)
	return loader's load(a_name)
end load

property FileSorter : load("FileSorter")
property TemporaryItem : load("TemporaryItem")
property XFile : TemporaryItem's XFile
property StringEngine : StringEngine of PathAnalyzer of XFile
property UniqueNamer : XFile's UniqueNamer


property appController : missing value
property UtilityHandlers : missing value
property PDFController : missing value
property MainScript : me

--property image_pdf_suffixes : {".png"}
property _image_suffixes : {".png", ".jpg", ".jpeg", ".tiff"}
property _pdf_suffixes : {".pdf", ".ai"}
property _acrobat_version : missing value

property a_pdf_sorter : missing value

on import_script(a_name)
	tell main bundle
		set a_path to path for script a_name extension "scpt"
	end tell
	return load script POSIX file a_path
end import_script

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

on make_pdf_sorter(a_container)
	script SorterHelper
		on resolve_container()
			if a_container is "Insertion Location" then
				error number -1708 -- continue FileSorter's resolve_container()
			else
				return a_container
			end if
		end resolve_container
		
		on target_items_at(a_location)
			--log "start target_items_at of SortHelper"
			tell application "Finder"
				set a_list to every file of a_location
			end tell
			set pdf_list to {}
			repeat with an_item in a_list
				set an_alias to an_item as alias
				set info_rec to info for an_alias
				if is_pdf(info_rec) or is_image(info_rec) then
					set end of pdf_list to an_alias
				end if
			end repeat
			--log "end target_items_at of SortHelper"
			return pdf_list
		end target_items_at
		
	end script
	
	return FileSorter's make_with_delegate(SorterHelper)
end make_pdf_sorter

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


on will open theObject -- deprecated
	activate
	center theObject
	(*
	set directionForPosition to readDefaultValue("DirectionForPosition", "column direction")
	set first responder of theObject to button directionForPosition of theObject
	*)
end will open

on clicked theObject
	set a_name to name of theObject
	hide window of theObject
	if a_name is not "Cancel" then
		set directionForPosition of a_pdf_sorter to a_name
		set contents of default entry "DirectionForPosition" of user defaults to a_name
		merge_pdf()
	end if
	quit
end clicked

on will finish launching theObject
	set appController to call method "sharedAppController" of class "AppController"
	set UtilityHandlers to import_script("UtilityHandlers")
	set PDFController to import_script("PDFController")
end will finish launching

on prepare_merging(theContainer)
	tell application "Adobe Acrobat 7.0 Standard"
		set _acrobat_version to (version as string)
	end tell
	
	try
		set a_pdf_sorter to make_pdf_sorter(theContainer)
	on error errMsg number 777
		activate
		display dialog errMsg buttons {"OK"} default button "OK" with icon note
		return false
	end try
	merge_pdf(a_pdf_sorter)
	if ((count (windows whose visible is true)) is 0) then
		quit
	end if
end prepare_merging

on merge_pdf_to(dest_file, pdf_list)
	--log "start merge_pdf_to"
	call method "activateAppOfIdentifer:" of class "SmartActivate" with parameter "com.adobe.Acrobat"
	
	set pdf_controllers to {}
	repeat with a_file in pdf_list
		set end of pdf_controllers to PDFController's make_with(a_file)
	end repeat
	
	pdf_controllers's item 1's open_pdf()
	tell application "Adobe Acrobat 7.0 Standard"
		set a_doc to a reference to active doc
	end tell
	
	save_pdf_as(a_doc, dest_file)
	set new_doc_name to dest_file's item_name()
	
	tell application "Adobe Acrobat 7.0 Standard"
		set new_doc to a reference to active doc
		set total_pages to count every page of new_doc
	end tell
	
	--make Bookmark for first page
	add_bookmark(new_doc, pdf_controllers's item 1's bookmark_name(), 1)
	
	--insert every pages
	repeat with a_pdf_controller in (rest of pdf_controllers)
		my insert_pages_at_end(new_doc, a_pdf_controller)
		
		--make bookmark
		add_bookmark(new_doc, a_pdf_controller's bookmark_name(), total_pages + 1)
		set total_pages to total_pages + (a_pdf_controller's page_count())
		
	end repeat
	
	tell application "Adobe Acrobat 7.0 Standard"
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
	set pdf_list to a_pdf_sorter's sorted_items()
	if pdf_list is {} then
		set a_folder to (a_pdf_sorter's resolve_container()) as Unicode text
		set no_found_msg to localized string "notFoundPDFs"
		display alert no_found_msg message (UtilityHandlers's localized_string("Location :", {a_folder}))
		return false
	end if
	
	set target_folder to XFile's make_with(a_pdf_sorter's resolve_container())
	set dest_location to target_folder's parent_folder()
	set dest_file to target_folder's change_path_extension(".pdf")
	set dest_file to check_destination(dest_file)
	if dest_file is not missing value then
		set a_result to merge_pdf_to(dest_file, pdf_list)
	else
		set a_result to false
	end if
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
	tell application "Adobe Acrobat 7.0 Standard"
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
			error msg number errnum
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
	--log dest_file
	local thePDFPath
	
	-- can't accept long file name
	tell application "Adobe Acrobat 7.0 Standard"
		save a_doc to file (dest_file's hfs_path()) -- conveting into unicode text is required
	end tell
	
end save_pdf_as

on insert_pages_at_end(a_doc, a_pdf_controller)
	set a_pdf_path to quoted form of (a_pdf_controller's posix_path())
	--log a_pdf_path
	set a_pdf_path to StringEngine's plain_text(a_pdf_path)
	--log a_pdf_path
	set end_page to (a_pdf_controller's page_count()) - 1
	set a_command to "var lastPage = this.numPages-1;this.insertPages(lastPage," & a_pdf_path & ",0," & end_page & ");"
	--log a_command
	tell application "Adobe Acrobat 7.0 Standard"
		tell a_doc
			do script a_command
		end tell
	end tell
end insert_pages_at_end

on add_bookmark(a_doc, a_bookmark_name, dest_page)
	set a_bookmark_name to do shell script "echo '" & a_bookmark_name & "'|iconv -f UTF-8 -t UTF-16"
	tell application "Adobe Acrobat 7.0 Standard"
		tell a_doc
			make new PDBookmark at end
			tell PDBookmark -1
				set name to a_bookmark_name
				set destination page number to dest_page
			end tell
		end tell
	end tell
end add_bookmark






