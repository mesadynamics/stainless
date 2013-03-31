//
//  StainlessController.h
//  StainlessClient
//
//  Created by Danny Espinoza on 9/5/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "StainlessClient.h"
#import "StainlessWindow.h"
#import "StainlessBarView.h"
#import "StainlessRemoteClient.h"
#import "StainlessShelfView.h"
#import "BookmarkView.h"
#import "FadingLabel.h"
#import "InspectorView.h"
#import "SmartBar.h"

#import "MAAttachedWindow.h"


@interface StainlessController : NSWindowController {
	IBOutlet WebView* webView;
	IBOutlet NSObjectController* webViewController;
	IBOutlet NSSegmentedControl* backForwardToggle;
	IBOutlet NSSegmentedControl* backForwardSearch;
	IBOutlet StainlessBarView* bar;
	IBOutlet NSTextField* query;
	IBOutlet NSTextField* status;
	IBOutlet NSTextField* results;
	IBOutlet NSButton* home;
	IBOutlet NSSearchField* search;
	IBOutlet NSView* navBar;
	IBOutlet NSView* searchBar;
	IBOutlet StainlessShelfView* iconShelf;
	IBOutlet InspectorView* iconEditor;
	IBOutlet NSPanel* overlay;
	IBOutlet FadingLabel* statusLabel;
	IBOutlet NSView* completionView;
	IBOutlet SmartBar* smartBar;
	
	NSConnection* port;
	id proxy;
	NSString* identifier;
	NSString* group;
	NSString* session;
	ProcessSerialNumber clientProcess;
	ProcessSerialNumber serverProcess;
	pid_t clientPid;
	NSInteger clientWid;
	
	int workspace;
	int syncspace;
	
	NSString* saveQuery;
	NSString* lastQuery;
	NSString* nextTitle;
	NSString* nextBookmark;
	
	NSString* lastSearch;
	int searchIndex;
	int searchCount;
	DOMRange* searchRange;
	NSRect searchRect;

	BOOL restoreWebFocus;
	BOOL syncOnActivate;
	BOOL ignoreActivation;
	//BOOL ignoreLayering;
	BOOL ignoreDisconnect;
	BOOL ignoreSearch;
	BOOL ignoreSync;
	
	BOOL saveFrameOnDeactivate;
	BOOL ignoreResize;
	BOOL ignoreModifiers;
	BOOL searchMode;
	BOOL firstSearch;
		
	NSMutableDictionary* trackedClients;
	NSString* mouseNode;
	
	NSURLRequest* securityRequest;
	NSString* securityHost;
	NSString* securityError;
	
	BOOL webViewCanCheckRequests;
	
	NSMutableDictionary* downloads;
	NSMutableDictionary* handlers;
	NSMutableDictionary* paths;
	
	BOOL autoClose;
	BOOL autoShow;
	BOOL autoHide;
	
	MAAttachedWindow* completion;
	NSArray* completionArray;
	NSString* completionString;
	
	// 0.8
	NSMutableDictionary* pageTitles;
}

@property(nonatomic, retain) StainlessBarView* bar;
@property(nonatomic, retain) StainlessShelfView* iconShelf;
@property(nonatomic, retain) MAAttachedWindow* completion;

@property(retain) NSString* identifier;
@property(retain) NSString* group;
@property(retain) NSString* session;
@property(nonatomic, retain) NSString* mouseNode;
@property(nonatomic, retain) NSArray* completionArray;
@property(nonatomic, retain) NSString* completionString;
@property(retain) NSURLRequest* securityRequest;
@property(retain) NSString* securityHost;
@property(retain) NSString* securityError;
@property pid_t clientPid;
@property BOOL ignoreSync;

- (void)mouseDownInProcess:(BOOL)force;
- (void)renderProcess;
- (void)activateProcess;
- (void)updateClientIfHidden;

- (IBAction)performCommand:(id)sender;
- (IBAction)terminate:(id)sender;
- (IBAction)clickToggle:(id)sender;
- (IBAction)clickDirection:(id)sender;
- (IBAction)closeTabOrWindow:(id)sender;
- (IBAction)goHome:(id)sender;
- (IBAction)nextTab:(id)sender;
- (IBAction)previousTab:(id)sender;
- (IBAction)gotoTab:(id)sender;
- (IBAction)nextWindow:(id)sender;
- (IBAction)previousWindow:(id)sender;
- (IBAction)search:(id)sender;
- (IBAction)searchNext:(id)sender;
- (IBAction)searchPrevious:(id)sender;
- (IBAction)searchThis:(id)sender;
- (IBAction)selectThis:(id)sender;
- (IBAction)toggleIconShelf:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)openSearch:(id)sender;
- (IBAction)closeSearch:(id)sender;
- (IBAction)openEditor:(id)sender;
- (IBAction)closeEditor:(id)sender;
- (IBAction)printWebView:(id)sender;
- (IBAction)collapseOneShelf:(id)sender;
- (IBAction)collapseAllShelves:(id)sender;
- (IBAction)gotoBookmark:(id)sender;
- (IBAction)gotoGroup:(id)sender;
- (IBAction)autoComplete:(id)sender;

- (void)openCompletion;
- (void)closeCompletion;
- (void)restoreCompletion;

- (void)newTabWithQuery;
- (void)forceQuery:(NSString*)prefix;

- (WebView*)webView;
- (NSImage*)webViewImage;
- (NSRect)webViewFrame;

- (BOOL)canDragClientWindow;
- (void)switchTab:(id)sender;
- (void)closeTab:(id)sender;
- (void)newTab:(id)sender;
- (void)undockTabToFrame:(NSRect)frame;
- (void)dockTabWithIdentifier:(NSString*)clientIdentifier beforeTabWithIdentifier:(NSString*)insertIdentifier;

- (void)resizeOverlay;
- (BOOL)keyDownForCompletion:(int)key;

- (void)updateEditorIfNeeded;
- (void)updateShelves;
- (void)arrangeShelvesForEditing:(BOOL)editing;
- (NSString*)shelfPath;
- (void)syncShelves;

- (void)trackRemoteClient:(StainlessRemoteClient*)remoteClient withIdentifier:(NSString*)clientIdentifier;
- (void)untrackRemoteClientWithIdentifier:(NSString*)clientIdentifier;
- (void)openURLString:(NSString*)urlString;
- (void)openURLString:(NSString*)urlString expandGroup:(BOOL)expand;
- (NSString*)resolveURLString:(NSString*)urlString;
- (void)deleteBookmark:(BookmarkView*)bookmark;
- (void)openBookmark:(BookmarkView*)bookmark;
- (void)openBookmark:(BookmarkView*)bookmark inGroup:(NSString*)signature forceTab:(BOOL)forceTab forceWindow:(BOOL)forceWindow checkModifiers:(BOOL)checkModifiers;
- (void)refreshBookmarks;
- (void)updateStatus:(NSString*)message reset:(BOOL)reset;

- (void)spaceDidChange;

- (id)connection;

@end


@interface NSWindow (Private)
- (void)setBottomCornerRounded:(BOOL)flag;
@end


@interface NSWindow (SnowLeopard)
- (BOOL)isOnActiveSpace;
@end


@protocol WebIconDatabase
- (NSImage *)defaultIconWithSize:(NSSize)size;
- (NSImage *)iconForURL:(NSString *)URL withSize:(NSSize)size;
- (void)retainIconForURL:(NSString *)URL;
- (NSString *)iconURLForURL:(NSString *)URL;
@end


@class WebSecurityOrigin;

@protocol WebSecurityOrigin
- (void)setQuota:(unsigned long long)quota;
@end


@protocol WebDocumentSelection
- (void)writeSelectionWithPasteboardTypes:(NSArray *)types toPasteboard:(NSPasteboard *)pasteboard;
- (NSRect)selectionRect;
@end


@interface NSURLRequest (Private)
+ (void)setAllowsAnyHTTPSCertificate:(BOOL)flag forHost:(NSString*)host;
@end


@protocol Gears
+ (void)loadGears;
@end