//
//  OverlayWindow.m
//  StainlessClient
//
//  Created by Danny Espinoza on 10/24/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "OverlayWindow.h"


@implementation OverlayWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	NSWindow* result = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	if(result) {
		[result setBackgroundColor:[NSColor clearColor]];
		[result setAlphaValue:0.0];
		[result setOpaque:NO];

		[result setIgnoresMouseEvents:YES];
	}
	
	return result;
}

@end
