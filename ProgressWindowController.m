#import "ProgressWindowController.h"
#define useLog 0

@implementation ProgressWindowController
@synthesize progressStatuses, sourceLocation, frameName, mergeProcessor, processStarted, canceled;


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[progressStatuses release];
	[sourceLocation release];
	[frameName release];
	[super dealloc];
}

- (void)closeDirectionChooser
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
	if (processStarted) {
#if useLog		
		NSLog(@"cancel merge processor");
#endif
		if (mergeProcessor) {
			mergeProcessor.canceled = YES;
			canceled = YES;
		} else {
			canceled = YES;
		}
	} else {
		[self close];
	}
}

- (void)markProcessStarted
{
	processStarted = YES;
}

- (void)processFiles:(NSArray *)array to:(NSString *)destination
{
	[newFileField setStringValue:destination];
	self.mergeProcessor = [[PDFMerger new] autorelease];
	NSNotificationCenter *noticenter = [NSNotificationCenter defaultCenter];
	[noticenter addObserver:self selector:@selector(updateProgressMessage:) 
					   name:@"UpdateProgressMessage" object:mergeProcessor];
	[noticenter addObserver:self selector:@selector(appendErrorMessage:)
					   name:@"AppendErrorMessage" object:mergeProcessor];
	mergeProcessor.targetFiles = array;
	mergeProcessor.destination = destination;
	[NSThread detachNewThreadSelector:@selector(start:) toTarget:mergeProcessor withObject:self];
}

- (double)currentProgressValue
{
	return [progressIndicator doubleValue];
}

- (void)updateStatus
{
	NSDictionary *dict = [progressStatuses objectAtIndex:statusLevel];
	NSString *msg = NSLocalizedString([dict objectForKey:@"status"], nil);
	[statusField setStringValue:msg];
	[progressIndicator incrementBy:[[dict objectForKey:@"levelIncrement"] doubleValue]];
	statusLevel++;
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
						 informativeTextWithFormat:
					  [NSString stringWithFormat:NSLocalizedString(@"Location :",nil), aPath]];
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
			[[NSWorkspace sharedWorkspace] openFile:mergeProcessor.destination];
			break;
		case NSAlertOtherReturn:
			[[NSWorkspace sharedWorkspace] selectFile:mergeProcessor.destination inFileViewerRootedAtPath:nil];
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
	processStarted = NO;
	statusLevel = 0;	
}

- (void)updateProgressMessage:(NSNotification *)notification
{
	NSDictionary *info = [notification userInfo];
	NSString *message = [info objectForKey:@"message"];
	if ([message isEqualToString:@"Success"]) {
		message = NSLocalizedString(message, @"");
		[progressIndicator setDoubleValue:[progressIndicator maxValue]];
		[statusField setStringValue:message];
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Success to merge files into a PDF file.", @"")
										 defaultButton:NSLocalizedString(@"Open", @"")
									   alternateButton:NSLocalizedString(@"Cancel", @"")
										   otherButton:NSLocalizedString(@"Reveal", @"")
							 informativeTextWithFormat:mergeProcessor.destination];
		BOOL is_key = [self.window isKeyWindow];
		[alert beginSheetModalForWindow:self.window
						  modalDelegate:self didEndSelector:@selector(finishAlertDidEnd:returnCode:contextInfo:)
							contextInfo:nil];
		if (is_key) [self.window makeKeyWindow]; // to make sheet key-window.
		processStarted = NO;
		return;
	} else if ([message isEqualToString:@"Canceled"]) {
		[self cancelTask];
		return;
	} else {
		[progressIndicator incrementBy:[[info objectForKey:@"levelIncrement"] doubleValue]];
		[statusField setStringValue:message];
	}
	
}

- (void)appendErrorMessage:(NSNotification *)notification
{
	NSString *msg = [[[[notification userInfo] objectForKey:@"error"] localizedDescription] stringByAppendingString:@"\n"];
	NSLog(msg);
	NSTextStorage *textStorage;
	textStorage = [errorTextView textStorage];
	[textStorage beginEditing];
	[textStorage appendAttributedString:[[[NSAttributedString alloc] initWithString:msg] autorelease]];
	[textStorage endEditing];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[[aNotification object] saveFrameUsingName:frameName];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self release];
}

- (void)windowDidLoad
{
	self.frameName = @"ProgressWindow";
	NSWindow *a_window = self.window;
	[a_window center];
	[a_window setFrameUsingName:frameName];
	
	NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
	self.progressStatuses = [user_defaults arrayForKey:@"ProgressMessages"];
	statusLevel = 0;
	processStarted = NO;
	canceled = NO;
}

@end
