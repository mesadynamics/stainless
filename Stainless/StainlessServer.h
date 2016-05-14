//
//  StainlessServer.h
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "StainlessClient.h"
#import "StainlessWindow.h"
#import "StainlessAutoComplete.h";

enum {
	historyOpen = 100,
	historyOpenTab = 200,
	historyOpenWindow = 300,
	historyCopy = 400,
	historyDelete = 500
};

enum {
	downloadOpen = 100,
	downloadReveal = 200,
	downloadCopy = 300,
	downloadDelete = 400,
	downloadDeleteAll = 500,
	downloadStop = 600
};


@protocol StainlessWorkspaceServer
- (void)beginTransportForPid:(pid_t)pid;
@end


@interface StainlessServer : NSObject <StainlessWorkspaceServer> {
	//NSMutableDictionary* provisionalClients;
	//NSMutableDictionary* provisionalWindows;
	//NSMutableArray* provisionalLayers;
	
	WebHistory* clientHistory;
	NSString* ignoreHistory;

	NSMutableDictionary* clients;
	NSMutableDictionary* windows;
	NSMutableArray* layers;
	NSMutableArray* hosts;
	
	IBOutlet NSTableView* tasks;
	IBOutlet NSButton* closeTask;
	
	IBOutlet NSTableView* history;
	IBOutlet NSPopUpButton* historyDate;
	IBOutlet NSSearchField* historySearch;
	NSMutableArray* historyList;
	NSMutableArray* filteredHistoryList;

	IBOutlet NSTableView* downloads;
	IBOutlet NSButton* clearDownloads;
	NSMutableDictionary* downloadInfo;

	StainlessAutoComplete* urlComplete;
	StainlessAutoComplete* searchComplete;
	NSString* searchString;
	NSString* searchToken;
	NSString* selectedTask;
	StainlessClient* focus;
	
	NSString* hotSpare;
	NSString* hotSpareCached;
	BOOL hotSpareBusy;
	
	BOOL forcePrivate;
	BOOL forceSingle;
	
	BOOL spawnWindow;
	BOOL spawnAndFocus;
	BOOL spawnPrivate;
	NSString* spawnGroup;
	NSString* spawnSession;
	BOOL spawnChild;
	NSRect spawnFrame;
	long spawnCount;
	long spawnIndex;
	
	BOOL focusFirst;
	BOOL ignoreLayer;
	unsigned int defaultSpace;

	BOOL webHistoryCanRecordVisits;
	BOOL webHistoryCanControlVisitCount;
	BOOL webHistoryHasVisitCount;
}

@property(nonatomic, retain) NSString* ignoreHistory;
@property(nonatomic, retain) NSString* searchString;
@property(nonatomic, retain) NSString* searchToken;
@property(nonatomic, retain) NSString* selectedTask;

@property(retain) StainlessClient* focus;
@property BOOL forcePrivate;
@property BOOL forceSingle;
@property BOOL spawnWindow;
@property BOOL spawnAndFocus;
@property BOOL spawnPrivate;
@property(retain) NSString* spawnGroup;
@property(retain) NSString* spawnSession;
@property BOOL spawnChild;
@property NSRect spawnFrame;
@property long spawnCount;
@property long spawnIndex;

- (IBAction)handleCloseTask:(id)sender;
- (IBAction)handleHistoryAction:(id)sender;
- (IBAction)handleDownloadAction:(id)sender;

- (void)createNewTab:(NSString*)urlString;
- (void)createNewTab;
- (void)refreshTaskManager:(NSTimer*)timer;
- (void)refreshHistory;
- (void)refreshHistoryDays;
- (IBAction)refreshHistoryList:(id)sender;
- (IBAction)filterHistoryList:(id)sender;
- (void)saveCookies:(NSTimer*)timer;
- (void)saveFocusWindow;

- (void)saveSessions:(BOOL)persist;
- (BOOL)restoreSessions;

- (void)computeSearchString;
- (void)addURLToAutoComplete:(NSString*)urlString withItem:(WebHistoryItem*)item;

- (void)launchHotSpareWithIdentifier:(NSString*)clientIdentifier;
- (BOOL)launchClientWithIdentifier:(NSString*)clientIdentifier andKey:(NSString*)clientKey;
- (void)launchManager;

- (void)refreshAllClients:(NSString*)message;
- (void)closeAllClients;

- (void)freezeAllWindows:(BOOL)freeze;
- (void)hideAllWindows:(BOOL)hide;
- (void)focusAllWindows;
- (void)focusMainWindow;
- (NSMutableDictionary*)windowsInCurrentSpace;
- (void)resetHotSpare;

- (StainlessClient*)spawnClientWithURL:(NSString*)urlString;
- (StainlessClient*)spawnClientWithURL:(NSString*)urlString inWindow:(StainlessWindow*)window;
- (StainlessClient*)spawnClientWithURL:(NSString*)urlString inWindowWithIdentifier:(NSString*)windowIdentifier;

- (BOOL)redirectClient:(StainlessClient*)client toURL:(NSString*)urlString;
- (BOOL)redirectClientWithIdentifier:(NSString*)clientIdentifier toURL:(NSString*)urlString;

- (void)performCommand:(NSString*)command;
- (void)clientToServerCommand:(NSString*)command;

- (void)closeWindowWithIdentifier:(NSString*)windowIdentifier;
- (void)layerWindow:(StainlessWindow*)window;
- (void)layerWindowWithIdentifier:(NSString*)windowIdentifier;
- (void)alignWindow:(StainlessWindow*)window;
- (void)alignWindowWithIdentifier:(NSString*)windowIdentifier;
- (void)focusWindow:(StainlessWindow*)window;
- (void)focusWindowWithIdentifier:(NSString*)windowIdentifier;

- (void)focusClient:(StainlessClient*)client;
- (void)focusClientWithIdentifier:(NSString*)clientIdentifier;

- (void)undockClient:(StainlessClient*)client;
- (void)dockClientWithIdentifier:(NSString*)clientIdentifier intoWindow:(StainlessWindow*)window beforeClientWithIdentifier:(NSString*)beforeIdentifier;
- (void)moveClient:(StainlessClient*)client intoWindow:(StainlessWindow*)window insertBefore:(StainlessClient*)nextClient;

- (StainlessClient*)registerClientWithIdentifier:(NSString*)clientIdentifier key:(NSString*)key;
- (StainlessClient*)clientWithIdentifier:(NSString*)clientIdentifier;
- (StainlessWindow*)getWindowForClient:(StainlessClient*)client;
- (StainlessWindow*)getWindowForClientWithIdentifier:(NSString*)clientIdentifier;
- (oneway void)closeClientWithIdentifier:(NSString*)clientIdentifier;
- (void)updateClientWithIdentifier:(NSString*)clientIdentifier;
- (void)updateClientWindowWithIdentifier:(NSString*)clientIdentifier;

- (void)purgeDownloads;
- (BOOL)hasDownloads;
- (BOOL)hasClients;
- (BOOL)isMultiClient;
- (BOOL)isActiveClient;
- (void)hold;

- (void)removeCacheForClientWithPid:(pid_t)pid;
- (NSInteger)widForTop;
- (NSInteger)widForBottom;
- (void)reconcileWid:(NSInteger)wid;

// Callback
- (void)shutdownClientWithPid:(pid_t)pid;
- (void)openHistoryItem:(id)sender;
- (void)openDownloadsItem:(id)sender;

@end


@interface WebHistory (WebPrivate)
- (WebHistoryItem *)_itemForURLString:(NSString *)URLString;
- (NSArray *)allItems;
@end


@interface WebHistoryItem (WebInternal)
- (void)_visitedWithTitle:(NSString *)title;
- (void)_visitedWithTitle:(NSString *)title increaseVisitCount:(BOOL)increaseVisitCount;
- (void)_recordInitialVisit;
@end


@interface WebHistoryItem (WebPrivate)
- (int)visitCount;
- (void)setVisitCount:(int)count;
@end


@interface WebHistoryItem (CountCompare)
- (NSComparisonResult)visitCountCompare:(WebHistoryItem*)dict;
@end


@interface NSMutableDictionary (KeyCompare)
- (NSComparisonResult)indexKeyCompare:(NSMutableDictionary*)dict;
@end

