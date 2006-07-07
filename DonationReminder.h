/* DonationReminder */

#import <Cocoa/Cocoa.h>

@interface DonationReminder : NSWindowController
{
    IBOutlet id _productMessage;
}
- (IBAction)cancelDonation:(id)sender;
- (IBAction)donated:(id)sender;
- (IBAction)makeDonation:(id)sender;
+ (id)remindDonation;
+ (void)goToDonation;

@end
