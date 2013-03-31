//
//  StainlessRemoteClient.m
//  StainlessClient
//
//  Created by Danny Espinoza on 10/23/08.
//  Copyright 2008 Mesa Dyanmics, LLC. All rights reserved.
//

#import "StainlessRemoteClient.h"
#import "StainlessController.h"
#import "StainlessClient.h"
#import "StainlessBridge.h"
#import "StainlessCookieJar.h"

extern BOOL gPrivateMode;
extern BOOL gSingleSession;


@implementation StainlessRemoteClient

- (id)initWithFrame:(NSRect)frame
{
    if(self = [super init]) {		
		webView =  [[WebView alloc] initWithFrame:frame frameName:nil groupName:nil];
		
		[webView setResourceLoadDelegate:[StainlessCookieJar sharedCookieJar]];
		[webView setUIDelegate:self];
		[webView setPolicyDelegate:self];
		[webView setHostWindow:nil];
		
		urlString = nil;
		identifier = nil;
		
		spawnOnNavigate = NO;
	}
	
    return self;
}

- (void)dealloc
{
	[urlString release];
	[identifier release];
	
	[super dealloc];
}

- (WebView*)webView
{
	return webView;
}

// WebPolicy delegate
- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id < WebPolicyDecisionListener >)listener
{	
	[listener ignore];
}

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
	NSString* requestUrlString = [[request URL] absoluteString];
	if(requestUrlString) {		
		if([requestUrlString hasPrefix:@"mailto:"]) {
			LSOpenCFURLRef((CFURLRef)[NSURL URLWithString:requestUrlString], NULL);
		}
		else {
			if([actionInformation objectForKey:@"WebActionFormKey"] && [[request HTTPMethod] isEqualToString:@"POST"]) {
				// kludge: we should add the ability to push NSURLRequests over IPC instead of munging POSTS like this
				NSString* post = [[[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding] autorelease];
				requestUrlString = [NSString stringWithFormat:@"%@?%@", requestUrlString, post];
			}
			
			if(identifier == nil) {
				[self setUrlString:requestUrlString];
				
				if(spawnOnNavigate)
					[self webViewShow:webView];
			}
			else {
				StainlessController* controller = (StainlessController*) [NSApp delegate];
				if([[controller connection] redirectClientWithIdentifier:identifier toURL:requestUrlString] == NO) {
					[self setUrlString:requestUrlString];
					[self webViewShow:webView];
				}
			}
		}
	}
	
	[listener ignore];
}

// WebUI delegate
- (void)webViewShow:(WebView *)sender
{
	if(urlString == nil) {
		spawnOnNavigate = YES;
		return;
	}
		
	StainlessController* controller = (StainlessController*) [NSApp delegate];

	if(gPrivateMode)
		[[controller connection] setSpawnPrivate:YES];

	if(gSingleSession)
		[[controller connection] copySpawnSession:[controller session]];

	[[controller connection] copySpawnGroup:[controller group]];

	NSRect newFrame = [webView frame];
	NSRect currentFrame = [[controller window] frame];
	if(NSEqualRects(newFrame, currentFrame) == NO) {
		NSPoint newFrameTL = newFrame.origin;
		newFrameTL.y += newFrame.size.height;
		NSPoint currentFrameTL = currentFrame.origin;
		currentFrameTL.y += currentFrame.size.height;
		
		if(NSEqualPoints(newFrameTL, currentFrameTL))
			newFrame = NSOffsetRect(newFrame, 10.0, -10.0);
		
		newFrame.size.height += 107.0;
		newFrame.origin.y -= 107.0;
		
		[[controller connection] setSpawnFrame:newFrame];
	}
	
	[[controller connection] setSpawnChild:YES];

	StainlessClient* client = [[controller connection] spawnClientWithURL:urlString inWindow:nil];
	NSString* clientIdentifier = [NSString stringWithString:[client identifier]];
	[self setIdentifier:clientIdentifier];
	
	[controller trackRemoteClient:self withIdentifier:clientIdentifier];
	[self autorelease];
}

- (void)webViewFocus:(WebView *)sender
{
	if(identifier) {
		StainlessController* controller = (StainlessController*) [NSApp delegate];
		[[controller connection] focusClientWithIdentifier:identifier];
	}
}

-(void)webView:(WebView *)sender setFrame:(NSRect)frame
{		
	int y = (int) frame.origin.y;
	int h = (int) frame.size.height;
	
	NSRect newFrame = [webView frame];
	if(y + h == 0) {
		newFrame.origin.x += frame.origin.x;
		newFrame.origin.y += frame.origin.y;
	}
	else {
		newFrame.origin.x = frame.origin.x;
		newFrame.origin.y = frame.origin.y;
	}
	
	newFrame.size.width += frame.size.width;
	newFrame.size.height += frame.size.height;
	
	[webView setFrame:newFrame];

	if(identifier) {
		StainlessController* controller = (StainlessController*) [NSApp delegate];
		[[controller connection] resizeClientWithIdentifier:identifier toFrame:frame];
	}
}

- (void)webViewClose:(WebView *)sender
{
	StainlessController* controller = (StainlessController*) [NSApp delegate];

	if(identifier)
		[[controller connection] closeClientWithIdentifier:identifier];

	[webView close];
	[webView autorelease];
	webView = nil;
	
	if(identifier)
		[controller untrackRemoteClientWithIdentifier:identifier];
}

@synthesize urlString;
@synthesize identifier;

@end
