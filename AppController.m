#import "AppController.h"
#import "DonationReminder/DonationReminder.h"
#import "ProgressWindowController.h"
#import "SmartActivate.h"

#import <Quartz/Quartz.h>

#define useLog 0

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

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
#if useLog
	NSLog([NSString stringWithFormat:@"start application:openFiles: for :%@",[filenames description]]);
#endif	
	NSEnumerator *enumerator = [filenames objectEnumerator];
	NSString *filename = nil;
	while (filename = [enumerator nextObject]) {
		BOOL is_dir;
		if (! [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&is_dir]) 
			continue;
		if (!is_dir) continue;
		
		if (! [[NSWorkspace sharedWorkspace] openFile:filename]) continue;
		[self processFolder:filename];
	}
	[SmartActivate activateSelf];

#if useLog
	NSLog(@"end application:openFiles:");
#endif	
}

- (void)processFolder:(NSString *)path
{
	if ([self activateWindowForFolder:path]) return;
	ProgressWindowController *wcontroller = [[ProgressWindowController alloc] initWithWindowNibName:@"ProgressWindow"];
	[wcontroller setSourceLocation:path];
	[wcontroller showWindow:self];
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

OSType getLauchedMethod()
{
#if useLog
	NSLog(@"start getLauchedMethod");
#endif	
	NSAppleEventDescriptor *ev = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
#if useLog
	NSLog([ev description]);
#endif
	if (!ev) {
		return typeNull;
	}
	AEEventID evid = [ev eventID];
	NSAppleEventDescriptor *propData;
	OSType result = kAEOpenApplication;
	switch (evid) {
		case kAEOpenDocuments:
			result = evid;
			break;
		case kAEOpenApplication:
			propData = [ev paramDescriptorForKeyword: keyAEPropData];
			DescType type = propData ? [propData descriptorType] : typeNull;
			if(type == typeType) {
				result = [propData typeCodeValue];
				// keyAELaunchedAsLogInItem or keyAELaunchedAsServiceItem
			} else {
				result = evid;
			}
			break;
	}
	return result;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#if useLog
	NSLog(@"start applicationDidFinishLaunching");
#endif
	NSAppleEventDescriptor *ev = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
	NSLog([NSString stringWithFormat:@"event :%@\n", [ev description]]);
	OSType evid = getLauchedMethod();
	NSLog(@"after getLauchedMethod");
	if (kAEOpenApplication == evid) {
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
