//
//  OverlayView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 10/28/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "OverlayView.h"


@implementation OverlayView


- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		holes = nil;
		offset = NSZeroPoint;
		selection = NSZeroRect;
	}
	
    return self;
}

- (void)dealloc
{
	[holes release];
	
	[super dealloc];
}

- (BOOL)isFlipped
{
	return YES;
}
		
- (void)drawRect:(NSRect)rect
{
	NSRect frame = [self frame];
	
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.25] set];
	NSRectFill(frame);
	
	[[NSColor clearColor] set];

	for(NSValue* hole in holes) {
		NSRect r = NSOffsetRect([hole rectValue], -offset.x, -offset.y);
		NSRectFill(r);
	}	
	
	if(NSIsEmptyRect(selection) == NO) {
		[NSGraphicsContext saveGraphicsState]; 
		NSShadow* theShadow = [[NSShadow alloc] init]; 
		[theShadow setShadowOffset:NSMakeSize(0.0, -1.0)]; 
		[theShadow setShadowBlurRadius:1.0]; 
		[theShadow setShadowColor:[NSColor darkGrayColor]]; 		
		[theShadow set];

		NSRect r = NSOffsetRect(selection, -offset.x, -offset.y);
		NSRect cursor = NSInsetRect(r, -1.0, -1.0);
		NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:cursor xRadius:5.0 yRadius:5.0];
		[path setLineWidth:3.0];
		[[NSColor yellowColor] set];
		[path stroke];
		
		[NSGraphicsContext restoreGraphicsState];
		[theShadow release]; 
	}
}

@synthesize holes;
@synthesize offset;
@synthesize selection;

@end
