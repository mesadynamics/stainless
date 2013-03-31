//
//  StainlessCookieJar.m
//  StainlessCookies
//
//  Created by Danny Espinoza on 2/10/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessCookieJar.h"
#import "StainlessCookieStorage.h"


@implementation StainlessCookieJar

@synthesize cookieServer;
@synthesize cookiePolicy;
@synthesize group;
@synthesize session;

+ (StainlessCookieJar *)sharedCookieJar
{
	static StainlessCookieJar* cookieJarInstance = nil;
	
	if(cookieJarInstance == nil)
		cookieJarInstance = [[StainlessCookieJar alloc] init];
	
	return cookieJarInstance;
}

+ (NSString*)_domainFromHost:(NSString*)host
{
	NSString* domain = host;
	
	NSArray* domains = [host componentsSeparatedByString:@"."];
	int domainCount = [domains count];
	if(domainCount >= 2)
		domain = [NSString stringWithFormat:@"%@.%@", [domains objectAtIndex:domainCount - 2], [domains objectAtIndex:domainCount - 1]];
	
	return domain;
}

+ (NSString*)domainForURLString:(NSString*)urlString
{
	NSURL* url = [NSURL URLWithString:urlString];
	if(url)
		return [StainlessCookieJar _domainFromHost:[url host]];
	
	return nil;
}

- (NSString*)_domainKeyFromHost:(NSString*)host group:(NSString*)groupName session:(NSString*)sessionName
{
	if(sessionName == nil)
		sessionName = @"default";
	
	NSString* urlDomain = [StainlessCookieJar _domainFromHost:host];
		
	NSMutableDictionary* sessionOverrides = [_overrides objectForKey:groupName];
	if(sessionOverrides) {		
		NSString* newSessionName = [sessionOverrides objectForKey:urlDomain];
		if(newSessionName)
			sessionName = newSessionName;
	}

	return [NSString stringWithFormat:@"[%@]%@", sessionName, urlDomain];
}

- (void)overrideDomain:(NSString*)domain inGroup:(NSString*)inGroup inSession:(NSString*)inSession toSession:(NSString*)toSession
{	
	if(cookieServer) {
		@try {
			[cookieServer overrideDomain:domain inGroup:inGroup inSession:inSession toSession:toSession];
		}
		
		@catch (NSException* anException) {
		}
		
		return;
	}
	
	NSMutableDictionary* sessionOverrides = [_overrides objectForKey:inGroup];
	if(sessionOverrides == nil) {
		if([inSession isEqualToString:toSession])
			return;

		sessionOverrides = [[NSMutableDictionary alloc] initWithCapacity:1];
		[_overrides setObject:sessionOverrides forKey:inGroup];
		[sessionOverrides release];
	}
	
	if([inSession isEqualToString:toSession]) {
		[sessionOverrides removeObjectForKey:domain];
		
		if([sessionOverrides count] == 0)
			[_overrides removeObjectForKey:inGroup];
	}
	else
		[sessionOverrides setObject:toSession forKey:domain];
}

- (void)copyDomain:(NSString*)domain inGroup:(NSString*)inGroup inSession:(NSString*)inSession toSession:(NSString*)toSession
{	
	if(cookieServer) {
		@try {
			[cookieServer copyDomain:domain inGroup:inGroup inSession:inSession toSession:toSession];
		}
		
		@catch (NSException* anException) {
		}
		
		return;
	}
	
	NSString* domainKey = [self _domainKeyFromHost:domain group:inGroup session:inSession];
	NSMutableDictionary* cookieJarForDomain = [_cookies objectForKey:domainKey];
	if(cookieJarForDomain == nil)
		return;
	
	NSArray* cookies = [cookieJarForDomain allValues];
	if(cookies == nil || [cookies count] == 0)
		return;

	NSString* copyKey = [NSString stringWithFormat:@"[%@]%@", toSession, domain];
	NSMutableDictionary* cookieJarForCopy = [_cookies objectForKey:copyKey];
	if(cookieJarForCopy == nil) {
		cookieJarForCopy = [[NSMutableDictionary alloc] initWithCapacity:[cookies count]];
		[_cookies setObject:cookieJarForCopy forKey:copyKey];
		[cookieJarForCopy release];
	}
	else
		NSLog(@"unexpected cookie namespace collision: %@", copyKey);
	
	for(NSHTTPCookie* cookie in cookies) {
		NSString* name = [cookie name];
		NSString* domain = [cookie domain];
		NSString* path = [cookie path];
		
		NSString* key = [NSString stringWithFormat:@"%@\\%@\\%@", name, domain, path];
		[cookieJarForCopy setObject:[cookie copy] forKey:key];
	}
}	

- (id)init
{
	if(self = [super init]) {
		_cookies = [[NSMutableDictionary alloc] init];
		_overrides = [[NSMutableDictionary alloc] init];
#if defined(CacheCookies)	
		_cache = [[NSMutableDictionary alloc] init];
#endif		
		
		self.cookiePolicy = NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain;
		
		group = nil;
		session = nil;
	}
	
	return self;
}

- (void)dealloc
{
#if defined(CacheCookies)	
	[_cache release];
#endif
	[_cookies release];
	[_overrides release];
	
	[group release];
	[session release];
	
	[super dealloc];
}

- (void)readCookiesFromPath:(NSString*)path
{
	@try {
		id plist = nil;
		
		if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
			NSString* error = nil;
			NSData* data = [NSData dataWithContentsOfFile:path];
			plist = [NSPropertyListSerialization propertyListFromData:data
													 mutabilityOption:NSPropertyListMutableContainersAndLeaves
															   format:nil
													 errorDescription:&error];
			
			if(error) {
				NSLog(@"Error deserializing %@: %@", path, error);
				[error release];
				
				plist = nil;
			}
		}
		
		if(plist) {
			for(NSString* key in [plist allKeys]) {
				NSMutableArray* plistJar = [plist objectForKey:key];
				NSMutableDictionary* cookieJarForDomain = [NSMutableDictionary dictionaryWithCapacity:[plistJar count]];
				
				for(NSDictionary* properties in plistJar) {
					NSHTTPCookie* cookie = [NSHTTPCookie cookieWithProperties:properties];
					if(cookie) {
						NSString* name = [cookie name];
						NSString* domain = [cookie domain];
						NSString* path = [cookie path];
						
						NSString* key = [NSString stringWithFormat:@"%@\\%@\\%@", name, domain, path];
						[cookieJarForDomain setObject:cookie forKey:key];
					}
				}
				
				[_cookies setObject:cookieJarForDomain forKey:key];
			}
		}
	}
	
	@catch (NSException* anException) {
		NSLog(@"%@ exception reading %@: %@", [anException name], path, [anException reason]);
	}
}

- (NSArray*)_bookmarkSessions
{
	NSMutableArray* sessionList = [NSMutableArray array];

	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* libraryPath = [NSString stringWithFormat:@"%@/Library/Preferences/Stainless", NSHomeDirectory()];
	if([fm fileExistsAtPath:libraryPath] == NO) {
		[fm createDirectoryAtPath:libraryPath attributes:nil];
		return sessionList;
	}
	
	NSString* path = [NSString stringWithFormat:@"%@/Shelf.plist", libraryPath];
	if([fm fileExistsAtPath:path] == NO)
		return sessionList;

	@try {
		id plist = nil;
		
		if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
			NSString* error = nil;
			NSData* data = [NSData dataWithContentsOfFile:path];
			plist = [NSPropertyListSerialization propertyListFromData:data
													 mutabilityOption:NSPropertyListMutableContainersAndLeaves
															   format:nil
													 errorDescription:&error];
			
			if(error) {
				NSLog(@"Error deserializing %@: %@", path, error);
				[error release];
				
				plist = nil;
			}
		}
		
		if(plist) {
			for(NSMutableDictionary* bookmarkInfo in plist) {
				NSString* bookmarkDomain = [bookmarkInfo objectForKey:@"domain"];
				NSString* bookmarkSession = [bookmarkInfo objectForKey:@"session"];
				if(bookmarkDomain && bookmarkSession) {
					NSString* cookies = [NSString stringWithFormat:@"[%@]%@", bookmarkSession, bookmarkDomain];
					[sessionList addObject:cookies];
				}
			}
		}
	}

	@catch (NSException* anException) {
		NSLog(@"%@ exception reading %@: %@", [anException name], path, [anException reason]);
	}
	
	return sessionList;
}

- (void)writeCookiesToPath:(NSString*)path purge:(BOOL)purge
{
	NSArray* sessionList = [self _bookmarkSessions];
		
	@try {
		NSMutableDictionary* plist = [NSMutableDictionary dictionaryWithCapacity:[_cookies count]];
		
		NSDate* now = [NSDate date];

		for(NSString* key in [_cookies allKeys]) {
			BOOL skip = purge;
			
			if([key hasPrefix:@"[private]"])
				skip = YES;
				
			if([key hasPrefix:@"[default]"]) {
				if(purge && [sessionList containsObject:key])
					skip = NO;
			}
			else {
				if([sessionList containsObject:key])
					skip = NO;
				else
					skip = YES;
			}
			
			NSMutableDictionary* cookieJarForDomain = [_cookies objectForKey:key];
			int count = [cookieJarForDomain count];
			if(count == 0)
				skip = YES;
			
			if(skip)
				continue;
			
			count = 0;
			
			NSMutableArray* jar = [NSMutableArray arrayWithCapacity:count];
			
			for(NSHTTPCookie* cookie in [cookieJarForDomain allValues]) {
				BOOL expired = [cookie isSessionOnly];
				
				if(expired == NO) {
					NSDate* then = [cookie expiresDate];
					if(then && [now compare:then] == NSOrderedDescending)
						expired = YES;
				}
				
				if(expired == NO) {
					count++;
					[jar addObject:[cookie properties]];
				}
			}
				
			if(count)
				[plist setObject:jar forKey:key];
		}
				
		NSString* error = nil;
		NSData* data = [NSPropertyListSerialization dataFromPropertyList:plist format:kCFPropertyListBinaryFormat_v1_0 errorDescription:&error];
		
		if(error) {
			NSLog(@"Error serializing write %@: %@", path, error);
			[error release];
			
			data = nil;
		}
		
		if(data) {
			if([data writeToFile:path atomically:YES] == NO)
				NSLog(@"Error writing %@.", path);
		}	
	}

	@catch (NSException* anException) {
		NSLog(@"%@ exception writing %@: %@", [anException name], path, [anException reason]);
	}
}

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)theURL mainDocumentURL:(NSURL *)mainDocumentURL group:(NSString*)groupName session:(NSString*)sessionName
{					
	NSString* urlHost = [theURL host];
		
	if(cookiePolicy == NSHTTPCookieAcceptPolicyNever) {
		return;
	}
	else if(cookiePolicy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain && mainDocumentURL) {
		NSString* pageDomain = [StainlessCookieJar _domainFromHost:[mainDocumentURL host]];
		NSString* urlDomain = [StainlessCookieJar _domainFromHost:urlHost];
		
		if([pageDomain isEqualToString:urlDomain] == NO)
			return;
	}
	
	if(cookieServer) {
		@try {
			[cookieServer setCookies:cookies forURL:theURL mainDocumentURL:nil group:group session:session];
		}
		
		@catch (NSException* anException) {
		}
		
		return;
	}
	
	NSString* domainKey = [self _domainKeyFromHost:urlHost group:groupName session:sessionName];
	
	NSMutableDictionary* cookieJarForDomain = [_cookies objectForKey:domainKey];
	if(cookieJarForDomain == nil) {
		cookieJarForDomain = [[NSMutableDictionary alloc] initWithCapacity:[cookies count]];
		[_cookies setObject:cookieJarForDomain forKey:domainKey];
		[cookieJarForDomain release];
	}
	
	for(NSHTTPCookie* cookie in cookies) {
		NSString* name = [cookie name];
		NSString* domain = [cookie domain];
		NSString* path = [cookie path];
		
		NSString* key = [NSString stringWithFormat:@"%@\\%@\\%@", name, domain, path];
		[cookieJarForDomain setObject:cookie forKey:key];
	}
	
	//NSLog(@"%d cookie jars, %d sites in %@", [_cookies count], [cookieJarForDomain count], domainKey);
	
#if defined(CacheCookies)	
	[_cache removeObjectForKey:domainKey];
#endif
}

- (NSArray *)cookiesForURL:(NSURL *)theURL group:(NSString*)groupName session:(NSString*)sessionName
{		
	if(cookieServer) {
		NSArray* localCookies = nil;
		
		@try {
			//NSConnection* c = [cookieServer connectionForProxy];
			//NSLog(@"%@", [c localObjects]);
			
			NSArray* remoteCookies = [cookieServer cookiesForURL:theURL group:group session:session];
			localCookies = [[NSArray alloc] initWithArray:remoteCookies copyItems:YES];
		}
		
		@catch (NSException* anException) {
			localCookies = [[NSArray alloc] init];
			
		}
		
		return [localCookies autorelease];
	}

	NSString* urlScheme = [theURL scheme];
	NSString* urlHost = [theURL host];
	NSNumber* urlPort = [theURL port];
	NSString* urlPath = [theURL path];
	
	NSString* domainKey = [self _domainKeyFromHost:urlHost group:groupName session:sessionName];
#if defined(CacheCookies)	
	NSMutableString* cacheKey = [NSMutableString stringWithFormat:@"%@://%@", urlScheme, urlHost];
	if(urlPort)
		[cacheKey appendFormat:@":%d%@", [urlPort intValue], [urlPath stringByDeletingLastPathComponent]];
	else
		[cacheKey appendFormat:@"%@", [urlPath stringByDeletingLastPathComponent]];
		
	NSMutableDictionary* cacheForDomain = [_cache objectForKey:domainKey];
	if(cacheForDomain) {
		NSMutableArray* cookies = [cacheForDomain objectForKey:cacheKey];
		if(cookies) {
			BOOL expired = NO;
			
			NSDate* then = [cacheForDomain objectForKey:@"Expiration"];
			if(then) {
				NSDate* now = [NSDate date];
				if([now compare:then] != NSOrderedDescending)
					expired = NO;
				else
					expired = YES;
			}
			
			if(expired)
				[_cache removeObjectForKey:domainKey];		
			else
				return cookies;
		}
	}
#endif
	
#if defined(CacheCookies)	
	NSDate* cacheExpiration = nil;
#endif
	NSMutableArray* expiredCookies = nil;
	NSMutableArray* cookies = [[NSMutableArray alloc] init];
	
	NSMutableDictionary* cookieJarForDomain = [_cookies objectForKey:domainKey];	
	if(cookieJarForDomain) {
		for(NSHTTPCookie* cookie in [cookieJarForDomain allValues]) {
			BOOL matchDomain = NO;
			
			NSString* domain = [cookie domain];
			if([domain hasPrefix:@"."]) {
				NSString* cleanDomain = [domain substringFromIndex:1];
				if([urlHost isEqualToString:cleanDomain])
					matchDomain = YES;
				else if([urlHost hasSuffix:domain])
					matchDomain = YES;
			}
			else {
				if([urlHost isEqualToString:domain])
					matchDomain = YES;
			}
			
			if(matchDomain == NO)
				continue;
			
			if([cookie isSecure] && [urlScheme isEqualToString:@"https"] == NO)
				continue;
						
			if(urlPort) {
				NSArray* ports = [cookie portList];
				if(ports && [ports containsObject:urlPort] == NO) {
					continue;
				}
			}
			
			NSString* path = [cookie path];
			
			if([urlPath hasPrefix:path]) {
				BOOL expired = NO;
				
				NSDate* then = [cookie expiresDate];
				if(then) {
					NSDate* now = [NSDate date];
					if([now compare:then] != NSOrderedDescending)
						expired = NO;
					else
						expired = YES;
				}
				
				if(expired == NO) {
#if defined(CacheCookies)	
					if(then && (cacheExpiration == nil || [cacheExpiration compare:then] == NSOrderedDescending))
#endif						cacheExpiration = then;
					
					[cookies addObject:cookie];
				}
				else {
					if(expiredCookies == nil)
						expiredCookies = [NSMutableArray arrayWithCapacity:1];
					
					NSString* name = [cookie name];
					NSString* key = [NSString stringWithFormat:@"%@\\%@\\%@", name, domain, path];
					[expiredCookies addObject:key];
				}
			}
		}
	}
	
	if(expiredCookies) {
		for(NSString* key in expiredCookies)
			[cookieJarForDomain removeObjectForKey:key];
	}
	
	
#if defined(CacheCookies)	
	if(cacheForDomain == nil) {
		cacheForDomain = [[NSMutableDictionary alloc] initWithCapacity:1];
		[_cache setObject:cacheForDomain forKey:domainKey];
		[cacheForDomain release];
	}
		
	[cacheForDomain setObject:cookies forKey:cacheKey];
	if(cacheExpiration)
		[cacheForDomain setObject:cacheExpiration forKey:@"Expiration"];
#endif
		
	return [cookies autorelease];
}

// NSHTTPCookieStorage (informal)
- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)theURL mainDocumentURL:(NSURL *)mainDocumentURL
{
	[self setCookies:cookies forURL:theURL mainDocumentURL:mainDocumentURL group:group session:session];
}

- (NSArray *)cookiesForURL:(NSURL *)theURL
{
	return [self cookiesForURL:theURL group:group session:session];
}

- (void)deleteCookie:(NSHTTPCookie *)aCookie
{
	for(NSMutableDictionary* cookieJarForDomain in [_cookies allValues]) {
		NSArray* keys = [cookieJarForDomain allKeysForObject:aCookie];
		if([keys count])
			[cookieJarForDomain removeObjectForKey:[keys objectAtIndex:0]];
	}
}

- (NSArray *)cookies
{
	NSMutableArray* cookies = [[NSMutableArray alloc] init];
	
	for(NSMutableDictionary* cookieJarForDomain in [_cookies allValues]) {
		for(NSHTTPCookie* cookie in [cookieJarForDomain allValues])
			[cookies addObject:cookie];
	}
	
	return [cookies autorelease];
}

// Private methods
- (void)_pullCookiesFromResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)dataSource
{
	NSURL* url = [response URL];

	if(url && [response respondsToSelector:@selector(allHeaderFields)]) {
		NSArray* cookiesIn = [NSHTTPCookie cookiesWithResponseHeaderFields:[(id)response allHeaderFields] forURL:url];
		
		if([cookiesIn count])
			[self setCookies:cookiesIn forURL:url mainDocumentURL:[[dataSource request] URL]];
	}
}

- (void)_pushCookiesToMutableRequest:(NSMutableURLRequest*)mutableRequest fromDataSource:(WebDataSource *)dataSource
{
	[mutableRequest setHTTPShouldHandleCookies:NO];
	
	NSURL* url = [mutableRequest URL];
	if(url && [url host]) {
		NSArray* cookiesOut = [self cookiesForURL:url];
		if([cookiesOut count]) {
			NSDictionary* headerFields = [NSHTTPCookie requestHeaderFieldsWithCookies:cookiesOut];
			
			for(NSString* key in [headerFields keyEnumerator])
				[mutableRequest setValue:[headerFields objectForKey:key] forHTTPHeaderField:key];
		}
	}
}

// WebResourceLoadDelegate
- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
	if(redirectResponse)
		[self _pullCookiesFromResponse:redirectResponse fromDataSource:dataSource];
		
	NSMutableURLRequest* mutableRequest = [request mutableCopy];
	[self _pushCookiesToMutableRequest:mutableRequest fromDataSource:dataSource];
					
	return mutableRequest;
}

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)dataSource
{
	[self _pullCookiesFromResponse:response fromDataSource:dataSource];
}

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource
{
	NSURLResponse* response = [challenge failureResponse];
	if(response)
		[self _pullCookiesFromResponse:response fromDataSource:dataSource];
	
	// todo: push cookies to this challenge
	
	@try {
		Class webAuthenticationClass = NSClassFromString(@"WebPanelAuthenticationHandler");
		if(webAuthenticationClass) {
			id authenticationHandler = [webAuthenticationClass performSelector:@selector(sharedHandler)];
			
			NSWindow* window = [sender hostWindow] ? [sender hostWindow] : [sender window]; 
			[authenticationHandler startAuthentication:challenge window:window];
		}
	}
	
	@catch (NSException* anException) {
	}	
}

- (void)webView:(WebView *)sender resource:(id)identifier didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource
{
	@try {
		Class webAuthenticationClass = NSClassFromString(@"WebPanelAuthenticationHandler");
		if(webAuthenticationClass) {
			id authenticationHandler = [webAuthenticationClass performSelector:@selector(sharedHandler)];
			[authenticationHandler cancelAuthentication:challenge];
		}
	}
	
	@catch (NSException* anException) {
	}	
}

@end

