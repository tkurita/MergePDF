#import "ProgressWindowController.h"
#import "DropBox.h"

#define useLog 0

@interface ProgressWindowWorker : NSObject
    - (void)setupDefaultDestination;
@end

@implementation ProgressWindowController

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)closeDirectionChooser:(id)sender
{
    [self.window endSheet:directionChooserWindow];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (void)showDirectionChooser
{
    [self.window beginSheet:directionChooserWindow
          completionHandler:^(NSInteger result)
     {
         [self->directionChooserWindow orderOut:self];
     }];
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
	self.mergeProcessor = [PDFMerger new];
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

- (void)noPDFAlert:(NSString *)aPath
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"notFoundPDFs", @"")];
    [alert setInformativeText:
            [NSString stringWithFormat:NSLocalizedString(@"Location :",@""), aPath]];
	[alert setShowsHelp:YES];
	[alert setDelegate:self];
	
    [alert beginSheetModalForWindow:self.window
                  completionHandler:^(NSModalResponse returnCode)
     {
         [self close];
     }];
	[[alert window] makeKeyWindow];
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

        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:NSLocalizedString(@"Success to merge files into a PDF file.", @"")];
        [alert setInformativeText:_mergeProcessor.destination];
        [alert addButtonWithTitle:NSLocalizedString(@"Open", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Reveal", @"")];
        
		BOOL is_key = [self.window isKeyWindow];
		[alert beginSheetModalForWindow:self.window
                      completionHandler:^(NSModalResponse returnCode)
         {
             switch (returnCode) {
                 case NSAlertFirstButtonReturn:
                     [[NSWorkspace sharedWorkspace] openFile:self.mergeProcessor.destination];
                     break;
                 case NSAlertThirdButtonReturn:
                     [[NSWorkspace sharedWorkspace] selectFile:self.mergeProcessor.destination
                                      inFileViewerRootedAtPath:@""];
                     break;
                 default:
                     break;
             }
             [self close];
         }];

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
	[textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:msg]];
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
			NSArray *target_files = [self->worker targetFiles];
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
