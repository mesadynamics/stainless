//
//  SearchView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 10/28/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "SearchView.h"


@implementation SearchView

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		gradient = nil;
	}
	
    return self;
}

- (void)dealloc
{
	[gradient release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
	NSRect frame = [self bounds];
	[[NSImage imageNamed:@"Find"] drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

@end
