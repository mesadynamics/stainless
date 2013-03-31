//
//  StainlessCookieStorage.m
//  StainlessCookies
//
//  Created by Danny Espinoza on 2/10/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessCookieStorage.h"
#import "StainlessCookieJar.h"


@implementation NSHTTPCookieStorage (Stainless)

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)theURL mainDocumentURL:(NSURL *)mainDocumentURL
{	
	[[StainlessCookieJar sharedCookieJar] setCookies:cookies forURL:theURL mainDocumentURL:mainDocumentURL];
}

- (NSArray *)cookiesForURL:(NSURL *)theURL
{
	return [[StainlessCookieJar sharedCookieJar] cookiesForURL:theURL];
}

- (NSHTTPCookieAcceptPolicy)cookieAcceptPolicy
{

	return [[StainlessCookieJar sharedCookieJar] cookiePolicy];
}

- (void)setCookieAcceptPolicy:(NSHTTPCookieAcceptPolicy)aPolicy
{
	[[StainlessCookieJar sharedCookieJar] setCookiePolicy:aPolicy];
}

- (void)setCookie:(NSHTTPCookie *)aCookie
{
	// StainlessCookieStorage only supports cookie setting via setCookies:forURL:mainDocumentURL
}

- (void)deleteCookie:(NSHTTPCookie *)aCookie
{
	[[StainlessCookieJar sharedCookieJar] deleteCookie:aCookie];
}

- (NSArray *)cookies
{
	return [[StainlessCookieJar sharedCookieJar] cookies];
}

@end


@implementation NSHTTPCookie (Stainless)

- (id)copyWithZone:(NSZone *)zone
{
	// should be implemented according to Apple docs (but it's not)
	return [[NSHTTPCookie allocWithZone:zone] initWithProperties:[self properties]];
}

@end
