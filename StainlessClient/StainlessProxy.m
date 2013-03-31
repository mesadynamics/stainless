//
//  StainlessProxy.m
//  StainlessClient
//
//  Created by Danny Espinoza on 1/29/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessProxy.h"


@implementation StainlessProxy

@synthesize controller;

- (oneway void)registerClient:(bycopy NSString*)clientKey
{
	NSString* arg = [NSString stringWithString:clientKey];
	[controller performSelectorOnMainThread:@selector(_registerClient:) withObject:arg waitUntilDone:NO];
}

- (oneway void)updateClientWithIdentifier:(bycopy NSString*)clientIdentifier
{
	NSString* arg = [NSString stringWithString:clientIdentifier];
	[controller performSelectorOnMainThread:@selector(_updateClientWithIdentifier:) withObject:arg waitUntilDone:NO];
}

- (oneway void)notifyClientWithIdentifier:(bycopy NSString*)clientIdentifier
{
	NSString* arg = [NSString stringWithString:clientIdentifier];
	[controller performSelectorOnMainThread:@selector(_notifyClientWithIdentifier:) withObject:arg waitUntilDone:NO];
}

- (BOOL)activateClientAndBringToFront:(BOOL)bringToFront withAttributes:(NSDictionary*)attributes siblings:(NSArray*)clientList
{
	NSMutableDictionary* arg = [[[NSMutableDictionary alloc] initWithDictionary:attributes copyItems:YES] autorelease];
	[arg setObject:[[[NSArray alloc] initWithArray:clientList copyItems:YES] autorelease] forKey:@"ClientList"];
	
	if(bringToFront) {
		ProcessSerialNumber clientProcess = { 0, kCurrentProcess };
		ProcessSerialNumber frontProcess;
		GetFrontProcess(&frontProcess);
		
		Boolean result;
		SameProcess(&frontProcess, &clientProcess, &result);
		if(result == false) {
			[controller performSelectorOnMainThread:@selector(_activateClientFront:) withObject:arg waitUntilDone:NO];			
			return NO;
		}
	}

	[controller performSelectorOnMainThread:@selector(_activateClient:) withObject:arg waitUntilDone:NO];
	return YES;
}

- (oneway void)deactivateClient
{
	[controller performSelectorOnMainThread:@selector(_deactivateClient) withObject:nil waitUntilDone:NO];
}

- (oneway void)reactivateClient
{
	ProcessSerialNumber clientProcess = { 0, kCurrentProcess };
	ProcessSerialNumber frontProcess;
	GetFrontProcess(&frontProcess);
	
	Boolean result;
	SameProcess(&frontProcess, &clientProcess, &result);
	if(result == false) {
		[controller performSelectorOnMainThread:@selector(_reactivateClient) withObject:nil waitUntilDone:NO];
	}
}

- (oneway void)refreshClient:(bycopy NSString*)message
{
	NSString* arg = [NSString stringWithString:message];
	[controller performSelectorOnMainThread:@selector(_refreshClient:) withObject:arg waitUntilDone:NO];
}

- (oneway void)closeClient
{
	[controller performSelectorOnMainThread:@selector(_closeClient) withObject:nil waitUntilDone:NO];
}

- (oneway void)freezeClient:(BOOL)freeze
{
	NSNumber* arg = [NSNumber numberWithBool:freeze];
	[controller performSelectorOnMainThread:@selector(_freezeClient:) withObject:arg waitUntilDone:NO];
}

- (oneway void)hideClient:(BOOL)hide
{
	NSNumber* arg = [NSNumber numberWithBool:hide];
	[controller performSelectorOnMainThread:@selector(_hideClient:) withObject:arg waitUntilDone:NO];
}

- (oneway void)redirectClient:(bycopy NSString*)urlString
{
	NSString* arg = [NSString stringWithString:urlString];
	[controller performSelectorOnMainThread:@selector(_redirectClient:) withObject:arg waitUntilDone:NO];
}

- (oneway void)permitClient:(bycopy NSString*)host
{
	NSString* arg = [NSString stringWithString:host];
	[controller performSelectorOnMainThread:@selector(_permitClient:) withObject:arg waitUntilDone:NO];
}

- (oneway void)resizeClient:(NSRect)frame
{
	NSValue* arg = [NSValue valueWithRect:frame];
	[controller performSelectorOnMainThread:@selector(_resizeClient:) withObject:arg waitUntilDone:NO];
}

- (oneway void)serverToClientCommand:(bycopy NSString*)command
{
	NSString* arg = [NSString stringWithString:command];
	[controller performSelectorOnMainThread:@selector(_serverToClientCommand:) withObject:arg waitUntilDone:NO];
}

// 0.8
- (oneway void)cancelDownloadForClient:(bycopy NSString*)downloadStamp
{
	NSString* arg = [NSString stringWithString:downloadStamp];
	[controller performSelectorOnMainThread:@selector(_cancelDownloadForClient:) withObject:arg waitUntilDone:NO];
}

@end
