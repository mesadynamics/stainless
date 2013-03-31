//
//  StainlessBrowser.h
//  StainlessClient
//
//  Created by Danny Espinoza on 9/11/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface StainlessBrowser : WebView {
	BOOL isReady;
	BOOL isSearching;
	BOOL isViewingSource;
	
	NSString* version;
}

@property BOOL isReady;
@property BOOL isSearching;

- (IBAction)zoomOut:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)resetZoom:(id)sender;
- (IBAction)takeStringRequestFrom:(id)sender;
- (IBAction)toggleViewSource:(id)sender;
- (IBAction)toggleFullScreen:(id)sender;
- (IBAction)toggleWebInspector:(id)sender;

- (NSString*)requestStringToURL:(NSString*)requestString sender:(id)sender;

- (void)setupPreferences:(BOOL)privateMode;
- (NSRect)clippedDocumentFrame;

- (void)readSafariBookmarksFromPath:(NSString*)path filter:(NSString*)filter;
- (void)parseSafariList:(NSDictionary*)plist toHTML:(NSMutableString*)html filter:(NSString*)filter;

@end


@interface WebPreferences (WebPrivate)
- (void)setTextAreasAreResizable:(BOOL)flag;
- (void)setDeveloperExtrasEnabled:(BOOL)flag;
- (void)setZoomsTextOnly:(BOOL)zoomsTextOnly;
- (void)setWebSecurityEnabled:(BOOL)flag;
@end


@protocol WebInspectorProtocol
- (void)show:(id)sender;
@end


@interface WebView (WebPrivate)
- (id<WebInspectorProtocol>)inspector;

+ (BOOL)_canHandleRequest:(NSURLRequest *)request forMainFrame:(BOOL)forMainFrame;
- (void)_setInViewSourceMode:(BOOL)flag;

- (IBAction)_zoomOut:(id)sender isTextOnly:(BOOL)isTextOnly;
- (IBAction)_zoomIn:(id)sender isTextOnly:(BOOL)isTextOnly;
- (IBAction)_resetZoom:(id)sender isTextOnly:(BOOL)isTextOnly;
@end


@interface WebFrame (WebPrivate)
- (void)reloadFromOrigin;
- (NSString *)_stringByEvaluatingJavaScriptFromString:(NSString *)string forceUserGesture:(BOOL)forceUserGesture; // Safari4
@end


@interface NSResponder (SnowLeopard)
- (void)swipeWithEvent:(NSEvent *)event;
@end

