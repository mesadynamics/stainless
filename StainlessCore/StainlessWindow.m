//
//  StainlessWindow.m
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessWindow.h"
#import "StainlessBridge.h"


@implementation StainlessWindow

@synthesize identifier;
@synthesize frame;
@synthesize focus;
@synthesize lastFocus;
@synthesize space;
@synthesize wid;
@synthesize privateMode;
@synthesize iconShelf;
@synthesize statusBar;
@synthesize shelfPath;

- (id)init
{
	if(self = [super init]) {
		identifier = nil;
		frame = nil;
		focus = nil;
		lastFocus = nil;
				
		clients = [[NSMutableArray alloc] init];
		ghosts = [[NSMutableArray alloc] init];
				
		privateMode = NO;
		iconShelf = YES;
		statusBar = YES;
		
		shelfPath = nil;
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	if(self = [super init]) {
		self.identifier = [decoder decodeObject];
		self.frame = [decoder decodeObject];

		focus = nil;
		lastFocus = nil;
		
		clients = [[NSMutableArray alloc] init];
		ghosts = [[NSMutableArray alloc] init];
		
		space = [[decoder decodeObject] unsignedIntValue];
		iconShelf = [[decoder decodeObject] boolValue];
		statusBar = [[decoder decodeObject] boolValue];
		
		NSMutableArray* allClients = [decoder decodeObject];
		
		NSString* focusIdentifier = [decoder decodeObject];	
		if([focusIdentifier length] == 0)
			focusIdentifier = nil;
		
		for(StainlessClient* client in allClients) {
			[clients addObject:client];
			
			if(focusIdentifier && [focusIdentifier isEqualToString:[client identifier]]) {
				self.focus = client;
				focusIdentifier = nil;
			}
		}	
		
		privateMode = NO;
		
		shelfPath = nil;
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:identifier];
	[encoder encodeObject:frame];
	[encoder encodeObject:[NSNumber numberWithUnsignedInt:space]];
	[encoder encodeObject:[NSNumber numberWithBool:iconShelf]];
	[encoder encodeObject:[NSNumber numberWithBool:statusBar]];
	
	NSMutableArray* allClients = [NSMutableArray arrayWithCapacity:[clients count]];
	for(StainlessClient* client in clients) {
		if([client isChild] == NO)
			[allClients addObject:client];
	}
	
	[encoder encodeObject:allClients];
	
	NSString* focusIdentifier = @"";
	if(focus)
		focusIdentifier = [focus identifier];
	
	[encoder encodeObject:focusIdentifier];
}

- (void)dealloc
{
	[shelfPath release];
	
	[identifier release];
	[frame release];
	[focus release];
	[lastFocus release];
	
	[clients release];
	[ghosts release];
	
	[super dealloc];
}

- (BOOL)addClient:(StainlessClient*)client beforeClient:(StainlessClient*)nextClient
{
	BOOL didAddClient = YES;
	
	//@synchronized(clients) {	
		if([clients containsObject:client]) {
			[client retain];
			[clients removeObject:client];
			
			didAddClient = NO;
		}
		
		NSUInteger nextClientIndex = (nextClient ? [clients indexOfObject:nextClient] : NSNotFound);
		
		if(nextClientIndex == NSNotFound)
			[clients addObject:client];
		else
			[clients insertObject:client atIndex:nextClientIndex];
	//}
	
	if(didAddClient == NO)
		[client release];

	return didAddClient;
}

- (StainlessClient*)moveClient:(StainlessClient*)client
{
	StainlessClient* newFocus = focus;
	
	//@synchronized(clients) {	
		if([clients containsObject:client]) {
			if([clients count] == 1) {
				newFocus = nil;
			}
			else {
				if([client isEqualTo:focus]) {
					NSUInteger refocusIndex = [clients indexOfObject:client] + 1;
					if(refocusIndex == [clients count])
						refocusIndex -= 2;
					
					newFocus = [clients objectAtIndex:refocusIndex];
				}
			}
			
			[clients removeObject:client];
		}
	//}
	
	return newFocus;
}

- (StainlessClient*)removeClient:(StainlessClient*)client
{
	StainlessClient* newFocus = focus;
	
	//@synchronized(clients) {	
		if([clients containsObject:client]) {		
			if([clients count] == 1) {
				newFocus = nil;
				[[client connection] closeClient];
			}
			else {
				if([client isEqualTo:focus]) {
					NSUInteger refocusIndex = [clients indexOfObject:client] + 1;
					if(refocusIndex == [clients count])
						refocusIndex -= 2;
					
					newFocus = [clients objectAtIndex:refocusIndex];
				}
				
				//@synchronized(ghosts) {	
					if([client identifier] && [ghosts containsObject:client] == NO)
						[ghosts addObject:client];
				//}
			}
			
			[clients removeObject:client];
		}
	//}
	
	return newFocus;
}

- (StainlessClient*)clientAtIndex:(NSUInteger)index
{
	if(index < [clients count])
		return [clients objectAtIndex:index];
	
	return nil;
}

- (NSUInteger)indexOfClient:(StainlessClient*)client
{
	return [clients indexOfObject:client];
}

- (void)refocusClientWindows
{
	[[focus connection] reactivateClient];
}

- (void)switchFocusToClient:(StainlessClient*)client
{
	self.lastFocus = focus;
	self.focus = client;
	
	[[lastFocus connection] freezeClient:YES];
	
	if([[focus connection] activateClientAndBringToFront:YES withAttributes:[self attributes] siblings:[self clientInformation]])
		[self syncClientWindows];
}

- (void)relayerClientWindows:(BOOL)bringToFront
{
	//@synchronized(clients) {	
		for(StainlessClient* client in clients) {
			if([client isEqualTo:focus] == NO)
				[[client connection] freezeClient:YES];
		}
	//}
	
	if([[focus connection] activateClientAndBringToFront:bringToFront withAttributes:[self attributes] siblings:[self clientInformation]])
		[self syncClientWindows];
}

- (void)syncClientWindows
{
	[[focus connection] refreshClient:SMShowShadow];
	
	if(lastFocus) {
		//[[lastFocus connection] freezeClient:NO];
		[[lastFocus connection] deactivateClient];
		
		self.lastFocus = nil;
		return;
	}
	
	//@synchronized(clients) {	
		for(StainlessClient* client in clients) {
			if([client isEqualTo:focus] == NO) {
				//[[client connection] freezeClient:NO];
				[[client connection] deactivateClient];
			}
		}
	//}
	
	//@synchronized(ghosts) {	
		if([ghosts count] > 0) {
			for(StainlessClient* ghost in ghosts)
				[[ghost connection] closeClient];
			
			[ghosts removeAllObjects];
		}
	//}
}

- (void)alertClientWindows
{
	[[focus connection] refreshClient:SMPrepareToSpawn];
}

- (void)freezeClientWindows:(BOOL)freeze
{
	//for(StainlessClient* client in clients)
	//	[[client connection] freezeClient:freeze];
	
	[[focus connection] freezeClient:freeze];
}

- (void)hideClientWindows:(BOOL)hide
{
	//for(StainlessClient* client in clients) 
	//	[[client connection] hideClient:hide];

	[[focus connection] hideClient:hide];
}

- (void)updateClientWindows:(NSString*)clientIdentifier
{
	//for(StainlessClient* client in clients) {
	//	if([clientIdentifier isEqualToString:[client identifier]] == NO)
	//		[[client connection] updateClientWithIdentifier:clientIdentifier];
	//}
	
	if([clientIdentifier isEqualToString:[focus identifier]] == NO)
		[[focus connection] updateClientWithIdentifier:clientIdentifier];
}

- (NSDictionary*)attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[frame copy], @"Frame",
			[NSNumber numberWithInt:space], @"Space",
			[NSNumber numberWithBool:iconShelf], @"Shelf",
			[NSNumber numberWithBool:statusBar], @"Bar",
			shelfPath, @"Path",
			nil];
}

- (NSArray*)clients
{
	return clients;
}

- (NSArray*)clientInformation
{
	NSMutableArray* information = [NSMutableArray arrayWithCapacity:[clients count]];
	
	for(StainlessClient* client in clients) {
		NSMutableDictionary* info = [NSMutableDictionary dictionaryWithCapacity:1];
		
		[info setObject:[NSNumber numberWithBool:[client busy]] forKey:@"Busy"];
		
		id i = [client identifier];
		if(i)
			[info setObject:i forKey:@"Identifier"];
		
		i = [client session];
		if(i)
			[info setObject:i forKey:@"Session"];
		
		i = [client url];
		if(i)
			[info setObject:i forKey:@"URL"];
		
		i = [client title];
		if(i)
			[info setObject:i forKey:@"Title"];
		
		i = [client icon];
		if(i) {
			id iname = [i name];
			if(iname)
				[info setObject:[NSString stringWithString:iname] forKey:@"IconName"];
			 
			 i = [client iconData];
			 if(i)
				[info setObject:i forKey:@"IconData"];
		}
		
		[information addObject:info];
	}
	
	return information;
}

- (NSArray*)clientIdentifiers
{
	NSMutableArray* identifiers = nil;
	
	//@synchronized(clients) {	
	identifiers = [NSMutableArray arrayWithCapacity:[clients count]];
	
	for(StainlessClient* client in clients) {
		NSString* clientIdentifier = [client identifier];
		if(clientIdentifier)
			[identifiers addObject:[NSString stringWithString:clientIdentifier]];
	}
	
	return identifiers;
}

- (BOOL)isMultiClient
{
	return ([clients count] > 1 ? YES : NO);
}

- (void)saveFrame
{
	NSRect windowFrame = [frame rectValue];
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.x] forKey:@"WindowOriginX"];
	[defaults setObject:[NSNumber numberWithFloat:windowFrame.origin.y] forKey:@"WindowOriginY"];
	[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.width] forKey:@"WindowSizeWidth"];
	[defaults setObject:[NSNumber numberWithFloat:windowFrame.size.height] forKey:@"WindowSizeHeight"];
}

- (oneway void)setStoreIconShelf:(BOOL)set
{
	[self setIconShelf:set];
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSNumber numberWithBool:set] forKey:@"ShowIconShelf"];
}

- (oneway void)setStoreStatusBar:(BOOL)set
{
	[self setStatusBar:set];
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSNumber numberWithBool:set] forKey:@"ShowStatusBar"];
}

// NSComparisonMethods protocol
- (NSComparisonResult)identifierCompare:(StainlessWindow*)container
{
	return [identifier compare:[container identifier]];
}

@end
