--libraryies
property LibraryFolder : "Macintosh HD:Users:tkurita:Factories:Script factory:ProjectsX:MergePDF:Library Scripts:"
property FileSorter : load script file (LibraryFolder & "FileSorter")
property PathAnalyzer : load script file (LibraryFolder & "PathAnalyzer")
property StyleStripper : load script file (LibraryFolder & "StyleStripper")
property UniqueNamer : load script file (LibraryFolder & "UniqueNamer")

--property imageSuffixList : {".png"}
property imageSuffixList : {}
property suffixList : {".pdf", ".ai"} & imageSuffixList
property acrobatVersion : missing value

property dQ : ASCII character 34

property thePDFsorter : missing value

on newPDFsorter(theContainer)
	script PDFSorter
		property parent : FileSorter
		property directionForPosition : missing value
		
		on getTargetItems()
			set thelist to list folder my targetContainer without invisibles
			set itemList to {}
			set containerPath to my targetContainer as Unicode text
			repeat with ith from 1 to length of thelist
				set theName to item ith of thelist
				repeat with theSuffix in suffixList
					if theName ends with theSuffix then
						set end of itemList to (containerPath & theName) as alias
						exit repeat
					end if
				end repeat
			end repeat
			return itemList
		end getTargetItems
		
		on getContainer()
			if theContainer is "Insertion Location" then
				return continue getContainer()
			else
				return theContainer
			end if
		end getContainer
		
		on sortDirectionOfIconView()
			return directionForPosition
		end sortDirectionOfIconView
		
		on isPositionSort()
			set targetContainer to getContainer()
			tell application "Finder"
				set theWindow to container window of targetContainer
				set theView to current view of theWindow
				
				if theView is icon view then
					set theArrangement to arrangement of icon view options of theWindow
					if theArrangement is in {not arranged, snap to grid} then
						return true
					end if
				else
					return false
				end if
			end tell
		end isPositionSort
	end script
	
	return PDFSorter
	
end newPDFsorter

on launched
	
	prepareMerging("Insertion Location")
end launched

on open thelist
	
	repeat with theItem in thelist
		if (theItem as Unicode text) ends with ":" then
			tell application "Finder"
				open theItem
			end tell
			prepareMerging(theItem)
		end if
	end repeat
	return true
end open

on readDefaultValue(entryName, defaultValue)
	tell user defaults
		if exists default entry entryName then
			return contents of default entry entryName
		else
			make new default entry at end of default entries with properties {name:entryName, contents:defaultValue}
			return defaultValue
		end if
	end tell
end readDefaultValue

on will open theObject
	activate
	center theObject
	set directionForPosition to readDefaultValue("DirectionForPosition", "column direction")
	set first responder of theObject to button directionForPosition of theObject
end will open

on clicked theObject
	set theName to name of theObject
	hide window of theObject
	if theName is not "Cancel" then
		set directionForPosition of thePDFsorter to theName
		set contents of default entry "DirectionForPosition" of user defaults to theName
		mergePDF()
	end if
	quit
end clicked

on newPDFObj for theFile given closedoc:closeFlag
	local theFileName
	local theFile
	local theBookmarkName
	
	set theFileName to getName(theFile)
	set theFile to (theFile as alias)
	
	set theBookmarkName to removeSuffix(theFileName)
	
	if theFileName ends with ".pdf" then
		tell application "Adobe Acrobat 7.0 Standard"
			activate
			open theFile
			set theNPages to count every page of document -1
			if closeFlag then
				close document -1
			end if
		end tell
		set singlePageFlag to false
	else
		set theNPages to 1
		set singlePageFlag to true
	end if
	
	set thePDFName to theFileName
	
	repeat with theSuffix in imageSuffixList
		if theFileName ends with theSuffix then
			set thePDFName to theBookmarkName & ".pdf"
			exit repeat
		end if
	end repeat
	
	script PDFToAddObj
		property name : theFileName
		property isSinglePage : singlePageFlag
		property pdfName : thePDFName
		property fileAlias : theFile
		property bookmarkName : theBookmarkName
		property nPages : theNPages
		
		on openPDF()
			tell application "Adobe Acrobat 7.0 Standard"
				activate
				open fileAlias
			end tell
		end openPDF
	end script
	
	return PDFToAddObj
end newPDFObj

on prepareMerging(theContainer)
	try
		set thePDFsorter to newPDFsorter(theContainer)
	on error errMsg number 777
		activate
		display dialog errMsg buttons {"OK"} default button "OK" with icon note
		return false
	end try
	if isPositionSort() of thePDFsorter then
		show window "directionChooser"
	else
		mergePDF()
		quit
	end if
end prepareMerging

on mergePDF()
	local pdfObjList
	set pdfList to item 1 of sortByView() of thePDFsorter
	if pdfList is {} then
		set theFolder to (targetContainer of thePDFsorter) as Unicode text
		set notFoundPDFs to localized string "notFoundPDFs"
		display dialog notFoundPDFs & return & theFolder buttons {"OK"} default button "OK"
		return false
	end if
	
	set pathRecord to do(targetContainer of thePDFsorter) of PathAnalyzer
	
	set theName to (name of pathRecord) & ".pdf"
	set destinationFile to (((folderReference of pathRecord) as Unicode text) & theName)
	set destinationFile to checkDestinationFile(destinationFile, theName)
	
	tell application "Adobe Acrobat 7.0 Standard"
		set acrobatVersion to (version as string)
		activate
	end tell
	
	---build pdfobj List
	set pdfObjList to {}
	repeat with i from 2 to (length of pdfList)
		-- get porperties of pdf document to add
		set end of pdfObjList to newPDFObj of me for item i of pdfList with closedoc
	end repeat
	
	--save first pdf file as new pdf document
	--set beginning of pdfObjList to newPDFObj of me for item 1 of pdfList without closedoc
	set firstPDFObj to newPDFObj of me for item 1 of pdfList without closedoc
	set firstItemName to pdfName of firstPDFObj
	if isSinglePage of firstPDFObj then
		openPDF() of firstPDFObj
		tell application "Adobe Acrobat 7.0 Standard"
			set theDoc to a reference to document 1
		end tell
	else
		tell application "Adobe Acrobat 7.0 Standard"
			set theDoc to a reference to document firstItemName
		end tell
	end if
	savePDFAs(theDoc, destinationFile)
	--	tell application "Adobe Acrobat 7.0 Standard"
	--		set theName to name of theDoc
	--	end tell
	--	log theName
	--build infomation for new pdf file
	set newPDFPathRecord to (do(destinationFile as alias) of PathAnalyzer)
	set newPDF to itemReference of newPDFPathRecord
	set newDocName to name of newPDFPathRecord
	
	tell application "Adobe Acrobat 7.0 Standard"
		set newDoc to a reference to document newDocName
		set totalPages to count every page of newDoc
	end tell
	
	--make Bookmark for first page	
	--set thePDFName to my getName(item 1 of pdfList)
	--set theBookmarkName to my removeSuffix(thePDFName)
	set theBookmarkName to bookmarkName of firstPDFObj
	
	(*
	tell application "Adobe Acrobat 7.0 Standard"
		set nBookmarks to count every bookmark of newDoc
	end tell
	
	if nBookmarks > 1 then
		addBookmarkToThePageAtLast(newDoc, theBookmarkName, 0)
	else
		addBookmarkToThePageAtFirst(newDoc, theBookmarkName, 0)
	end if
	*)
	AddBookmark(newDoc, theBookmarkName, 1)
	
	--insert every pages
	repeat with i from 1 to (length of pdfObjList)
		-- get porperties of pdf document to add
		set thePDFToAddObj to item i of pdfObjList
		
		--insert pdf document
		my insertPagesToLast(newDoc, thePDFToAddObj)
		
		--make bookmark
		--addBookmarkToThePageAtLast(newDoc, bookmarkName of thePDFToAddObj, totalPages)
		AddBookmark(newDoc, bookmarkName of thePDFToAddObj, totalPages + 1)
		set totalPages to totalPages + (nPages of thePDFToAddObj)
		
	end repeat
	
	tell application "Adobe Acrobat 7.0 Standard"
		create thumbs newDoc
		
		set view mode of newDoc to pages and bookmarks
		--display dialog (finder location of (basic info for newPDF)) as string
		save newDoc
	end tell
	--display dialog (finder location of (basic info for newPDF)) as string
	
	tell application "Finder"
		activate
		reveal newPDF
	end tell
	
	beep
end mergePDF


on removeSuffix(theString)
	repeat with theSuffix in suffixList
		if theString ends with theSuffix then
			return text 1 thru -((length of theSuffix) + 1) of theString
		end if
	end repeat
	
	return theString
end removeSuffix

on getName(theItem)
	tell application "Finder"
		return name of theItem as Unicode text
	end tell
end getName

on checkDestinationFile(destinationFile, theName)
	--log "start checkDestinationFile"
	if isExists(destinationFile) then
		activate
		set chooseNewLocationMessage to localized string "chooseNewLocationMessage"
		try
			--set newDestinationFile to (choose file name default name theName with prompt chooseNewLocationMessage & " :") as file specification
			set newDestinationFile to (choose file name default name theName with prompt chooseNewLocationMessage & " :")
			--log (newDestinationFile as Unicode text)
		on error errMsg number errNum
			quit
			error errMsg number errNum
		end try
		set newDestinationFile to newDestinationFile as Unicode text
		
		if (newDestinationFile as Unicode text) is (destinationFile) then
			set isBusy to busy status of (info for (alias destinationFile))
			if isBusy then
				set dot to localized string "dot"
				set isBusyMessage to localized string "isBusyMessage"
				display dialog dQ & destinationFile & dQ & space & isBusyMessage & return & chooseNewLocationMessage & dot with icon note
				set destinationFile to checkDestinationFile(destinationFile, theName)
			end if
		else
			set destinationFile to newDestinationFile
		end if
	end if
	--log "end checkDestinationFile"
	return destinationFile
end checkDestinationFile

on isExists(thePath)
	try
		thePath as alias
		return true
	on error
		return false
	end try
end isExists

--Javascript wrapper functions
on jsStringFilter(theString)
	set sqFlag to "'" is in theString
	set dqFlag to dQ is in theString
	
	if sqFlag and dqFlag then
		display dialog "There are invalid charactes in" & return & dQ & "theString" & dQ & "." buttons {"OK"} default button "OK" with icon stop
		error number -128
	else if sqFlag then
		set jQuote to dQ
	else
		set jQuote to "'"
	end if
	
	return (jQuote & theString & jQuote)
end jsStringFilter

on savePDFAs(theDoc, theDistinationFile)
	log "start savePDFAs"
	log theDistinationFile
	local thePDFPath
	
	-- can't accept long file name
	tell application "Adobe Acrobat 7.0 Standard"
		save theDoc to file (theDistinationFile as Unicode text) -- conveting into unicode text is required
		--save theDoc to (theDistinationFile as Unicode text)
	end tell
	
	(*	
	--japanese file name are chenged into invalid code
	jsStringFilter(theDistinationFile)
	set thePDFPath to POSIX path of theDistinationFile as Unicode text
	set thePDFPath to jsStringFilter(thePDFPath)
	set thePDFPath to getPlainText of StyleStripper from thePDFPath
	
	tell application "Adobe Acrobat 7.0 Standard"
		tell theDoc
			do script "this.saveAs(" & thePDFPath & ");"
		end tell
	end tell
*)
	
end savePDFAs

on insertPagesToLast(theDoc, thePDFToAddObj)
	local theFile
	local endPage
	local thePDFPath
	
	set thePDFPath to quoted form of POSIX path of fileAlias of thePDFToAddObj as Unicode text
	--log thePDFPath
	set thePDFPath to getPlainText of StyleStripper from thePDFPath
	--log thePDFPath
	set endPage to (nPages of thePDFToAddObj) - 1
	set insertCommand to "var lastPage = this.numPages-1;this.insertPages(lastPage," & thePDFPath & ",0," & endPage & ");"
	--log insertCommand
	tell application "Adobe Acrobat 7.0 Standard"
		tell theDoc
			do script insertCommand
		end tell
	end tell
end insertPagesToLast

on AddBookmark(theDoc, theBookmarkName, destinationPage)
	(*
	TECConvertText theBookmarkName fromCode "macintosh" toCode "UNICODE-1-1"
	--TECConvertText theBookmarkName fromCode "X-MAC-JAPANESE" toCode "UNICODE-1-1"
	set theBookmarkName to ("β„‘β€χο‹Ώ" & the result)
	*)
	set theBookmarkName to do shell script "echo '" & theBookmarkName & "'|iconv -f UTF-8 -t UTF-16"
	tell application "Adobe Acrobat 7.0 Standard"
		tell theDoc
			make new PDBookmark at end
			tell PDBookmark -1
				set name to theBookmarkName
				set destination page number to destinationPage
			end tell
		end tell
	end tell
end AddBookmark

on addBookmarkToThePageAtLast(theDoc, theBookmarkName, destinationPage)
	set theBookmarkName to (my jsStringFilter(theBookmarkName)) as Unicode text
	set theBookmarkName to getPlainText of StyleStripper from theBookmarkName
	set theJS to "bookmarkRoot.createChild(" & theBookmarkName & ", 'this.pageNum=" & destinationPage & "',bookmarkRoot.children.length)"
	--set theJS to "bookmarkRoot.createChild(" & theBookmarkName & ", null,bookmarkRoot.children.length)"
	tell application "Adobe Acrobat 7.0 Standard"
		tell theDoc
			do script theJS
		end tell
	end tell
end addBookmarkToThePageAtLast

on addBookmarkToThePageAtFirst(theDoc, theBookmarkName, destinationPage)
	set theBookmarkName to (my jsStringFilter(theBookmarkName)) as Unicode text
	set theBookmarkName to getPlainText of StyleStripper from theBookmarkName
	set theJS to "bookmarkRoot.createChild(" & theBookmarkName & ", 'this.pageNum=" & destinationPage & "')"
	
	tell application "Adobe Acrobat 7.0 Standard"
		tell theDoc
			do script theJS
		end tell
	end tell
end addBookmarkToThePageAtFirst


on addBookmarkToLastAtLast(theDoc, theBookmarkName)
	set theBookmarkName to (my jsStringFilter(theBookmarkName)) as Unicode text
	set theBookmarkName to getPlainText of StyleStripper from theBookmarkName
	set theJS to "var lastPage = this.numPages-1;bookmarkRoot.createChild(" & theBookmarkName & ", 'this.pageNum='+lastPage,bookmarkRoot.children.length);"
	
	tell application "Adobe Acrobat 7.0 Standard"
		tell theDoc
			do script theJS
		end tell
	end tell
end addBookmarkToLastAtLast
