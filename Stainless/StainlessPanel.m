//
//  StainlessPanel.m
//  Stainless
//
//  Created by Danny Espinoza on 4/17/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessPanel.h"


@implementation StainlessPanel

@synthesize focusWid;
@synthesize focusMode;
@synthesize focusOnAppChange;

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	if(self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag]) {
		focusWid = 0;
		focusMode = NSWindowAbove;
		focusOnAppChange = NO;
	}
	
	return self;
}

@end
