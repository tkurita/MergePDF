#import "AppController.h"
#import "DonationReminder/DonationReminder.h"
#import <Quartz/Quartz.h>

#define DEFAULT_DPI 72

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

- (size_t)convertImage:(NSString *)imgPath toPDF:(NSString *)outputPath
{
	size_t img_count;
	NSURL *url = [NSURL fileURLWithPath:imgPath];
	CGImageSourceRef image_source =  CGImageSourceCreateWithURL((CFURLRef)url, NULL);
	NSURL *out_url = [NSURL fileURLWithPath:outputPath];	
	CGDataConsumerRef data_consumer = CGDataConsumerCreateWithURL((CFURLRef)out_url);
	if (data_consumer == NULL) {
		img_count = 0;
		goto bail;
	}
	CGContextRef out_context = CGPDFContextCreate(data_consumer, NULL, NULL);
	img_count = CGImageSourceGetCount(image_source);
	for (size_t i = 0; i<img_count; i++) {
		CFDictionaryRef image_info = CGImageSourceCopyPropertiesAtIndex(image_source, i, NULL );
		CGImageRef image = CGImageSourceCreateImageAtIndex( image_source, i, NULL );
		/*
		CFShow(image_info);
		CFShow(CFDictionaryGetValue(image_info, kCGImagePropertyDPIHeight));
		CFShow(CFDictionaryGetValue(image_info, kCGImagePropertyDPIWidth));
		CFShow(CFDictionaryGetValue(image_info, kCGImagePropertyPixelHeight));
		CFShow(CFDictionaryGetValue(image_info, kCGImagePropertyPixelWidth));
		*/
		float dpi_w;
		CFNumberGetValue(CFDictionaryGetValue(image_info, kCGImagePropertyDPIWidth), 
												kCFNumberFloat32Type, &dpi_w);
		float dpi_h;
		CFNumberGetValue(CFDictionaryGetValue(image_info, kCGImagePropertyDPIHeight), 
												kCFNumberFloat32Type, &dpi_h);
		
		int size_w;
		CFNumberGetValue(CFDictionaryGetValue(image_info, kCGImagePropertyPixelWidth), 
												kCFNumberSInt32Type, &size_w);
		int size_h;
		CFNumberGetValue(CFDictionaryGetValue(image_info, kCGImagePropertyPixelHeight), 
												kCFNumberSInt32Type, &size_h);
		CFRelease(image_info);
		
		CGRect img_rect = CGRectMake(0, 0, size_w/(dpi_w/DEFAULT_DPI), size_h/(dpi_h/DEFAULT_DPI));
		
		
		CGContextBeginPage(out_context, &img_rect);
		// Draw the image into the rect.
		CGContextDrawImage(out_context, img_rect, image);
		CGContextEndPage(out_context);
		CFRelease(image);
		
	}
	CGDataConsumerRelease(data_consumer);
bail:
	CFRelease(image_source);
	CGContextRelease(out_context);

	return img_count;
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
