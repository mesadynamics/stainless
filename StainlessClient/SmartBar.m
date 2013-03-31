//
//  SmartBar.m
//  StainlessClient
//
//  Created by Danny Espinoza on 7/14/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "SmartBar.h"


@implementation SmartBar

- (void)awakeFromNib
{
	[[self window] setAcceptsMouseMovedEvents:YES];
}

- (void)updateTrackingAreas
{
	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited + NSTrackingMouseMoved + NSTrackingActiveInActiveApp + NSTrackingInVisibleRect;
	NSTrackingArea* tracker = [[NSTrackingArea alloc] initWithRect:[self bounds] options:options owner:self userInfo:nil];
	[self addTrackingArea:tracker];
	
	[super updateTrackingAreas];
}

- (void)mouseMoved:(NSEvent*)theEvent
{
	int mouseOverRow = [self rowAtPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	
	if(mouseOverRow == -1)
		[self deselectAll:self];
	else if(mouseOverRow != [self selectedRow]) {
		if([[self delegate] tableView:self shouldSelectRow:mouseOverRow] == NO)
			return;
		
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:mouseOverRow] byExtendingSelection:NO];
	}
}

- (void)mouseExited:(NSEvent*)theEvent
{
	[self deselectAll:self];
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect
{
	int selectedRow = [self selectedRow];
	if(selectedRow == -1)
		return;
	
	NSRect rowRect = [self rectOfRow:selectedRow];
	NSRect columnRect = [self rectOfColumn:0];

	NSImage* highlightImage = [NSImage imageNamed:@"Selection"];
	[highlightImage drawInRect:NSIntersectionRect(rowRect, columnRect) fromRect:NSMakeRect(0.0, 0.0, 1.0, 19.0) operation:NSCompositeSourceOver fraction:1.0];
}

- (id)_highlightColorForCell:(NSCell *)cell
{
	return nil;
}

@end
