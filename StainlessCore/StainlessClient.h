//
//  StainlessClient.h
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface StainlessClient : NSObject {
	id proxy;
	
	NSString* url;
	NSString* title;
	NSString* identifier;
	NSString* group;
	NSString* session;
	NSString* key;
	NSString* container;
	NSImage* icon;
	NSData* iconData;
	
	BOOL busy;
	BOOL isChild;
	
	unsigned long hiPSN;
	unsigned long loPSN;
	pid_t pid;
}

@property(retain) NSString* url;
@property(retain) NSString* title;
@property(retain) NSString* identifier;
@property(retain) NSString* group;
@property(retain) NSString* session;
@property(retain) NSString* key;
@property(retain) NSString* container;
@property(retain) NSImage* icon;
@property(retain) NSData* iconData;

@property BOOL busy;
@property BOOL isChild;

@property unsigned long hiPSN;
@property unsigned long loPSN;
@property pid_t pid;

- (id)connection;

- (void)copyUrl:(bycopy NSString*)copy;
- (void)copyKey:(bycopy NSString*)copy;
- (void)copyTitle:(bycopy NSString*)copy;
- (void)copyIcon:(NSImage*)copy;

- (NSComparisonResult)pidCompare:(StainlessClient*)client;

@end
