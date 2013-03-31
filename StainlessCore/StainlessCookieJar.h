//
//  StainlessCookieJar.h
//  StainlessCookies
//
//  Created by Danny Espinoza on 2/10/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface StainlessCookieJar : NSObject {
@private
	NSMutableDictionary* _cookies;
	NSMutableDictionary* _overrides;
#if defined(CacheCookies)	
	NSMutableDictionary* _cache;
#endif

@protected
	id cookieServer;
	NSHTTPCookieAcceptPolicy cookiePolicy;

	NSString* group;
	NSString* session;
}

@property(nonatomic, assign) id cookieServer;
@property NSHTTPCookieAcceptPolicy cookiePolicy;
@property(retain) NSString* group;
@property(retain) NSString* session;

+ (StainlessCookieJar *)sharedCookieJar;
+ (NSString*)domainForURLString:(NSString*)urlString;

- (void)overrideDomain:(NSString*)domain inGroup:(NSString*)inGroup inSession:(NSString*)inSession toSession:(NSString*)toSession;
- (void)copyDomain:(NSString*)domain inGroup:(NSString*)inGroup inSession:(NSString*)inSession toSession:(NSString*)toSession;

- (void)readCookiesFromPath:(NSString*)path;
- (void)writeCookiesToPath:(NSString*)path purge:(BOOL)purge;

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)theURL mainDocumentURL:(NSURL *)mainDocumentURL group:(NSString*)groupName session:(NSString*)sessionName;
- (NSArray *)cookiesForURL:(NSURL *)theURL group:(NSString*)groupname session:(NSString*)sessionName;

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)theURL mainDocumentURL:(NSURL *)mainDocumentURL;
- (NSArray *)cookiesForURL:(NSURL *)theURL;
- (void)deleteCookie:(NSHTTPCookie *)aCookie;
- (NSArray *)cookies;

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource;
- (void)webView:(WebView *)sender resource:(id)identifier didReceiveResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)dataSource;

@end


@protocol StainlessCookieServer

- (void)overrideDomain:(bycopy NSString*)domain inGroup:(bycopy NSString*)inGroup inSession:(bycopy NSString*)inSession toSession:(bycopy NSString*)toSession;
- (void)copyDomain:(bycopy NSString*)domain inGroup:(bycopy NSString*)inGroup inSession:(bycopy NSString*)inSession toSession:(bycopy NSString*)toSession;
- (void)setCookies:(NSArray *)cookies forURL:(bycopy NSURL *)theURL mainDocumentURL:(bycopy NSURL *)mainDocumentURL group:(bycopy NSString*)groupName session:(bycopy NSString*)sessionName;
- (NSArray *)cookiesForURL:(bycopy NSURL *)theURL group:(bycopy NSString*)groupName session:(bycopy NSString*)sessionName;

@end


@protocol WebPanelAuthenticationHandler
- (void)startAuthentication:(NSURLAuthenticationChallenge *)challenge window:(NSWindow *)w;
- (void)cancelAuthentication:(NSURLAuthenticationChallenge *)challenge;
@end
