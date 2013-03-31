//
//  MainWindow.m
//  StainlessClient
//
//  Created by Danny Espinoza on 3/19/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "MainWindow.h"
#import <Carbon/Carbon.h>
#import "StainlessController.h"

extern BOOL gPrivateMode;


@implementation MainWindow

#if 0
- (void)sendEvent:(NSEvent *)theEvent
{
	if([theEvent type] == NSKeyDown && [theEvent keyCode] == kVK_Delete) {
		id responder = [self firstResponder];
		
		if([responder isMemberOfClass:[WebHTMLView class]]) {
			NSMenuItem* item = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector(paste:) keyEquivalent:@""] autorelease];
			if([responder validateUserInterfaceItemWithoutDelegate:item] == NO)
				return;
		}
	}
	
	[super sendEvent:theEvent];
}
#endif

- (void)sendEvent:(NSEvent *)theEvent
{
	if(gPrivateMode == NO && [theEvent type] == NSKeyDown) {
		int keyCode = [theEvent keyCode];
		NSResponder* responder = [self firstResponder];
		if([responder isMemberOfClass:[NSTextView class]]) {
			if([theEvent modifierFlags] & NSCommandKeyMask) {
				if(keyCode == kVK_ANSI_Period) {
					StainlessController* controller = (StainlessController*)[self windowController];
					
					if([[controller completion] isVisible])
						[controller keyDownForCompletion:kVK_Escape];
					//else
					//	[controller restoreCompletion];
					
					return;
				}
				else if(keyCode == kVK_Return) {
					StainlessController* controller = (StainlessController*)[self windowController];
					[controller newTabWithQuery];
					
					return;
				}
			}
			else if([theEvent modifierFlags] & NSControlKeyMask) {
				if(keyCode == kVK_ANSI_P || keyCode == kVK_ANSI_N) {
					StainlessController* controller = (StainlessController*)[self windowController];
					if([[controller completion] isVisible]) {
						if(keyCode == kVK_ANSI_P && [controller keyDownForCompletion:kVK_UpArrow])
							return;
						
						if(keyCode == kVK_ANSI_N && [controller keyDownForCompletion:kVK_DownArrow])
							return;
					}
				}
				else if(keyCode == kVK_Return) {
					StainlessController* controller = (StainlessController*)[self windowController];
					if([theEvent modifierFlags] & NSShiftKeyMask)
						[controller forceQuery:@"!:"];
					else
						[controller forceQuery:@"?:"];
					
					return;
				}
			}
			else if(keyCode == kVK_UpArrow || keyCode == kVK_DownArrow || keyCode == kVK_Escape || keyCode == kVK_Return || keyCode == kVK_Tab) {
				StainlessController* controller = (StainlessController*)[self windowController];
				if([[controller completion] isVisible]) {
					if([controller keyDownForCompletion:[theEvent keyCode]])
						return;
				}
			}
		}
		
		if(keyCode == kVK_Escape) {
			NSResponder* responder = [self firstResponder];
			if([responder isMemberOfClass:[NSTextView class]]) {
				NSView* superview = [[(NSView*)responder superview] superview];
				if([superview isMemberOfClass:[NSTextField class]])
					return;
			}
			
			//StainlessController* controller = (StainlessController*)[self windowController];
			//[controller restoreCompletion];
			
		}	
	}
	
	[super sendEvent:theEvent];
}

- (BOOL)makeFirstResponder:(NSResponder *)responder
{
	if([responder isEqualTo:query]) {
		StainlessController* controller = (StainlessController*)[self windowController];
		[controller openCompletion];
	}
	
	return [super makeFirstResponder:responder];
}

- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{
	return frameRect;
}

@end
