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

static Boolean fullscreen = false;

static OSStatus handleSystemUIModeChanged(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void* inUserData)
{
	if(fullscreen == false) {
		UInt32 mode = 0;
		GetEventParameter(inEvent, kEventParamSystemUIMode, typeUInt32, NULL, sizeof(UInt32), NULL, &mode);
		
		if(mode != kUIModeNormal) {
			ProcessSerialNumber current;
			GetCurrentProcess(&current);
			
			ProcessSerialNumber front;
			GetFrontProcess(&front);
			
			Boolean same;
			SameProcess(&current, &front, &same);
			
			if(same)
				fullscreen = true;
		}
	}
	
	return noErr;
}

static OSStatus handleActiveWindowChanged(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void* inUserData)
{
	if(fullscreen) {
		StainlessController* controller = (StainlessController*) inUserData;
		[[controller window] makeKeyWindow];
		
		SetSystemUIMode(kUIModeNormal, 0);
		fullscreen = false;
	}
	
	return noErr;
}


@implementation StainlessApplication

- (id)init
{
	if(self = [super init]) {
		ignoreNextActivation = NO;
		lastMouseDown = NO;
		
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:@"~/Library/Preferences/Stainless/Databases" forKey:@"WebDatabaseDirectory"];
		[defaults setObject:@"~/Library/Preferences/Stainless/Icons" forKey:@"WebIconDatabaseDirectoryDefaultsKey"];
		[defaults setObject:@"~/Library/Preferences/Stainless/LocalStorage" forKey:@"WebKitLocalStorageDatabasePathPreferenceKey"];
		[defaults setObject:[NSNumber numberWithBool:YES] forKey:@"WebContinuousSpellCheckingEnabled"];

		{
			NSImage* defaultWebIcon = nil;
			
			@try {
				Class webIconDatabaseClass = NSClassFromString(@"WebIconDatabase");
				if(webIconDatabaseClass) {
					[webIconDatabaseClass performSelector:@selector(_checkIntegrityBeforeOpening)];
					
					id iconDB = [webIconDatabaseClass performSelector:@selector(sharedIconDatabase)];	
					defaultWebIcon = [iconDB defaultIconWithSize:NSMakeSize(16.0, 16.0)];
				}
			}
			
			@catch (NSException* anException) {
			}
			
			if(defaultWebIcon == nil) {
				@try {
					NSData* iconData = [[NSImage imageNamed:@"NSNetwork"] TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:1.0];
					if(iconData)
						defaultWebIcon = [[NSImage alloc] initWithData:iconData];
				}
				
				@catch (NSException* anException) {
				}	
			}
			
			[defaultWebIcon setName:@"Web"];
		}		
	}
	
	return self;
}


- (NSEvent *)nextEventMatchingMask:(NSUInteger)mask untilDate:(NSDate *)expiration inMode:(NSString *)mode dequeue:(BOOL)flag
{
	NSEvent* event = [super nextEventMatchingMask:mask untilDate:expiration inMode:mode dequeue:flag];
	
	/*if([event type] == NSAppKitDefined && [event subtype] == NSApplicationActivatedEventType) {
		if(ignoreNextActivation == NO) {
			StainlessController* controller = (StainlessController*) [self delegate];
			[controller bringProcessToFront];
		}
		
		ignoreNextActivation = NO;
	}
	else*/
		
	if([event type] == NSLeftMouseDown || [event type] == NSRightMouseDown || [event type] == NSOtherMouseDown) {
		lastMouseDown = [event type];
	
		//StainlessController* controller = (StainlessController*) [self delegate];
		//[controller mouseDownInProcess:NO];
	}
				
	return event;
}

- (void)finishLaunching
{
	EventTypeSpec systemEvent = { kEventClassApplication, kEventAppSystemUIModeChanged };
	InstallApplicationEventHandler(NewEventHandlerUPP(handleSystemUIModeChanged), 1, &systemEvent, NULL, NULL);
	
	EventTypeSpec windowEvent = { kEventClassApplication, kEventAppActiveWindowChanged };
	InstallApplicationEventHandler(NewEventHandlerUPP(handleActiveWindowChanged), 1, &windowEvent, [self delegate], NULL);
	
	[super finishLaunching];
}

@synthesize ignoreNextActivation;
@synthesize lastMouseDown;

@end
