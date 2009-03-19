#import "AppController.h"
#import "DonationReminder/DonationReminder.h"
#import "ProgressWindowController.h"

#import <Quartz/Quartz.h>

#define DEFAULT_DPI 72

static id sharedObj;

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
		NSString *location = [window.windowController sourceLocation];
		if ([location isEqualToString:path]) {
			[window.windowController showWindow:self];
			return YES;
		}
	}
	return NO;
}

- (void)processFolder:(NSString *)path
{
	if ([self activateWindowForFolder:path]) return;
	ProgressWindowController *wcontroller = [[ProgressWindowController alloc] initWithWindowNibName:@"ProgressWindow"];
	[wcontroller setSourceLocation:path];
	[wcontroller showWindow:self];
}

- (IBAction)makeDonation:(id)sender
{
	[DonationReminder goToDonation];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	[DonationReminder remindDonation];
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
