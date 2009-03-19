#import "PDFMerger.h"

#define useLog 0

#define DEFAULT_DPI 72

@implementation PDFDestination (MergePDF)

+ (PDFDestination *)destinationWithPage:(PDFPage *)page
{
	NSRect rect = [page boundsForBox:kPDFDisplayBoxMediaBox];
	NSPoint point = NSMakePoint(kPDFDestinationUnspecifiedValue, rect.size.height);
	PDFDestination *dest = [[PDFDestination alloc] initWithPage:page atPoint:point];
	return [dest autorelease];
}

@end

@implementation PDFDocument (MergePDF)

BOOL is_image_file(NSString *path)
{
	CFStringRef a_uti = nil;
	OSStatus status = noErr;
	FSRef fileref;
    status = FSPathMakeRef((UInt8 *)[path fileSystemRepresentation], &fileref, NULL); 
	if (status != noErr) {
		NSLog(@"Fail to FSPathMakeRef for %@", path);
		return NO;
	}
	status = LSCopyItemAttribute(&fileref, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&a_uti );
	if (status != noErr) {
		NSLog(@"Fail to LSCopyItemAttribute for %@", path);
		return NO;
	}
	if (UTTypeConformsTo(a_uti, CFSTR("com.adobe.pdf"))) return NO;
	if ([(NSString *)a_uti isEqualToString:@"com.adobe.illustrator.ai-image"]) return NO;
	return UTTypeConformsTo(a_uti, CFSTR("public.image"));
}

+ (PDFDocument *)pdfDocumentWithImageFile:(NSString *)path // it looks PDFPage's initWithImage cause same result.
{
	size_t img_count;
	NSURL *url = [NSURL fileURLWithPath:path];
	CGImageSourceRef image_source =  CGImageSourceCreateWithURL((CFURLRef)url, NULL);
	CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
	CGDataConsumerRef data_consumer = CGDataConsumerCreateWithCFData(data);
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
	CGContextRelease(out_context);
	PDFDocument *doc = [[PDFDocument alloc] initWithData:(NSData *)data];
bail:
	CFRelease(image_source);
	CGDataConsumerRelease(data_consumer);
	CFRelease(data);	
	return [doc autorelease];	
}

+ (PDFDocument *)pdfDocumentWithPath:(NSString *)path
{
	PDFDocument *result = NULL;
	if (is_image_file(path)) {
		result = [[PDFDocument alloc] init];
		NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
		NSEnumerator *enumerator = [[image representations] objectEnumerator];
		NSImageRep *imagerep;
		NSUInteger ind = 0;
		PDFPage *page = NULL;
		NSImage *single_image = NULL;
		while (imagerep = [enumerator nextObject]) { //support for multipage tiff
			single_image = [NSImage new];
			[single_image addRepresentation:imagerep];
			page = [[PDFPage alloc] initWithImage:[single_image autorelease]];
			[result insertPage:[page autorelease] atIndex:ind];
			ind++;
		}
		[image autorelease];
		//result = [PDFDocument pdfDocumentWithImageFile:path];
	} else {
		result = [[[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: path]] autorelease];
	}
	return result;
}

- (void)appendOutline:(PDFOutline *)outline
{
	[[self outlineRoot] insertChild:outline atIndex:[[self outlineRoot] numberOfChildren]];	
}	
	
- (PDFOutline *) appendBookmark:(NSString *)label atPageIndex:(NSUInteger)index
{
	PDFOutline *newoutline = [[[PDFOutline alloc] init] autorelease];
	[newoutline setLabel:label];
#if useLog	
	NSLog(@"pageCount: %d, index:%d", [self pageCount], index);
#endif
	PDFPage *target_page = [self pageAtIndex:index];
	PDFDestination *bookmark_destination = [PDFDestination destinationWithPage:target_page];
	[newoutline setDestination:bookmark_destination];
	[self appendOutline:newoutline];	
	return newoutline;
}

- (void)mergeFile:(NSString *)path
{
#if useLog
	NSLog(@"start mergeFile for %@", path);
#endif
	PDFDocument *pdf_doc = [PDFDocument pdfDocumentWithPath:path];
	if (!pdf_doc) {
		NSLog(@"Fail to get PDF for %@", path);
		return;
	}
	NSInteger npages = [pdf_doc pageCount];
#if useLog
	NSLog(@"number of pages before appending : %d", [self pageCount]);
	NSLog(@"number of pages to append : %d", npages);
#endif
	for (int n = 0; n < npages; n++) {
		[self insertPage:[pdf_doc pageAtIndex:n] atIndex:[self pageCount]];
	}
#if useLog
	NSLog(@"number of pages after appending : %d", [self pageCount]);
#endif
	PDFOutline *outline = [[pdf_doc outlineRoot] retain];
	NSString *label = [[path lastPathComponent] stringByDeletingPathExtension];
	NSUInteger destpage_index = [self pageCount]-npages;
	if (outline) {
		PDFDestination *pdfdest = [PDFDestination destinationWithPage:[self pageAtIndex: destpage_index]];
		[outline setDestination:pdfdest];
		[outline setLabel:label];
		[self appendOutline:[outline autorelease]];
	} else {
		[self appendBookmark:[[path lastPathComponent] stringByDeletingPathExtension]
										   atPageIndex:destpage_index];
	}
}

@end


@implementation PDFMerger
@synthesize targetFiles, destination, canceled;

- (id)init {
    if (self = [super init]) {
		canceled = NO;
    }
    return self;
}
- (void)dealloc
{
	[targetFiles release];
	[destination release];
	[super dealloc];
}

- (void)postProgressNotificationWithFile:(NSString *)path increment:(double)increment
{
	NSNotificationCenter *noticenter = [NSNotificationCenter defaultCenter];
	NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Processing %@", @""), 
							[path lastPathComponent]];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
							  message, @"message", 
							  [NSNumber numberWithDouble:increment], @"levelIncrement", nil];
	[noticenter postNotificationName:@"UpdateProgressMessage" object:self userInfo:dict];
}

- (void)postProgressNotificationWithMessage:(NSString *)message increment:(double)increment
{
	NSNotificationCenter *noticenter = [NSNotificationCenter defaultCenter];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  message, @"message", 
						  [NSNumber numberWithDouble:increment], @"levelIncrement", nil];
	[noticenter postNotificationName:@"UpdateProgressMessage" object:self userInfo:dict];
}

- (BOOL)checkCanceled
{
	if (!canceled) {
#if useLog		
		NSLog(@"Not canceled");
#endif
		return NO;
	}
	[self postProgressNotificationWithMessage:@"Canceled" increment:0];
	return YES;
}

- (void)start:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if ([self checkCanceled]) goto bail;
	double incstep = 85.0/[targetFiles count];
	NSEnumerator *enumerator = [targetFiles objectEnumerator];
	NSString *path = [enumerator nextObject];
	[self postProgressNotificationWithFile:path increment:incstep];
	PDFDocument *pdf_doc = [PDFDocument pdfDocumentWithPath:path];
	PDFOutline *outline = [[pdf_doc outlineRoot] retain];
	[pdf_doc setOutlineRoot:[[[PDFOutline alloc] init] autorelease]];
	NSString *label = [[path lastPathComponent] stringByDeletingPathExtension];
	if (outline) {
		[outline setLabel:label];
		PDFDestination *pdfdest = [PDFDestination destinationWithPage:[pdf_doc pageAtIndex:0]];
		[outline setDestination:pdfdest];
		[pdf_doc appendOutline:[outline autorelease]];	
	} else {
		[pdf_doc appendBookmark:label atPageIndex:0];
	}
	

	while (path = [enumerator nextObject]) {
		if ([self checkCanceled]) goto bail;
		[self postProgressNotificationWithFile:path increment:incstep];
		[pdf_doc mergeFile:path];
	}
	if ([self checkCanceled]) goto bail;
	[self postProgressNotificationWithMessage:NSLocalizedString(@"Saving a new PDF file", @"") increment:5];
	[pdf_doc writeToFile:destination];
	[self postProgressNotificationWithMessage:@"Success" increment:5];
bail:
	[pool release];
}

@end
