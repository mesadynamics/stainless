//
//  StainlessView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 9/11/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessView.h"

extern BOOL gPrivateMode;
extern BOOL gStatusBar;


@implementation StainlessView

- (void)drawRect:(NSRect)rect
{
	NSRect origFrame = [self frame];
	
	NSRect frame = origFrame;
	frame.origin.y = frame.size.height - 58.0;
	frame.size.height = 35.0;
	[[NSImage imageNamed:(gPrivateMode ? @"PrivateNavigation" : @"Navigation")] drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	if(gStatusBar) {
		[[NSColor darkGrayColor] set];
		
		frame = origFrame;
		frame.origin.y = 15.0;
		frame.size.height = 1.0;
		NSRectFill(frame);

		frame.origin.y--;
		[[NSColor lightGrayColor] set];
		NSRectFill(frame);
	}
}

- (void)keyDown:(NSEvent *)event
{
}

@end
