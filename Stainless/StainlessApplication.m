//
//  StainlessApplication.m
//  Stainless
//
//  Created by Danny Espinoza on 9/10/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessApplication.h"
#import "StainlessController.h"
#import <Carbon/Carbon.h>

static bool fullscreen = false;

extern bool gTransporting;

static OSStatus handleSystemUIModeChanged(EventHandlerCallRef myHandler, EventRef event, void *user_data)
{
	UInt32 mode = 0;
	GetEventParameter(event, kEventParamSystemUIMode, typeUInt32, NULL, sizeof(UInt32), NULL, &mode);

	NSDictionary* activeApplication = [[NSWorkspace sharedWorkspace] activeApplication];
	NSString* activeBundle = [activeApplication objectForKey:@"NSApplicationBundleIdentifier"];
	if([activeBundle isEqualToString:@"com.stainlessapp.StainlessClient"]) {
		if(mode == kUIModeNormal) {
			if(fullscreen) {
				[NSMenu setMenuBarVisible:YES];
				fullscreen = false;
			}
		}
		else {
			if(fullscreen == false) {
				[NSMenu setMenuBarVisible:NO];
				fullscreen = true;
			}
		}
	}
		
	return noErr;
}


@implementation StainlessApplication

- (NSEvent *)nextEventMatchingMask:(NSUInteger)mask untilDate:(NSDate *)expiration inMode:(NSString *)mode dequeue:(BOOL)flag
{
	NSEvent* event = [super nextEventMatchingMask:mask untilDate:expiration inMode:mode dequeue:flag];
	if([event type] == NSLeftMouseDown || [event type] == NSRightMouseDown || [event type] == NSOtherMouseDown) {
		StainlessController* controller = (StainlessController*) [self delegate];
		[controller setIgnoreActivation:YES];
	}
	 
	return event;
}

- (void)finishLaunching
{		  
	EventTypeSpec event = { kEventClassApplication, kEventAppSystemUIModeChanged };
	InstallApplicationEventHandler(NewEventHandlerUPP(handleSystemUIModeChanged), 1, &event, NULL, NULL);
	
	[super finishLaunching];
}

// NSUserInterfaceValidations protocol
- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
	if(
	   [anItem action] == @selector(undo:) ||
	   [anItem action] == @selector(redo:) ||
	   [anItem action] == @selector(cut:) ||
	   [anItem action] == @selector(copy:) ||
	   [anItem action] == @selector(paste:) ||
	   [anItem action] == @selector(delete:) ||
	   [anItem action] == @selector(selectAll:)
	)
	{
		// return Undo and Redo for title
		
		if(gTransporting)
			return YES;
		else {
			ProcessSerialNumber clientProcess = { 0, kCurrentProcess };
			ProcessSerialNumber frontProcess;
			GetFrontProcess(&frontProcess);
			
			Boolean result;
			SameProcess(&frontProcess, &clientProcess, &result);
			if(result == false)
				return YES;
		}
		
		return NO;
	}
	else if([anItem action] == @selector(noopAction:)) {
		if(gTransporting)
			return YES;
	}
	
	return [super validateUserInterfaceItem:anItem];
}

- (void)undo:(id)sender
{
	StainlessController* controller = (StainlessController*) [self delegate];
	[controller performCommand:sender];
}

- (void)redo:(id)sender
{
	StainlessController* controller = (StainlessController*) [self delegate];
	[controller performCommand:sender];
}

- (void)cut:(id)sender
{
	StainlessController* controller = (StainlessController*) [self delegate];
	[controller performCommand:sender];
}

- (void)copy:(id)sender
{
	StainlessController* controller = (StainlessController*) [self delegate];
	[controller performCommand:sender];
}

- (void)paste:(id)sender
{
	StainlessController* controller = (StainlessController*) [self delegate];
	[controller performCommand:sender];
}

- (void)delete:(id)sender
{
	StainlessController* controller = (StainlessController*) [self delegate];
	[controller performCommand:sender];
}

- (void)selectAll:(id)sender
{
	StainlessController* controller = (StainlessController*) [self delegate];
	[controller performCommand:sender];
}

- (void)noopAction:(id)sender
{
}


@end
