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
+ (PDFDocument *)pdfDocumentWithPath:(NSString *)path;
+ (PDFDocument *)pdfDocumentWithImageFile:(NSString *)path;

@end

@interface PDFOutline (MergePDF)
+ (PDFOutline *)outlineWithCopying:(PDFOutline *)outline;
@end

@interface PDFMerger : NSObject

@property(strong) NSArray *targetFiles;
@property(strong) NSString* destination;
@property(assign) BOOL canceled;

@end
