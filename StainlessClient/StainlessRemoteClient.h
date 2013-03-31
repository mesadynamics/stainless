//
//  StainlessRemoteClient.h
//  StainlessClient
//
//  Created by Danny Espinoza on 10/23/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface StainlessRemoteClient : NSObject {
	WebView* webView;
	
	NSString* urlString;
	NSString* identifier;
	
	BOOL spawnOnNavigate;
}

- (WebView*)webView;

@property(retain) NSString* urlString;
@property(retain) NSString* identifier;

@end
