#import "AppController.h"
#import "DonationReminder.h"

@class ASKScriptCache;
@implementation AppController
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	[DonationReminder remindDonation];
}
/*
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	id scriptCash = [ASKScriptCache sharedScriptCache];
	id theScript = [scriptCash scriptWithName:@"MergePDF"];
	NSDictionary *errorInfo;
	//NSLog([theScript source]);
	NSArray *inputArray = [NSArray arrayWithObjects:@"incoming data", 
		nil];
	[theScript executeHandlerWithName:@"sayhello" arguments:nil error:&errorInfo];
	NSLog([errorInfo description]);
}
*/
- (void)awakeFromNib
{
	NSString *defaultsPlistPath = [[NSBundle mainBundle] pathForResource:@"FactorySetting" ofType:@"plist"];
	NSDictionary *defautlsDict = [NSDictionary dictionaryWithContentsOfFile:defaultsPlistPath];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:defautlsDict];
}
@end
