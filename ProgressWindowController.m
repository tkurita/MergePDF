#import "ProgressWindowController.h"
#import "DropBox.h"

#define useLog 0

@implementation ProgressWindowController


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_sourceLocation release];
	[_frameName release];
	[super dealloc];
}

- (IBAction)closeDirectionChooser:(id)sender
{
	[NSApp endSheet:directionChooserWindow];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (void)showDirectionChooser
{
	[NSApp beginSheet:directionChooserWindow modalForWindow:self.window
			modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}

- (IBAction)cancelAction:(id)sender
{
	if (_processStarted) {
#if useLog		
		NSLog(@"cancel merge processor");
#endif
		if (_mergeProcessor) {
			self.mergeProcessor.canceled = YES;
			self.canceled = YES;
		} else {
			self.canceled = YES;
		}
	} else {
		[self close];
	}
}

- (void)markProcessStarted
{
	self.processStarted = YES;
}

- (void)processFiles:(NSArray *)array to:(NSString *)destination
{
	[newFileField setStringValue:destination];
	self.mergeProcessor = [[PDFMerger new] autorelease];
	NSNotificationCenter *noticenter = [NSNotificationCenter defaultCenter];
	[noticenter addObserver:self selector:@selector(updateProgressMessage:) 
					   name:@"UpdateProgressMessage" object:_mergeProcessor];
	[noticenter addObserver:self selector:@selector(appendErrorMessage:)
					   name:@"AppendErrorMessage" object:_mergeProcessor];
	self.mergeProcessor.targetFiles = array;
	self.mergeProcessor.destination = destination;
	[NSThread detachNewThreadSelector:@selector(start:) toTarget:_mergeProcessor withObject:self];
}

- (double)currentProgressValue
{
	return [progressIndicator doubleValue];
}

- (BOOL)alertShowHelp:(NSAlert *)alert {
	[NSApp showHelp:self];
	return YES;
}

- (void) noPDFAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[self close];
}

- (void)noPDFAlert:(NSString *)aPath
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"notFoundPDFs",nil)
									 defaultButton:@"OK"
								   alternateButton:nil
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Location :",@""), aPath];
	[alert setShowsHelp:YES];
	[alert setDelegate:self];
	
	[alert beginSheetModalForWindow:self.window 
						modalDelegate:self didEndSelector:@selector(noPDFAlertDidEnd:returnCode:contextInfo:) 
						contextInfo:nil];
	[[alert window] makeKeyWindow];
}

- (void)finishAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	switch (returnCode) {
		case NSAlertDefaultReturn:
			[[NSWorkspace sharedWorkspace] openFile:_mergeProcessor.destination];
			break;
		case NSAlertOtherReturn:
			[[NSWorkspace sharedWorkspace] selectFile:_mergeProcessor.destination inFileViewerRootedAtPath:nil];
			break;
		default:
			break;
	}
	[self close];
}

- (void)cancelTask
{
	[progressIndicator setDoubleValue:[progressIndicator minValue]];
	NSString *message = NSLocalizedString(@"Canceled", @"");
	[statusField setStringValue:message];
	self.processStarted = NO;
	statusLevel = 0;	
}

- (void)setStatusMessage:(NSString *)message indicatorIncrement:(double)delta
{
    [statusField setStringValue:NSLocalizedString(message, @"")];
    [progressIndicator incrementBy:delta];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow: 0.1]];
}

- (void)updateProgressMessage:(NSNotification *)notification
{
	NSDictionary *info = [notification userInfo];
	NSString *message = info[@"message"];
	if ([message isEqualToString:@"Success"]) {
		message = NSLocalizedString(message, @"");
		[progressIndicator setDoubleValue:[progressIndicator maxValue]];
		[statusField setStringValue:NSLocalizedString(message, @"")];
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Success to merge files into a PDF file.", @"")
										 defaultButton:NSLocalizedString(@"Open", @"")
									   alternateButton:NSLocalizedString(@"Cancel", @"")
										   otherButton:NSLocalizedString(@"Reveal", @"")
							 informativeTextWithFormat:@"%@", _mergeProcessor.destination];
		BOOL is_key = [self.window isKeyWindow];
		[alert beginSheetModalForWindow:self.window
						  modalDelegate:self didEndSelector:@selector(finishAlertDidEnd:returnCode:contextInfo:)
							contextInfo:nil];
		if (is_key) [self.window makeKeyWindow]; // to make sheet key-window.
		self.processStarted = NO;
		return;
	} else if ([message isEqualToString:@"Canceled"]) {
		[self cancelTask];
		return;
	} else {
		[progressIndicator incrementBy:[info[@"levelIncrement"] doubleValue]];
		[statusField setStringValue:NSLocalizedString(message, @"")];
	}
	
}

- (void)appendErrorMessage:(NSNotification *)notification
{
	NSString *msg = [[[notification userInfo][@"error"] localizedDescription] stringByAppendingString:@"\n"];
#if useLog
	NSLog(msg);
#endif
	NSTextStorage *textStorage;
	textStorage = [errorTextView textStorage];
	[textStorage beginEditing];
	[textStorage appendAttributedString:[[[NSAttributedString alloc] initWithString:msg] autorelease]];
	[textStorage endEditing];
}

#pragma mark DropBox
- (BOOL)dropBox:(NSView *)dbv acceptDrop:(id <NSDraggingInfo>)info item:(id)item
{
	self.sourceLocation = item;
	[worker setupDefaultDestination];
	return YES;
}

#pragma mark window delegate

- (void)windowWillClose:(NSNotification *)aNotification
{
	[[aNotification object] saveFrameUsingName:_frameName];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self release];
}

- (void)windowDidLoad
{
	self.frameName = @"ProgressWindow";
	NSWindow *a_window = self.window;
	[a_window center];
	[a_window setFrameUsingName:_frameName];
	
	statusLevel = 0;
	self.processStarted = NO;
	self.canceled = NO;
    
    [saveToBox setAcceptFileInfo:@[@{@"FileType": NSFileTypeDirectory}]];
}

#pragma mark choose new PDF location

- (void)chooseSaveLocation:(NSString *)defaultPath
{
	NSSavePanel *save_panel = [NSSavePanel savePanel];
	[save_panel setDirectoryURL:[NSURL fileURLWithPath:
						[defaultPath stringByDeletingLastPathComponent]]];
	[save_panel setNameFieldStringValue:[defaultPath lastPathComponent]];
	
	void (^cohandler)(NSInteger) = ^(NSInteger result_code) {
		
		if (NSFileHandlingPanelOKButton == result_code) {
			NSString *new_path = [[save_panel URL] path];
			NSArray *target_files = [worker targetFiles];
			[save_panel orderOut:self];
			[self processFiles:target_files to:new_path];
		} else {
			[self cancelAction:self];
			if (![self canceled]) return;
				
			[self cancelTask];
			[self setProcessStarted:NO];
		}
	};
	
	[save_panel beginSheetModalForWindow:[self window] completionHandler:cohandler];
}


@end
