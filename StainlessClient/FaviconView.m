//
//  FaviconView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 1/30/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "FaviconView.h"
#import "StainlessTabView.h"
#import "StainlessController.h"

extern BOOL gPrivateMode;
extern BOOL gIconShelf;


@implementation FaviconView

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		mouseDown = NO;
	}
	
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	mouseDown = YES;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if(mouseDown) {
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		StainlessTabView* tab = (StainlessTabView*) [self superview];
		[controller switchTab:tab];
	}
	
	mouseDown = NO;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if(mouseDown) {		
		mouseDown = NO;
		
		if(gPrivateMode)
			return;
		
		StainlessTabView* tab = (StainlessTabView*) [self superview];
		NSString* urlString = [tab tabURL];
		if(urlString && [urlString length]) {
			NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
			[tab writeToPasteboard:pboard];
			
			NSPoint framePosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
			NSPoint dragPosition = [theEvent locationInWindow];
			dragPosition.x -= framePosition.x;
			dragPosition.y -= framePosition.y;
			
			BOOL revealShelf = NO;
			if(gIconShelf == NO) {
				StainlessController* controller = (StainlessController*)[NSApp delegate];
				[controller toggleIconShelf:self];
				revealShelf = YES;
			}
			
			[[self window] dragImage:[self image] at:dragPosition offset:NSMakeSize(0.0, 0.0) event:theEvent pasteboard:pboard source:self slideBack:NO];
		
			if(revealShelf)
				[NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(hideIconShelf:) userInfo:nil repeats:NO];
		}
	}
}

// Callbacks
- (void)hideIconShelf:(id)sender
{
	StainlessController* controller = (StainlessController*)[NSApp delegate];
	[controller toggleIconShelf:self];
}

@end
