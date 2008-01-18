global XFile
global appController

on posix_path()
	return my _xfile's posix_path()
end posix_path

on open_pdf()
	tell application "Adobe Acrobat 7.0 Standard"
		activate
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
	script PDFController
		property _xfile : XFile's make_with(a_file)
		property _page_count : missing value
		property _bookmark_name : missing value
	end script
end make_with