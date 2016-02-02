script ProgressWindowWorker
	property parent : class "NSObject"
	
	property FileSorter : module
	property XFile : module
	property loader : boot (module loader of application (get "MergePDFLib")) for me
	
	property SorterDelegate : missing value
	
	
	property _source_location_field : missing value
	

	property _pdf_sorter : missing value
	property _target_files : missing value
	property _source_location : missing value
	property _default_dest : missing value
	property _destination : missing value
	
    (* IB Outlets *)
    property _window : missing value
	property _window_controller : missing value
	property _column_direction_button : missing value
	property _row_direction_button : missing value
	property _direction_chooser_window : missing value
	property _new_file_field : missing value
    
	on import_script(a_name)
		--log "start import_script"
		set a_script to load script (path to resource a_name & ".scpt")
		return a_script
	end import_script
	
    
    on setupDefaultDestination() -- must be camelCase to call from Obj-C
        --log "start setupDefaultDestination"
  		set a_container to my _window_controller's sourceLocation() as text
		try
			set my _pdf_sorter to FileSorter's make_with_delegate(SorterDelegate's make_with(a_container))
            on error msg number 777
			activate
			display dialog msg buttons {"OK"} default button "OK" with icon note
			return false
		end try
		set target_folder to XFile's make_with(my _pdf_sorter's resolve_container())
		set source_location to target_folder's posix_path()
		my _window_controller's setSourceLocation_(source_location)
		set dest_location to target_folder's parent_folder()
		set my _default_dest to target_folder's change_path_extension("pdf")
		my _new_file_field's setStringValue_(my _default_dest's normalized_posix_path())
    end setup_default_destination
    
	on awakeFromNib()
		-- log "start awakeFromNib in ProgressWindowController"
		set SorterDelegate to import_script("SorterDelegate")
        setupDefaultDestination()
		-- log "end awakeFromNib"
	end awakeFromNib
	
	
	on set_chooser_button(a_direction)
		if a_direction is "row direction" then
			my _direction_chooser_window's makeFirstResponder_(my _row_direction_button)
		else
			my _direction_chooser_window's makeFirstResponder_(my _column_direction_button)
		end if
	end set_chooser_button
	
	on will_position_sort(a_sorter)
		--log "start will_position_sort"
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
		--log dest_file's posix_path()
		if dest_file's item_exists() then
			my _window_controller's chooseSaveLocation_(dest_file's posix_path())
			return missing value
		end if
		--log "end check_destination"
		return dest_file
	end check_destination
	
	on check_canceled()
		if not (my _window_controller's canceled() as boolean) then
			return false
		end if
		tell my _window_controller
			cancelTask()
			setProcessStarted_(false)
		end tell
		return true
	end check_canceled
	
	on merge_pdf(a_pdf_sorter)
		--log "start merge_pdf"
		tell my _window_controller
			setProcessStarted_(true)
			setCanceled_(false)
			setStatusMessage_indicatorIncrement_("Checking files",5)
		end tell
		set _target_files to a_pdf_sorter's sorted_items()
		if check_canceled() then return false
		if _target_files is {} then
			set a_folder to (a_pdf_sorter's resolve_container())
			set a_folder to POSIX path of a_folder
			my _window_controller's noPDFAlert_(a_folder)
			return false
		end if
		if check_canceled() then return false
		set target_folder to XFile's make_with(a_pdf_sorter's resolve_container())
		set _destination to check_destination(_default_dest)
		if check_canceled() then return false
		if _destination is not missing value then
			my _window_controller's processFiles_to_(_target_files, _destination's normalized_posix_path())
			set a_result to true
		else
			set a_result to false
		end if
		-- log "end merge_pdf"
		return a_result
	end merge_pdf
	
	(* actions *)
	on okButtonClicked_(sender)
		if will_position_sort(my _pdf_sorter) then
			my _window_controller's showDirectionChooser()
		else
			merge_pdf(my _pdf_sorter)
		end if
	end okButtonClicked_
	
	on coloumnDirectionClicked_(sender)
		my _window_controller's closeDirectionChooser_(me)
		_pdf_sorter's delegate()'s set_direction_for_position("column direction")
		merge_pdf(_pdf_sorter)
	end coloumnDirectionClicked_
	
	on rowDirectionClicked_(sender)
		my _window_controller's closeDirectionChooser_(me)
		_pdf_sorter's delegate()'s set_direction_for_position("row direction")
		merge_pdf(_pdf_sorter)
	end rowDirectionClicked_
	
	(* accessors *)
	
	on targetFiles()
		return my _target_files
	end targetFiles
	
end script
