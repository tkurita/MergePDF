#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface PDFDestination (MergePDF)
+ (PDFDestination *)destinationWithPage:(PDFPage *)page;
@end

@interface PDFDocument (MergePDF)
+ (PDFDocument *)pdfDocumentWithPath:(NSString *)path;
+ (PDFDocument *)pdfDocumentWithImageFile:(NSString *)path;
- (PDFOutline *)appendBookmark:(NSString *)label atPageIndex:(NSUInteger)index;
- (void)mergeFile:(NSString *)path;
@end

@interface PDFMerger : NSObject {
	NSArray *targetFiles;
	NSString *destination;
	BOOL canceled;
}

@property(retain) NSArray *targetFiles;
@property(retain) NSString* destination;
@property(readwrite) BOOL canceled;

@end
