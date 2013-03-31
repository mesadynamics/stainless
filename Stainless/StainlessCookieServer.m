//
//  StainlessCookieServer.m
//  Stainless
//
//  Created by Danny Espinoza on 3/12/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessCookieServer.h"


@implementation StainlessCookieServer

// StainlessCookieServer protocol
- (void)overrideDomain:(bycopy NSString*)domain inGroup:(bycopy NSString*)inGroup inSession:(bycopy NSString*)inSession toSession:(bycopy NSString*)toSession
{
	[[StainlessCookieJar sharedCookieJar] overrideDomain:domain inGroup:inGroup inSession:inSession toSession:toSession];
}

- (void)copyDomain:(bycopy NSString*)domain inGroup:(bycopy NSString*)inGroup inSession:(bycopy NSString*)inSession toSession:(bycopy NSString*)toSession
{
	[[StainlessCookieJar sharedCookieJar] copyDomain:domain inGroup:inGroup inSession:inSession toSession:toSession];
}

- (void)setCookies:(NSArray *)cookies forURL:(bycopy NSURL *)theURL mainDocumentURL:(bycopy NSURL *)mainDocumentURL group:(bycopy NSString*)groupName session:(bycopy NSString*)sessionName
{
	NSArray* localCookies = [[[NSArray alloc] initWithArray:cookies copyItems:YES] autorelease];
	[[StainlessCookieJar sharedCookieJar] setCookies:localCookies forURL:theURL mainDocumentURL:mainDocumentURL group:groupName session:sessionName];
}

- (NSArray *)cookiesForURL:(bycopy NSURL *)theURL group:(bycopy NSString*)groupName session:(bycopy NSString*)sessionName
{
	return [[StainlessCookieJar sharedCookieJar] cookiesForURL:theURL group:groupName session:sessionName];
}

@end
