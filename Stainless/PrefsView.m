//
//  PrefsView.m
//  Stainless
//
//  Created by Danny Espinoza on 10/15/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "PrefsView.h"


@implementation PrefsView

- (void)drawRect:(NSRect)rect
{
	[[NSColor colorWithCalibratedWhite:.90 alpha:1.0] set];
	NSRectFill(rect);
	
    [super drawRect:rect];
}

@end
