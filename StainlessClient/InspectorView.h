//
//  InspectorView.h
//  StainlessClient
//
//  Created by Danny Espinoza on 5/6/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BookmarkView.h"
#import "StainlessShelfView.h"


@interface InspectorView : NSView {
	IBOutlet NSImageView* arrow;
	IBOutlet NSForm* form;
	IBOutlet NSImageView* icon;
	
	NSGradient* gradient;
	NSGradient* selectGradient;
	
	BookmarkView* bookmark;
	StainlessShelfView* shelf;	
	BOOL isDirty;
}

@property(nonatomic, retain) BookmarkView* bookmark;
@property(nonatomic, retain) StainlessShelfView* shelf;
@property BOOL isDirty;

- (IBAction)revertChanges:(id)sender;
- (IBAction)applyChanges:(id)sender;
- (IBAction)iconDidChange:(id)sender;

- (void)updateBookmark:(BookmarkView*)newBookmark;
- (void)updateArrow;

@end
