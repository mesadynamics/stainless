//
//  StainlessShelfView.h
//  StainlessClient
//
//  Created by Danny Espinoza on 1/29/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BookmarkView.h"
#import "FadingLabel.h"


enum {
	bookmarkOpen = 100,
	bookmarkOpenTab = 200,
	bookmarkOpenWindow = 300,
	bookmarkCopy = 400,
	bookmarkDelete = 500,
	bookmarkConfirmDelete = 501,
	bookmarkEdit = 600
};


@interface StainlessShelfView : NSView {
	IBOutlet NSMenu* context;
	IBOutlet NSMenu* groupContext;
	IBOutlet FadingLabel* label;
	NSGradient* gradient;
	NSBezierPath* help;
	
	NSString* signature;
	StainlessShelfView* parent;
	StainlessShelfView* child;
	float width;
	
	BookmarkView* selection;
	BookmarkView* focus;
	BookmarkView* owner;
	
	BOOL canSync;
	BOOL canCommit;

	int dragOffset;
	int dragIndex;
	int shelfIndex;
}

@property(nonatomic, retain) NSMenu* context;
@property(nonatomic, retain) NSMenu* groupContext;
@property(nonatomic, retain) FadingLabel* label;

@property(nonatomic, retain) NSString* signature;
@property(nonatomic, retain) StainlessShelfView* parent;
@property(nonatomic, retain) StainlessShelfView* child;
@property float width;
@property(nonatomic, retain) BookmarkView* selection;
@property(nonatomic, retain) BookmarkView* focus;
@property(nonatomic, retain) BookmarkView* owner;
@property BOOL canSync;
@property BOOL canCommit;
@property int shelfIndex;

- (void)finishInit;

- (NSArray*)syncBookmarks:(BOOL)force;
- (NSArray*)syncBookmarks:(BOOL)force andUpdate:(BOOL)update;

- (void)commitBookmarks;
- (void)commitBookmarksWithSignature:(NSString*)bookmarkSignature fromArray:(NSArray*)bookmarkArray;
- (void)deleteBookmarksForGroup:(BookmarkView*)bookmark;

- (void)resizeToWindow;

- (void)setLoading:(BOOL)set;

- (void)openBookmarkGroup:(BookmarkView*)bookmark;
- (void)closeBookmarkGroup:(BookmarkView*)bookmark;
- (void)expandToGroupPath:(NSString*)path;

- (void)showBookmark:(BookmarkView*)bookmark;
- (void)hideBookmark:(BOOL)now;

- (BOOL)shelfExists:(StainlessShelfView*)shelf;
- (BOOL)bookmarkExists:(BookmarkView*)bookmark;

- (IBAction)createGroup:(id)sender;
- (IBAction)createGroupFromTabs:(id)sender;
- (IBAction)closeGroup:(id)sender;
- (IBAction)handleBookmarkAction:(id)sender;

@end
