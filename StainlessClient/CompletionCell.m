//
//  CompletionCell.m
//  StainlessClient
//
//  Created by Danny Espinoza on 10/19/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "CompletionCell.h"


@implementation CompletionCell

@synthesize attributes;

- (void)awakeFromNib
{
	NSFont* controlFont = [NSFont systemFontOfSize:13.0];
	NSFont* font = [[NSFontManager sharedFontManager] convertFont:controlFont toHaveTrait:NSCondensedFontMask];
	NSColor* color = [NSColor whiteColor];
	
	self.attributes = [[[NSDictionary alloc] initWithObjectsAndKeys:
						font, NSFontAttributeName,
						color, NSForegroundColorAttributeName,
						nil] autorelease];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect frame = cellFrame;
	frame.origin.y--;
	
	NSString* string = [self stringValue];
	if([string isEqualToString:@"-"]) {
		frame.origin.y += 5.0;
		frame.size.height = 1.0;
		
		[[NSColor colorWithCalibratedWhite:0.15 alpha:1.0] set];
		NSRectFill(frame);
		frame.origin.y++;
		[[NSColor colorWithCalibratedWhite:0.30 alpha:1.0] set];
		NSRectFill(frame);
	}
	else
		[string drawInRect:NSInsetRect(frame, 2.0, 0.0) withAttributes:attributes];
}

@end
