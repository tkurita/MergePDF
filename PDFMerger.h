#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

typedef enum {
	NotImage,
	GenericImage, 
	PDFImage,
JpegImage } ImageKind;

ImageKind image_type(NSString *path);

@interface PDFDestination (MergePDF)
+ (PDFDestination *)destinationWithPage:(PDFPage *)page;
@end

@interface PDFDocument (MergePDF)
- (PDFOutline *)appendBookmark:(NSString *)label atPageIndex:(NSUInteger)index;
+ (PDFDocument *)pdfDocumentWithURL:(NSURL *)fURL;
+ (PDFDocument *)pdfDocumentWithImageURL:(NSURL *)fURL;
- (BOOL)mergeFileAtURL:(NSURL *)path error:(NSError **)error;

//deprecated
- (BOOL)mergeFile:(NSString *)path error:(NSError **)error;
+ (PDFDocument *)pdfDocumentWithPath:(NSString *)path;
+ (PDFDocument *)pdfDocumentWithImageFile:(NSString *)path;

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
