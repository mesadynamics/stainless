//
//  StainlessBarView.h
//  StainlessClient
//
//  Created by Danny Espinoza on 9/12/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StainlessTabView.h"
#import "StainlessWindow.h"
#import "StainlessClient.h"


@interface StainlessBarView : NSView {
	NSMutableDictionary* tabControllers;
	StainlessTabView* activeTab;
	
	NSButton* newTabButton;
	
	int dragOffset;
	int dragIndex;
}

- (void)prepareForDragging;
- (void)prepareForUndocking;

- (void)updateClientWithIdentifier:(NSString*)identifier;
- (void)syncClientList:(NSArray*)clientList inWindowWithIdentifier:(NSString*)clientIdentifier;
- (void)resizeToWindow;

- (NSArray*)allTabs;
- (StainlessTabView*)nextTab;
- (StainlessTabView*)previousTab;
- (StainlessTabView*)tabWithIndex:(int)index;

@property(assign) StainlessTabView* activeTab;

@end
