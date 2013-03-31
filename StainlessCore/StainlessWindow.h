//
//  StainlessWindow.h
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StainlessClient.h"


@interface StainlessWindow : NSObject {
	NSString* identifier;
	NSValue* frame;
	StainlessClient* focus;
	StainlessClient* lastFocus;

	NSMutableArray* clients; // of StainlessClients
	NSMutableArray* ghosts; // of StainlessClients
	
	unsigned int space;
	NSInteger wid;
	
	BOOL privateMode;
	BOOL iconShelf;
	BOOL statusBar;
	
	NSString* shelfPath;
}

@property(retain) NSString* identifier;
@property(retain) NSValue* frame;
@property(retain) StainlessClient* focus;
@property(retain) StainlessClient* lastFocus;
@property unsigned int space;
@property NSInteger	wid;
@property BOOL privateMode;
@property BOOL iconShelf;
@property BOOL statusBar;
@property(retain) NSString* shelfPath;

- (BOOL)addClient:(StainlessClient*)client beforeClient:(StainlessClient*)nextClient;
- (StainlessClient*)moveClient:(StainlessClient*)client;
- (StainlessClient*)removeClient:(StainlessClient*)client;
- (StainlessClient*)clientAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfClient:(StainlessClient*)client;
- (void)refocusClientWindows;
- (void)switchFocusToClient:(StainlessClient*)client;
- (void)relayerClientWindows:(BOOL)bringToFront;
- (void)syncClientWindows;
- (void)alertClientWindows;
- (void)freezeClientWindows:(BOOL)freeze;
- (void)hideClientWindows:(BOOL)hide;
- (void)updateClientWindows:(NSString*)clientIdentifier;

- (NSDictionary*)attributes;
- (NSArray*)clients;
- (NSArray*)clientInformation;
- (NSArray*)clientIdentifiers;
- (BOOL)isMultiClient;
- (void)saveFrame;

- (oneway void)setStoreIconShelf:(BOOL)set;
- (oneway void)setStoreStatusBar:(BOOL)set;

- (NSComparisonResult)identifierCompare:(StainlessWindow*)container;

@end
