//
//  StainlessBridge.m
//  Stainless
//
//  Created by Danny Espinoza on 9/6/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessBridge.h"

NSString* SMHideShadow = @"HideShadow";
NSString* SMShowShadow = @"ShowShadow";
NSString* SMPrepareToSpawn = @"PrepareToSpawn";

NSString* SMHideHomeButton = @"HideHomeButton";
NSString* SMShowHomeButton = @"ShowHomeButton";
NSString* SMUpdateIconShelf = @"UpdateIconShelf";
NSString* SMHidePopups = @"HidePopups";
NSString* SMShowPopups = @"ShowPopups";


@implementation NSString (Stainless)

- (int)globalHash
{	
  	int base1 = 0;
	int base2 = 0;
	int base3 = 0;
	int base4 = 0;
	
	char* element = (char*) [self UTF8String];
	
	while(*element) {
		int h = (int) (*element);
		
		base1 += h;
		element++;
		
		if(*element) {
			h = (int) (*element);
			
			base1 += h;
			base2 += h;
			element++;
		}
		
		if(*element) {
			h = (int) (*element);
			
			base1 += h;
			base3 += h;
			element++;
		}
		
		if(*element) {
			h = (int) (*element);
			
			base1 += h;
			base2 += h;
			element++;
		}
		
		if(*element) {
			h = (int) (*element);
			
			base1 += h;
			base4 += h;
			element++;
		}
		
		if(*element) {
			h = (int) (*element);
			
			base1 += h;
			base2 += h;
			base3 += h;
			element++;
		}
	}
	
	return (base1 + (base2 << 8) + (base3 << 16) + (base4 << 24));
}

@end


@implementation NSImage (Stainless)

- (NSImage*)thumbnailWithSize:(NSSize)scaleSize
{
	if(NSEqualSizes([self size], scaleSize))
		return self;
	
	NSImage* iconImage = [[self copy] autorelease];
	NSImage* thumbImage = nil;
	
	@try {
		thumbImage = [[NSImage alloc] initWithSize:scaleSize];
		
		NSAffineTransform* at = [NSAffineTransform transform];
		[iconImage setScalesWhenResized:YES];
		
		float heightFactor = scaleSize.height / [iconImage size].height;
		float widthFactor = scaleSize.width / [iconImage size].width;
		float scale = 1.0;
		
		if(heightFactor > widthFactor)
			scale = widthFactor;
		else
			scale = heightFactor;
		
		[at scaleBy:scale];
		
		[thumbImage lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[iconImage setSize:[at transformSize:[iconImage size]]];
		[iconImage compositeToPoint:NSMakePoint((scaleSize.width-[iconImage size].width)*.5 , (scaleSize.height-[iconImage size].height)*.5) operation:NSCompositeCopy];
		[thumbImage unlockFocus];
	}

	@catch (NSException* anException) {
		thumbImage = nil;
	}
	
	return thumbImage;
}

@end

