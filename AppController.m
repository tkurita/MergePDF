#import "AppController.h"
#import "DonationReminder.h"

@implementation AppController
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
@end
