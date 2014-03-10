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
	
ImageKind image_type(NSString *path)
{
	CFStringRef a_uti = nil;
	OSStatus status = noErr;
	FSRef fileref;
	ImageKind result = NotImage;
    status = FSPathMakeRef((UInt8 *)[path fileSystemRepresentation], &fileref, NULL); 
	if (status != noErr) {
		NSLog(@"Fail to FSPathMakeRef for %@", path);
		goto bail;
	}
	status = LSCopyItemAttribute(&fileref, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&a_uti );
	if (status != noErr) {
		NSLog(@"Fail to LSCopyItemAttribute for %@", path);
		goto finish;
	}
	if (UTTypeConformsTo(a_uti, CFSTR("com.adobe.pdf"))){
		result = PDFImage;
		goto finish;
	}
	if ([(NSString *)a_uti isEqualToString:@"com.adobe.illustrator.ai-image"]) {
		result = PDFImage;
		goto finish;
	}
		
	if (UTTypeConformsTo(a_uti, CFSTR("public.jpeg"))) {
		result = JpegImage;
		goto finish;
	}

	if (UTTypeConformsTo(a_uti, CFSTR("public.image"))) result = GenericImage;
finish:
	CFRelease(a_uti);
bail:
#if useLog	
	NSLog(@"image type : %d", result); 
#endif	
	return result;
}


// it looks PDFPage's initWithImage cause same result in almost
// But CGPDFContext help to keep file size of jpeg in Mac OS X 10.5
// In Mac OS X 10.6, initWithImage does not increse data size of jpeg.
+ (PDFDocument *)pdfDocumentWithImageFile:(NSString *)path 
{
	PDFDocument *doc = nil;
	CGContextRef out_context = NULL;
	size_t img_count;
	NSURL *url = [NSURL fileURLWithPath:path];
	CGImageSourceRef image_source =  CGImageSourceCreateWithURL((CFURLRef)url, NULL);
	CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
	CGDataConsumerRef data_consumer = CGDataConsumerCreateWithCFData(data);
	if (data_consumer == NULL) {
		img_count = 0;
		goto bail;
	}
	out_context = CGPDFContextCreate(data_consumer, NULL, NULL);
	img_count = CGImageSourceGetCount(image_source);
	CFNumberRef dpi = NULL;
	for (size_t i = 0; i<img_count; i++) {
		CFDictionaryRef image_info = CGImageSourceCopyPropertiesAtIndex(image_source, i, NULL );
		CGImageRef image = CGImageSourceCreateImageAtIndex( image_source, i, NULL );
#if useLog
		 CFShow(image_info);
		 CFShow(CFDictionaryGetValue(image_info, kCGImagePropertyDPIHeight));
		 CFShow(CFDictionaryGetValue(image_info, kCGImagePropertyDPIWidth));
		 CFShow(CFDictionaryGetValue(image_info, kCGImagePropertyPixelHeight));
		 CFShow(CFDictionaryGetValue(image_info, kCGImagePropertyPixelWidth));
#endif
		float dpi_w = DEFAULT_DPI;
		dpi = CFDictionaryGetValue(image_info, kCGImagePropertyDPIWidth);
		if (dpi) {
			CFNumberGetValue(dpi, kCFNumberFloat32Type, &dpi_w);
		}
			
		float dpi_h = DEFAULT_DPI;
		dpi = CFDictionaryGetValue(image_info, kCGImagePropertyDPIHeight);
		if (dpi) {
			CFNumberGetValue(dpi, kCFNumberFloat32Type, &dpi_h);
		}
		
		int size_w;
		CFNumberGetValue(CFDictionaryGetValue(image_info, kCGImagePropertyPixelWidth), 
						 kCFNumberSInt32Type, &size_w);
		int size_h;
		CFNumberGetValue(CFDictionaryGetValue(image_info, kCGImagePropertyPixelHeight), 
						 kCFNumberSInt32Type, &size_h);
		CFRelease(image_info);
		
		CGRect img_rect = CGRectMake(0, 0, size_w/(dpi_w/DEFAULT_DPI), size_h/(dpi_h/DEFAULT_DPI));
		
		
		CGContextBeginPage(out_context, &img_rect);
		//CGPDFContextBeginPage(out_context, &img_rect);
		// Draw the image into the rect.
		CGContextDrawImage(out_context, img_rect, image);
		//CGContextEndPage(out_context);
		CGPDFContextEndPage(out_context);
		CFRelease(image);
		
	}
	CGPDFContextClose(out_context);
	CGContextRelease(out_context);
	if (CFDataGetLength(data)) {
		doc = [[PDFDocument alloc] initWithData:(NSData *)data];
	}
bail:
	CFRelease(image_source);
	CGDataConsumerRelease(data_consumer);
	CFRelease(data);	
	return [doc autorelease];	
}

+ (PDFDocument *)pdfDocumentWithPath:(NSString *)path
{
	PDFDocument *result = NULL;

	switch (image_type(path)) {
		case JpegImage:
			result = [PDFDocument pdfDocumentWithImageFile:path];
			break;
		case GenericImage:
			result = [[[PDFDocument alloc] init] autorelease];
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
			break;
		default:
			result = [[[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: path]] autorelease];
			break;
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

- (BOOL)mergeFile:(NSString *)path error:(NSError **)error
{
#if useLog
	NSLog(@"start mergeFile for %@", path);
#endif
	PDFDocument *pdf_doc = [PDFDocument pdfDocumentWithPath:path];
	if (!pdf_doc) {
		//NSLog(@"Fail to get PDF for %@", path);
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSString stringWithFormat:@"Fail to get PDF for %@.",path], NSLocalizedDescriptionKey, nil];
		*error = [NSError errorWithDomain:@"MergePDFErrorDomain" code:0 userInfo:dict];
		return NO;
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
	return YES;
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

- (void)postErrorNotification:(NSError *)error
{
	NSNotificationCenter *noticenter = [NSNotificationCenter defaultCenter];
	[noticenter postNotificationName:@"AppendErrorMessage" object:self userInfo:
		[NSDictionary dictionaryWithObject:error forKey:@"error"]];
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
	NSError *error;
	if ([self checkCanceled]) goto bail;
	double incstep = 85.0/[targetFiles count];
	NSEnumerator *enumerator = [targetFiles objectEnumerator];
	NSString *path = [[[enumerator nextObject] URL] path];
	[self postProgressNotificationWithFile:path increment:incstep];
	PDFDocument *pdf_doc = [PDFDocument pdfDocumentWithPath:path];
	if (!pdf_doc) {
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSString stringWithFormat:@"Fail to get PDF for %@.",path], NSLocalizedDescriptionKey, nil];
		error = [NSError errorWithDomain:@"MergePDFErrorDomain" code:0 userInfo:dict];
		[self postErrorNotification:error];
		return;
	}
	
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

	while (path = [[[enumerator nextObject] URL] path]) {
		if ([self checkCanceled]) goto bail;
		[self postProgressNotificationWithFile:path increment:incstep];
		if (![pdf_doc mergeFile:path error:&error] ) {
			[self postErrorNotification:error];
		}
	}
	if ([self checkCanceled]) goto bail;
	[self postProgressNotificationWithMessage:NSLocalizedString(@"Saving a new PDF file", @"") increment:5];
	[pdf_doc writeToFile:destination];
	[self postProgressNotificationWithMessage:@"Success" increment:5];
bail:
	[pool release];
}

@end
