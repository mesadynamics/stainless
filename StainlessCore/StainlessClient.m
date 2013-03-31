//
//  StainlessClient.m
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessClient.h"
#import "StainlessBridge.h"


@implementation StainlessClient

@synthesize url;
@synthesize title;
@synthesize identifier;
@synthesize group;
@synthesize session;
@synthesize key;
@synthesize container;
@synthesize icon;
@synthesize iconData;

@synthesize busy;
@synthesize isChild;

@synthesize hiPSN;
@synthesize loPSN;
@synthesize pid;

- (id)init
{
	if(self = [super init]) {
		proxy = nil;
		
		url = nil;
		title = nil;
		identifier = nil;
		group = nil;
		session = nil;
		key = nil;
		container = nil;
		icon = nil;
		iconData = nil;
		
		busy = NO;
		isChild = NO;
		
		hiPSN = 0;
		loPSN = 0;
		pid = 0;
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	if(self = [super init]) {
		proxy = nil;
		
		self.url = [decoder decodeObject];
		self.title = [decoder decodeObject];
		self.identifier = [decoder decodeObject];
		self.group = [decoder decodeObject];
		self.session = [decoder decodeObject];
		self.container = [decoder decodeObject];
		self.iconData = [decoder decodeObject];
	
		if(iconData) {
			NSImage* image = nil;
			
			@try {
				image = [[[NSImage alloc] initWithData:iconData] autorelease];
				[image setScalesWhenResized:YES];
				[image setSize:NSMakeSize(16.0, 16.0)];
				
				NSString* imageName = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
				[image setName:imageName];
			}
			
			@catch (NSException* anException) {
				image = nil;
			}			
			
			if(image)
				self.icon = image;
		}
		
		self.key = [NSString stringWithFormat:@"%X", [identifier globalHash]];
				
		busy = NO;
		isChild = NO;
		
		hiPSN = 0;
		loPSN = 0;
		pid = 0;
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:url];
	[encoder encodeObject:title];
	[encoder encodeObject:identifier];
	[encoder encodeObject:group];
	[encoder encodeObject:session];
	[encoder encodeObject:container];
	[encoder encodeObject:iconData];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[url release];
	[title release];
	[identifier release];
	[session release];
	[key release];
	[container release];
	[icon release];
	[iconData release];
	
	[super dealloc];
}

- (id)connection
{
	NSDistantObject* connection = nil;
	
	if(key)
		connection = proxy;
	
	if(connection == nil && identifier) {
		@try {
			connection = [NSConnection rootProxyForConnectionWithRegisteredName:identifier host:nil];
		}
		
		@catch (NSException* anException) {
			connection = nil;
		}
		
		if(connection) {			
			proxy = [connection retain];
			[proxy setProtocolForProxy:@protocol(StainlessClientProxy)];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disconnect:) name:@"NSConnectionDidDieNotification" object:[proxy connectionForProxy]];
			
			[self retain];
		}
	}
			
	return connection;
}

- (void)copyUrl:(bycopy NSString*)copy
{
	[self setUrl:[NSString stringWithString:copy]];
}

- (void)copyKey:(bycopy NSString*)copy
{
	[self setKey:[NSString stringWithString:copy]];
}

- (void)copyTitle:(bycopy NSString*)copy
{
	[self setTitle:[NSString stringWithString:copy]];
}

- (void)copyIcon:(NSImage*)copy
{
	@try {
		NSData* data = [copy TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:1.0];
		if(data) {
			NSImage* image = [[[NSImage alloc] initWithData:data] autorelease];
			[image setScalesWhenResized:YES];
			[image setSize:NSMakeSize(16.0, 16.0)];
			
			NSString* imageName = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
			[image setName:imageName];
			
			[self setIcon:image];
			[self setIconData:data];
		}
	}
	
	@catch (NSException* anException) {
	}
}

// Notifications
- (void)disconnect:(NSNotification*)aNotification
{
	[self setKey:nil];
			
	if(identifier) {
		NSString* clientIdentifier = [NSString stringWithString:identifier];
		[[NSApp delegate] performSelectorOnMainThread:@selector(handleClientDisconnect:) withObject:clientIdentifier waitUntilDone:NO];
	}

	if(proxy) {
		[proxy release];
		proxy = nil;
		
		[self autorelease];
	}
}

// NSComparisonMethods protocol
- (NSComparisonResult)pidCompare:(StainlessClient*)client
{
	if([client pid] > [self pid])
		return NSOrderedAscending;
	
	return NSOrderedDescending;
}

@end

