//
//  StainlessBridge.h
//  Stainless
//
//  Created by Danny Espinoza on 9/6/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* SMHideShadow;
extern NSString* SMShowShadow;
extern NSString* SMPrepareToSpawn;

extern NSString* SMHideHomeButton;
extern NSString* SMShowHomeButton;
extern NSString* SMUpdateIconShelf;
extern NSString* SMHidePopups;
extern NSString* SMShowPopups;


@protocol StainlessClientProxy
- (oneway void)registerClient:(bycopy NSString*)clientKey;
- (oneway void)notifyClientWithIdentifier:(bycopy NSString*)clientIdentifier;
- (oneway void)updateClientWithIdentifier:(bycopy NSString*)clientIdentifier;
- (BOOL)activateClientAndBringToFront:(BOOL)bringToFront withAttributes:(NSDictionary*)attributes siblings:(NSArray*)clientList;
- (oneway void)deactivateClient;
- (oneway void)reactivateClient;
- (oneway void)refreshClient:(bycopy NSString*)message;
- (oneway void)closeClient;
- (oneway void)freezeClient:(BOOL)freeze;
- (oneway void)hideClient:(BOOL)hide;
- (oneway void)redirectClient:(bycopy NSString*)urlString;
- (oneway void)permitClient:(bycopy NSString*)host;
- (oneway void)resizeClient:(bycopy NSRect)frame;
- (oneway void)serverToClientCommand:(bycopy NSString*)command;
- (oneway void)cancelDownloadForClient:(bycopy NSString*)downloadStamp; // 0.8
@end


@protocol StainlessServerProxy
- (void)hotSpareReadyWithIdentifier:(id)clientIdentifier;
- (id)registerClientWithIdentifier:(id)clientIdentifier key:(id)key;
- (id)clientWithIdentifier:(id)clientIdentifier;

- (void)undockClient:(id)client;
- (void)dockClientWithIdentifier:(id)clientIdentifier intoWindow:(id)window beforeClientWithIdentifier:(id)beforeIdentifier;

- (oneway void)closeWindow:(id)window;
- (void)focusWindow:(id)window;
- (void)layerWindow:(id)window;
- (void)alignWindow:(id)window;
- (id)getPermittedHosts;
- (id)getWindowForClient:(id)client;
- (void)focusClientWithIdentifier:(id)clientIdentifier;
- (void)resetFocus;
- (oneway void)trimFocus:(long)count;
- (oneway void)closeClient:(id)client;
- (oneway void)closeClientWithIdentifier:(id)clientIdentifier;
- (oneway void)updateClient:(id)client;
- (oneway void)updateClientWindow:(id)client;
- (oneway void)resizeClientWithIdentifier:(id)clientIdentifier toFrame:(NSRect)frame;

- (oneway void)permitClients:(id)host fromClientWithIdentifier:(id)clientIdentifier;

- (id)spawnClientWithURL:(id)urlString inWindow:(id)window;
- (BOOL)redirectClientWithIdentifier:(id)clientIdentifier toURL:(id)urlString;

- (void)clientToServerCommand:(id)command;
- (BOOL)isMultiClient;
- (BOOL)isActiveClient;
- (void)hold;

- (void)setSpawnWindow:(BOOL)set;
- (void)setSpawnAndFocus:(BOOL)set;
- (void)setSpawnPrivate:(BOOL)set;
- (void)setSpawnChild:(BOOL)set;
- (void)setSpawnFrame:(NSRect)set;
- (void)setSpawnIndex:(long)set;

- (oneway void)copySpawnGroup:(bycopy NSString*)copy;
- (oneway void)copySpawnSession:(bycopy NSString*)copy;

- (oneway void)addURLToHistory:(bycopy NSString *)URLString title:(bycopy NSString *)title;

- (oneway void)updateDownload:(bycopy NSString*)downloadStamp contentLength:(bycopy NSNumber*)length fileName:(bycopy NSString*)name;
- (oneway void)endDownload:(bycopy NSString*)downloadStamp didFail:(BOOL)fail;

- (NSArray*)completionForURLString:(bycopy NSString*)urlString includeSearch:(BOOL)search;

@end


@interface NSString (Stainless)
- (int)globalHash;
@end


@interface NSImage (Stainless)
- (NSImage*)thumbnailWithSize:(NSSize)scaleSize;
@end