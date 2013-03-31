//
//  NewTabButton.m
//  StainlessClient
//
//  Created by Danny Espinoza on 2/24/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "NewTabButton.h"
#import "StainlessController.h"

extern NSString* StainlessBookmarkPboardType;
extern NSString* WebURLPboardType;


@implementation NewTabButton

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super initWithFrame:frame]) {
		[self setIgnoresMultiClick:YES];
		[self registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, WebURLPboardType, nil]];
	}
	
    return self;
}

- (void)dealloc
{
	[super dealloc];
}

// NSDraggingDestination protocol
- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
	return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{	
	NSString* urlString = nil;
	
	NSPasteboard* pboard = [sender draggingPasteboard];
	[pboard types];

	NSString* bookmarkIndexString = [pboard stringForType:StainlessBookmarkPboardType];
	if(bookmarkIndexString) {
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		[controller openURLString:bookmarkIndexString expandGroup:NO];
		
		return YES;
	}

	NSURL* url = [NSURL URLFromPasteboard:pboard];
	if(url)
		urlString = [url absoluteString];
	
	if(urlString == nil) {
		NSData* data = [pboard dataForType:WebURLPboardType];
		if(data)
			urlString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	}
	
	if(urlString && ([urlString hasPrefix:@"http:"] || [urlString hasPrefix:@"https:"])) {
		StainlessController* controller = (StainlessController*)[NSApp delegate];
		[controller openURLString:urlString];
		
		return YES;
	}
	
	return NO;
}

@end
