#import "AppleEventExtra.h"

@implementation NSAppleEventDescriptor (AppleEventExtra)

+ (NSAppleEventDescriptor *)descriptorWithShort:(short)a_value
{
	return [self descriptorWithDescriptorType:typeSInt16 
										bytes:&a_value
									   length:sizeof(a_value)];
}

+ (NSAppleEventDescriptor *)descriptorWithUnsignedShort:(unsigned short)a_value
{
	return [self descriptorWithDescriptorType:typeUInt16 
										bytes:&a_value
									   length:sizeof(a_value)];
}

+ (NSAppleEventDescriptor *)descriptorWithUnsignedLong:(unsigned long)a_value
{
	return [self descriptorWithDescriptorType:typeUInt32 
										bytes:&a_value
									   length:sizeof(a_value)];
}

+ (NSAppleEventDescriptor *)descriptorWithLongLong:(long long)a_value
{
	return [self descriptorWithDescriptorType:typeSInt64 
										bytes:&a_value
									   length:sizeof(a_value)];
}

+ (NSAppleEventDescriptor *)descriptorWithUnsignedLongLong:(unsigned long long)a_value
{
	return [self descriptorWithDescriptorType:typeUInt64 
										bytes:&a_value
									   length:sizeof(a_value)];
}

+ (NSAppleEventDescriptor *)descriptorWithFloat:(float)a_value
{
	return [self descriptorWithDescriptorType:typeIEEE32BitFloatingPoint 
										bytes:&a_value
									   length:sizeof(a_value)];
}

- (NSURL *)URL
{
	id file_url = nil;
	OSErr err;
	Size data_size;
	void *data_ptr = NULL;
	
	switch([self descriptorType])
	{
		case typeAlias:							//	alias record
		{
            NSAppleEventDescriptor *ae_type_url = [self coerceToDescriptorType:typeFileURL];
            NSData *url_data = [ae_type_url data];
            
            file_url = (NSURL *)CFBridgingRelease(CFURLCreateWithBytes(NULL, [url_data bytes],
                                                        [url_data length], kCFStringEncodingUTF8, NULL));
			break;
		}
		case typeFileURL:
			data_size = AEGetDescDataSize([self aeDesc]);
			data_ptr = malloc(data_size);
			err = AEGetDescData([self aeDesc], data_ptr, data_size);
			if (noErr != err) {
				file_url = (NSURL *)CFBridgingRelease(CFURLCreateAbsoluteURLWithBytes(NULL,
														   (const UInt8 *)data_ptr,
														   data_size,
														   kCFStringEncodingUTF8,
														   NULL,
														   false));
			}
			free(data_ptr);
			break;
	}
	
	return file_url;	
}

@end

@implementation NSString (AppleEventExtra)
- (NSAppleEventDescriptor *)appleEventDescriptor
{
	return [NSAppleEventDescriptor descriptorWithString:self];
}
@end

@implementation NSNumber (AppleEventExtra)
- (NSAppleEventDescriptor *)appleEventDescriptor
{
	const char *type = [self objCType];

	if(strcmp(type, @encode(BOOL)) == 0)
		return [NSAppleEventDescriptor descriptorWithBoolean:[self boolValue]];
	else if(strcmp(type, @encode(short)) == 0)
		return [NSAppleEventDescriptor descriptorWithShort:[self shortValue]];
	else if(strcmp(type, @encode(unsigned short)) == 0)
		return [NSAppleEventDescriptor descriptorWithUnsignedShort:[self unsignedShortValue]];
	else if(strcmp(type, @encode(int)) == 0)
		return [NSAppleEventDescriptor descriptorWithInt32:[self intValue]];
	else if(strcmp(type, @encode(unsigned int)) == 0)
		return [NSAppleEventDescriptor descriptorWithUnsignedLong:[self unsignedIntValue]];
	else if(strcmp(type, @encode(long)) == 0)
		return [NSAppleEventDescriptor descriptorWithInt32:[self longValue]];
	else if(strcmp(type, @encode(unsigned long)) == 0)
		return [NSAppleEventDescriptor descriptorWithInt32:[self unsignedLongValue]];
	else if(strcmp(type, @encode(float)) == 0)
		return [NSAppleEventDescriptor descriptorWithFloat:[self floatValue]];
	else if(strcmp(type, @encode(double)) == 0)
		return [NSAppleEventDescriptor descriptorWithDouble:[self doubleValue]];
	
	return nil;
}


@end
