global XFile
global appController
global TemporaryItem
global MainScript

on posix_path()
	return my _xfile's posix_path()
end posix_path

on open_pdf()
	call method "activateAppOfIdentifer:" of class "SmartActivate" with parameter "com.adobe.Acrobat"
	tell application "Adobe Acrobat 7.0 Standard"
		open my _xfile's as_alias()
	end tell
end open_pdf

on page_count()
	if my _page_count is not missing value then
		return my _page_count
	end if
	
	set my _page_count to call method "countPDFPages:" of appController with parameter (my _xfile's posix_path())
	return my _page_count
end page_count

on is_single()
	return (page_count() is 1)
end is_single

on bookmark_name()
	if my _bookmark_name is not missing value then
		return my _bookmark_name
	end if
	set my _bookmark_name to my _xfile's basename()
	return my _bookmark_name
end bookmark_name

on make_with(a_file)
	set a_xfile to XFile's make_with(a_file)
	set a_bookmark_name to a_xfile's basename()
	set a_page_count to missing value
	if MainScript's is_image(info for a_file) then
		set tmp_file to TemporaryItem's make_with(a_xfile's change_path_extension(".pdf")'s item_name())
		set a_page_count to call method "convertImage:toPDF:" of appController with parameters {a_xfile's posix_path(), tmp_file's posix_path()}
		if a_page_count is 0 then
			error "Failt to convert " & quoted form of (tmp_file's posix_path()) & " into a PDF."
		end if
		set a_xfile to tmp_file
	end if
	
	script PDFController
		property _xfile : a_xfile
		property _page_count : a_page_count
		property _bookmark_name : a_bookmark_name
	end script
end make_with