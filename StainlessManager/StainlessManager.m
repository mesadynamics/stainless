//
//  main.m
//  StainlessManager
//
//  Created by Danny Espinoza on 3/6/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

static id server = nil;
static NSConnection* port = nil;
static NSWorkspace* workspace = nil;
static NSRect gMenubarRect;

@protocol StainlessWorkspaceServer
- (void)beginTransportForPid:(pid_t)pid;
@end

@interface StainlessListener : NSObject
- (void)disconnect:(NSNotification*)aNotification;
@end

@implementation StainlessListener

- (void)disconnect:(NSNotification*)aNotification
{
	@try {
		[port registerName:nil];
		[port invalidate];
	}

	@catch (NSException* anException) {
	}
	
	exit(0);
}

@end


static
CGEventRef transportCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon)
{
	int clickState = CGEventGetIntegerValueField(event, kCGMouseEventClickState);
	if(clickState == 1) {
		NSPoint mouse = NSPointFromCGPoint(CGEventGetLocation(event));
		
		if(NSPointInRect(mouse, gMenubarRect)) {
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			
			NSDictionary* activeApplication = [workspace activeApplication];
			NSString* activeBundle = [activeApplication objectForKey:@"NSApplicationBundleIdentifier"];
			if([activeBundle isEqualToString:@"com.stainlessapp.StainlessClient"]) {
				NSNumber* pidNumber = [activeApplication objectForKey:@"NSApplicationProcessIdentifier"];
				if(pidNumber) {
					@try {
						[server beginTransportForPid:[pidNumber integerValue]];
					}
					
					@catch (NSException* anException) {
						NSLog(@"%@ exception: %@", [anException name], [anException reason]);
					}
				}
			}
			
			[pool drain];
		}
	}
	
	return event;
}

int main(int argc, const char * argv[])
{
	if(argc == 2) {		
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSScreen* menubarScreen = [[NSScreen screens] objectAtIndex:0];
		gMenubarRect = [menubarScreen frame];
		gMenubarRect.origin.y = 0;
		gMenubarRect.size.height = atof(argv[1]);
		
		workspace = [NSWorkspace sharedWorkspace];

		@try {
			server = [[NSConnection rootProxyForConnectionWithRegisteredName:@"StainlessServer" host:nil] retain];
		}
		
		@catch (NSException* anException) {
			NSLog(@"%@ exception: %@", [anException name], [anException reason]);
			server = nil;
		}

		if(server) {
			[server setProtocolForProxy:@protocol(StainlessWorkspaceServer)];
			
			StainlessListener* listener = [[StainlessListener alloc] init];
			
			id connection = [[NSConnection serviceConnectionWithName:@"StainlessManager" rootObject:listener] retain];			
			if(connection) {
				[[NSNotificationCenter defaultCenter] addObserver:listener selector:@selector(disconnect:) name:@"NSConnectionDidDieNotification" object:[server connectionForProxy]];
				
				CGEventMask eventMask = CGEventMaskBit(kCGEventLeftMouseDown);
				CFMachPortRef eventPort = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, eventMask, transportCallback, NULL);
				if(eventPort) {
					CFRunLoopSourceRef eventSrc = CFMachPortCreateRunLoopSource(NULL, eventPort, 0);
					if(eventSrc) {
						CFRunLoopRef runLoop = CFRunLoopGetCurrent();
						if(runLoop) {
							CFRunLoopAddSource(runLoop, eventSrc, kCFRunLoopDefaultMode);
							CFRunLoopRun();
						}
					}
				}
			}
		}
		
		[pool drain];
	}
	
    return 0;
}
