#import "PDFMerger.h"
#import "AppleEventExtra.h"

#define useLog 0

#define DEFAULT_DPI 72

@implementation PDFDestination (MergePDF)

+ (PDFDestination *)destinationWithPage:(PDFPage *)page
{
	NSRect rect = [page boundsForBox:kPDFDisplayBoxMediaBox];
	NSPoint point = NSMakePoint(kPDFDestinationUnspecifiedValue, rect.size.height);
	PDFDestination *dest = [[PDFDestination alloc] initWithPage:page atPoint:point];
	return dest;
}

@end

@implementation PDFDocument (MergePDF)
	
ImageKind image_type(NSString *path)
{
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSError *err = nil;
    NSString *uti = [ws typeOfFile:path error:&err];
    if (err) {
        [NSApp presentError:err];
        return NotImage;
    }
    
    if ([ws type:uti conformsToType:@"com.adobe.pdf"]) {
        return PDFImage;
        
    } else if ([uti isEqualToString:@"com.adobe.illustrator.ai-image"]) {
        return PDFImage;
        
    } else if ([ws type:uti conformsToType:@"public.jpeg"]) {
        return JpegImage;
    } else if ([ws type:uti conformsToType:@"public.image"]) {
        return GenericImage;
    }
    
    return NotImage;
}

//deprecated use pdfDocumentWithImageURL:
// it looks PDFPage's initWithImage cause same result in almost
// But CGPDFContext help to keep file size of jpeg in Mac OS X 10.5
// In Mac OS X 10.6, initWithImage does not increse data size of jpeg.
+ (PDFDocument *)pdfDocumentWithImageFile:(NSString *)path 
{
	PDFDocument *doc = nil;
	CGContextRef out_context = NULL;
	size_t img_count;
	NSURL *url = [NSURL fileURLWithPath:path];
	CGImageSourceRef image_source =  CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
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
		doc = [[PDFDocument alloc] initWithData:(NSData *)CFBridgingRelease(data)];
	}
bail:
	CFRelease(image_source);
	CGDataConsumerRelease(data_consumer);
	CFRelease(data);	
	return doc;	
}

//deprecated use pdfDocumentWithImageURL
+ (PDFDocument *)pdfDocumentWithPath:(NSString *)path
{
	PDFDocument *result = NULL;

	switch (image_type(path)) {
		case JpegImage:
			result = [PDFDocument pdfDocumentWithImageFile:path];
			break;
		case GenericImage:
        {
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
				page = [[PDFPage alloc] initWithImage:single_image];
				[result insertPage:page atIndex:ind];
				ind++;
			}
			break;
        }
		default:
			result = [[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: path]];
			break;
	}
	return result;
}

+ (PDFDocument *)pdfDocumentWithImageURL:(NSURL *)fURL
{
    PDFDocument *result = [[PDFDocument alloc] init];
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:fURL];
    NSArray *image_reps = [image representations];
    if ([image_reps count] > 1) {
        //support for multipage tiff
        NSUInteger ind = 0;
        for (NSImageRep *imgrep in image_reps) {
            NSImage *single_image = [NSImage new];
            [single_image addRepresentation:imgrep];
             PDFPage *page = [[PDFPage alloc] initWithImage:single_image];
             [result insertPage:page atIndex:ind++];
        }
    } else {
        PDFPage *page = [[PDFPage alloc] initWithImage:image];
        [result insertPage:page atIndex:0];
    }
    
    return result;
}

+ (PDFDocument *)pdfDocumentWithURL:(NSURL *)fURL
{
    PDFDocument *result = NULL;
    
	switch (image_type([fURL path])) {
		case JpegImage:
			result = [PDFDocument pdfDocumentWithImageURL:fURL];
			break;
		case GenericImage:
            result = [PDFDocument pdfDocumentWithImageURL:fURL];
			break;
		default:
			result = [[PDFDocument alloc] initWithURL: fURL];
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
	PDFOutline *newoutline = [[PDFOutline alloc] init];
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

// deprecated use mergeFileAtURL:
- (BOOL)mergeFile:(NSString *)path error:(NSError **)error
{
#if useLog
	NSLog(@"start mergeFile for %@", path);
#endif
	PDFDocument *pdf_doc = [PDFDocument pdfDocumentWithPath:path];
	if (!pdf_doc) {
		//NSLog(@"Fail to get PDF for %@", path);
		NSDictionary *dict = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Fail to get PDF for %@.",path]};
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
	PDFOutline *outline = [pdf_doc outlineRoot];
	NSString *label = [[path lastPathComponent] stringByDeletingPathExtension];
	NSUInteger destpage_index = [self pageCount]-npages;
	if (outline) {
		PDFDestination *pdfdest = [PDFDestination destinationWithPage:[self pageAtIndex: destpage_index]];
		[outline setDestination:pdfdest];
		[outline setLabel:label];
		[self appendOutline:outline];
	} else {
		[self appendBookmark:[[path lastPathComponent] stringByDeletingPathExtension]
										   atPageIndex:destpage_index];
	}
	return YES;
}

- (BOOL)mergeFileAtURL:(NSURL *)fURL error:(NSError **)error
{
#if useLog
	NSLog(@"start mergeFile for %@", fURL);
#endif
	PDFDocument *pdf_doc = [PDFDocument pdfDocumentWithURL:fURL];
	if (!pdf_doc) {
		//NSLog(@"Fail to get PDF for %@", path);
		NSDictionary *dict = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Fail to get PDF for %@.",[fURL path]]};
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
	PDFOutline *outline = [pdf_doc outlineRoot];
	NSString *label = [[fURL lastPathComponent] stringByDeletingPathExtension];
	NSUInteger destpage_index = [self pageCount]-npages;
	if (outline) {
		PDFDestination *pdfdest = [PDFDestination destinationWithPage:[self pageAtIndex: destpage_index]];
		[outline setDestination:pdfdest];
		[outline setLabel:label];
		[self appendOutline:outline];
	} else {
		[self appendBookmark:[[fURL lastPathComponent] stringByDeletingPathExtension]
                 atPageIndex:destpage_index];
	}
	return YES;
}

@end


@implementation PDFMerger

- (id)init {
    if (self = [super init]) {
		self.canceled = NO;
    }
    return self;
}

- (void)postProgressNotificationWithFile:(NSString *)path increment:(double)increment
{
	NSLog(@"postProgressNotificationWithFile:%@", path);
    NSNotificationCenter *noticenter = [NSNotificationCenter defaultCenter];
	NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Processing %@", @""), 
							[path lastPathComponent]];
	NSDictionary *dict = @{@"message": message, 
							  @"levelIncrement": @(increment)};
	[noticenter postNotificationName:@"UpdateProgressMessage" object:self userInfo:dict];
}

- (void)postProgressNotificationWithMessage:(NSString *)message increment:(double)increment
{
	NSNotificationCenter *noticenter = [NSNotificationCenter defaultCenter];
	NSDictionary *dict = @{@"message": message, 
						  @"levelIncrement": @(increment)};
	//[noticenter postNotificationName:@"UpdateProgressMessage" object:self userInfo:dict];
    
    [noticenter performSelectorOnMainThread:@selector(postNotification:)
                                 withObject:[NSNotification notificationWithName:@"UpdateProgressMessage"
                                                                          object:self
                                                                        userInfo:dict]
                              waitUntilDone:NO];
}

- (void)postErrorNotification:(NSError *)error
{
	NSNotificationCenter *noticenter = [NSNotificationCenter defaultCenter];
	[noticenter postNotificationName:@"AppendErrorMessage" object:self userInfo:
		@{@"error": error}];
}

- (BOOL)checkCanceled
{
	if (!_canceled) {
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
	@autoreleasepool {
        NSError *error = nil;
        if ([self checkCanceled]) return;
        double incstep = 85.0/[_targetFiles count];
        NSEnumerator *enumerator = [_targetFiles objectEnumerator];
        NSURL *fURL = [[enumerator nextObject] URL];
        [self postProgressNotificationWithFile:[fURL path] increment:incstep];
        PDFDocument *pdf_doc = [PDFDocument pdfDocumentWithURL:fURL];
        if (!pdf_doc) {
            NSDictionary *dict = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Fail to get PDF for %@.",[fURL path]]};
            error = [NSError errorWithDomain:@"MergePDFErrorDomain" code:0 userInfo:dict];
            [self postErrorNotification:error];
            return;
        }
        
        PDFOutline *outline = [pdf_doc outlineRoot];
        [pdf_doc setOutlineRoot:[[PDFOutline alloc] init]];
        NSString *label = [[fURL lastPathComponent] stringByDeletingPathExtension];
        if (outline) {
            [outline setLabel:label];
            PDFDestination *pdfdest = [PDFDestination destinationWithPage:[pdf_doc pageAtIndex:0]];
            [outline setDestination:pdfdest];
            [pdf_doc appendOutline:outline];	
        } else {
            [pdf_doc appendBookmark:label atPageIndex:0];
        }

        for (NSAppleEventDescriptor *aedesc in enumerator) {
            fURL = [aedesc URL];
            if ([self checkCanceled]) return;
            [self postProgressNotificationWithFile:[fURL path] increment:incstep];
            if (![pdf_doc mergeFileAtURL:fURL error:&error] ) {
                [self postErrorNotification:error];
            }
        }
        if ([self checkCanceled]) return;
        [self postProgressNotificationWithMessage:NSLocalizedString(@"Saving a new PDF file", @"") increment:5];
        [pdf_doc writeToFile:_destination];
        [self postProgressNotificationWithMessage:@"Success" increment:5];
    }

}

@end
