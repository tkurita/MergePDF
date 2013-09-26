#import "AppleEventExtra.h"
#import "NSURL+NDCarbonUtilities.h"

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

+ (NSAppleEventDescriptor *)descriptorWithDouble:(double)a_value
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
			Handle			alias_handle;
			FSRef			fs_ref;
			Boolean			was_changed;
			
			data_size = AEGetDescDataSize([self aeDesc]);
			alias_handle = NewHandle(data_size);
			HLock(alias_handle);
			err = AEGetDescData([self aeDesc], *alias_handle, data_size);
			HUnlock(alias_handle);
			if( err == noErr  && FSResolveAlias(NULL, (AliasHandle)alias_handle, &fs_ref, &was_changed ) == noErr )
			{
				file_url = [NSURL URLWithFSRef:&fs_ref];
			}
			
			DisposeHandle(alias_handle);
			break;
		}
		case typeFileURL:
			data_size = AEGetDescDataSize([self aeDesc]);
			data_ptr = malloc(data_size);
			err = AEGetDescData([self aeDesc], data_ptr, data_size);
			if (noErr != err) {
				file_url = (NSURL *)CFURLCreateAbsoluteURLWithBytes(NULL,
														   (const UInt8 *)data_ptr,
														   data_size,
														   kCFStringEncodingUTF8,
														   NULL,
														   false);
				file_url = [file_url autorelease];
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
