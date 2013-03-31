//
//  StainlessController.h
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StainlessServer.h"
#import "StainlessCookieServer.h"


@interface StainlessController : NSObject {
	IBOutlet StainlessServer* server;
	IBOutlet NSPanel* taskManager;
	IBOutlet NSPanel* historyList;
	IBOutlet NSPanel* downloads;
	IBOutlet NSPanel* preferences;
	IBOutlet NSButton* prefGears;
	IBOutlet NSButton* prefGearsInfo;
	IBOutlet NSButton* prefWebKit;
	IBOutlet NSTextField* prefHome;
	IBOutlet NSTextField* prefLocation;
	IBOutlet NSToolbar* toolbar;
	IBOutlet NSMenuItem* menuBlockPopups;
	
	NSConnection* serverPort;
	NSConnection* cookiePort;
	
	long activeTimerCount;
	BOOL ignoreActivation;
	BOOL ignoreSwitch;
	
	BOOL ignoreQuitConfirm;
	NSAlert* quitConfirm;
	
	BOOL ignoreSessionSave;
	BOOL forceSessionSave;
	//BOOL focusAllWindows;
	
	BOOL prefLocationSet;
	
	NSInteger saveGears;
	NSInteger saveWebKit;
	
	NSString* activeBundle;
	NSString* transportCoda;
}

@property BOOL ignoreActivation;
@property(retain) NSString* activeBundle;

- (IBAction)createNewTab:(id)sender;
- (IBAction)createIsolatedTab:(id)sender;
- (IBAction)createPrivateWindow:(id)sender;
- (IBAction)performCommand:(id)sender;
- (IBAction)bringAllToFront:(id)sender;
- (IBAction)showAboutPage:(id)sender;
- (IBAction)showHelpPage:(id)sender;
- (IBAction)showShortcutsPage:(id)sender;
- (IBAction)checkForUpdates:(id)sender;
- (IBAction)updatePopupBlock:(id)sender;
- (IBAction)chooseDownloadLocation:(id)sender;
- (IBAction)terminateLater:(id)sender;
- (IBAction)newDocumentFromDock:(id)sender;

- (IBAction)getGears:(id)sender;
- (IBAction)getWebkit:(id)sender;

- (IBAction)showSafariBookmarks:(id)sender;

- (IBAction)showHistoryList:(id)sender;
- (IBAction)showTaskManager:(id)sender;
- (IBAction)showDownloads:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)cancelPreferences:(id)sender;
- (IBAction)savePreferences:(id)sender;

- (IBAction)noopAction:(id)sender;

- (void)handleClientDisconnect:(id)sender;

- (void)frontAppChanged;

@end


@interface NSWindow (Stainless)
- (BOOL)_hasActiveControls;
@end


@interface NSToolbarItem (Stainless)
- (NSInteger)indexOfSelectedItem;
@end


