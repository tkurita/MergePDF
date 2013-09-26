/* AppController */

#import <Cocoa/Cocoa.h>

@interface AppController : NSObject
{
}
- (void)processFolder:(NSString *)path;
- (IBAction)chooseFolder:(id)sender;
- (IBAction)makeDonation:(id)sender;
@end
