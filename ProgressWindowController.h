#import <Cocoa/Cocoa.h>
#import "PDFMerger.h"

@interface ProgressWindowController : NSWindowController <NSAlertDelegate> {
	IBOutlet NSTextField *statusField;
	IBOutlet NSTextView *errorTextView;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField *newFileField;
	IBOutlet NSWindow *directionChooserWindow;
	IBOutlet id worker;
	
	NSUInteger statusLevel;
}

@property (retain) NSString *sourceLocation;
@property (retain) NSString *frameName;
@property (retain) PDFMerger *mergeProcessor;
@property (assign) BOOL processStarted;
@property (assign) BOOL canceled;

- (IBAction)cancelAction:(id)sender;
- (IBAction)closeDirectionChooser:(id)sender;
- (void)setStatusMessage:(NSString *)message indicatorIncrement:(double)delta;

@end
