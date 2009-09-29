#import "AppController.h"
#import "DonationReminder/DonationReminder.h"
#import "ProgressWindowController.h"
#import "SmartActivate.h"

#import <Quartz/Quartz.h>

#define useLog 1

#define DEFAULT_DPI 72

static id sharedObj;
static BOOL isFirstOpen = YES;

@implementation AppController

+ (id)sharedAppController
{
	if (sharedObj == nil) {
		sharedObj = [[self alloc] init];
	}
	return sharedObj;
}

- (id)init
{
	if (self = [super init]) {
		if (sharedObj == nil) {
			sharedObj = self;
		}
	}
	
	return self;
}

- (BOOL)activateWindowForFolder:(NSString *)path
{
	for (NSWindow *window in [NSApp windows]) {
		if ([window.windowController isKindOfClass:[ProgressWindowController class]]) {
			NSString *location = [window.windowController sourceLocation];
			if ([location isEqualToString:path]) {
				[window.windowController showWindow:self];
				return YES;
			}
		}
	}
	return NO;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	BOOL is_dir;
	if (! [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&is_dir]) 
		return NO;
	if (!is_dir) return NO;
	
	if (! [[NSWorkspace sharedWorkspace] openFile:filename]) return NO;
	[SmartActivate activateSelf];
	[self processFolder:filename];
	return YES;
}

- (void)processFolder:(NSString *)path
{
	if ([self activateWindowForFolder:path]) return;
	ProgressWindowController *wcontroller = [[ProgressWindowController alloc] initWithWindowNibName:@"ProgressWindow"];
	[wcontroller setSourceLocation:path];
	[wcontroller showWindow:self];
	isFirstOpen = NO;
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
}

- (IBAction)makeDonation:(id)sender
{
	[DonationReminder goToDonation];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	[DonationReminder remindDonation];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#if useLog
	NSLog(@"start applicationDidFinishLaunching");
#endif
	if (isFirstOpen) {
		[self processFolder:@"Insertion Location"];
		//[self processFolder:@"/Users/tkurita/Dev/Projects/MergePDF/testpdfs/"];
	}
}

- (void)awakeFromNib
{
	NSString *defaultsPlistPath = [[NSBundle mainBundle] pathForResource:@"FactorySetting" ofType:@"plist"];
	NSDictionary *defautlsDict = [NSDictionary dictionaryWithContentsOfFile:defaultsPlistPath];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:defautlsDict];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}
@end
