#import "DonationReminder.h"

@implementation DonationReminder

+ (void)goToDonation
{
	NSString *urlString = [[NSUserDefaults standardUserDefaults] stringForKey:@"donationURL"];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (IBAction)cancelDonation:(id)sender
{
	[[self window] close];
}

- (IBAction)donated:(id)sender
{
	NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSArray *verList = [userDefaults objectForKey:@"DonatedVersions"];
	if (verList == nil) {
		verList = [NSArray arrayWithObject:[bundleInfo objectForKey:@"CFBundleVersion"]];
	}
	else {
		verList = [verList arrayByAddingObject:[bundleInfo objectForKey:@"CFBundleVersion"]];
	}
	[userDefaults setObject:verList forKey:@"DonatedVersions"];
}

- (IBAction)makeDonation:(id)sender
{
	[[self class] goToDonation];
	[[self window] close];
}

+ (id)displayReminder
{
	id newObj = [[self alloc] initWithWindowNibName:@"DonationReminder"];
	[newObj showWindow:newObj];
	return newObj;
}

+ (id)remindDonation
{
	//return [self displayReminder];
	NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSArray *verList = [userDefaults objectForKey:@"DonatedVersions"];
	if (verList == nil) {
		return [self displayReminder];
	}
	else if (![verList containsObject:[bundleInfo objectForKey:@"CFBundleVersion"]]) {
		return [self displayReminder];
	}
	
	return nil;
}

- (void)awakeFromNib
{
	NSString *theMessage = [_productMessage stringValue];
	[_productMessage setStringValue: [NSString stringWithFormat:theMessage,NSLocalizedString(@"this software",@"")]];
	[[self window] center];
}

@end
