//
//  DownloadTable.m
//  Stainless
//
//  Created by Danny Espinoza on 7/29/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "DownloadTable.h"
#import "StainlessServer.h"
#import <Carbon/Carbon.h>


@implementation DownloadTable

- (void)copy:(id)sender
{
	StainlessServer* server = (StainlessServer *) [self delegate];
	NSMenuItem* copyItem = [[self menu] itemWithTag:downloadCopy];
	[server handleDownloadAction:copyItem];
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	BOOL enabled = ([self selectedRow] == -1 ? NO : YES);
	if(enabled == NO && [self clickedRow] != -1)
		enabled = YES;
	
	for(NSMenuItem* item in [menu itemArray])
		[item setEnabled:enabled];
}

- (void)keyDown:(NSEvent *)event
{
	unsigned short keyCode = [event keyCode];
	
	if(keyCode == kVK_Delete) {
		StainlessServer* server = (StainlessServer *) [self delegate];
		NSMenuItem* deleteItem = [[self menu] itemWithTag:downloadDelete];
		[server handleDownloadAction:deleteItem];
		
		return;
		
	}
		
	if(keyCode == kVK_Return) {
		StainlessServer* server = (StainlessServer *) [self delegate];
		NSMenuItem* revealItem = [[self menu] itemWithTag:downloadReveal];
		[server handleDownloadAction:revealItem];
		
		return;
	}
	
	[super keyDown:event];
}

@end
