#import "AppController.h"
#import "DonationReminder/DonationReminder.h"
#import <Quartz/Quartz.h>

static id sharedObj;

@class ASKScriptCache;
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

- (unsigned int)countPDFPages:(NSString *)aPath
{
	PDFDocument *pdf_doc = [[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: aPath]];
	unsigned int n_pages = [pdf_doc pageCount];
	//NSLog([[NSNumber numberWithUnsignedInt:n_pages] description]);
	[pdf_doc release];
	return n_pages;
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
@end
