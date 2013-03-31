//
//  main.m
//  StainlessClient
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright Mesa Dynamics, LLC 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StainlessApplication.h"
#import "StainlessCookieJar.h"

//#define MallocStackLogging 1

#if defined(MallocStackLogging)
#include <stdlib.h>
void sleepForLeaks(void);
#endif

NSString* StainlessTabPboardType = @"com.stainlessapp.tab";
NSString* StainlessPrivateTabPboardType = @"com.stainlessapp.tab.private";
NSString* StainlessBookmarkPboardType = @"com.stainlessapp.bookmark";
NSString* StainlessIconPboardType = @"com.stainlessapp.icon";
NSString* StainlessSessionPboardType = @"com.stainlessapp.session";
NSString* StainlessGroupPboardType = @"com.stainlessapp.group";

// ref: PasteboardMac.mm (WebKit)
NSString* WebURLPboardType = @"public.url";
NSString* WebURLNamePboardType = @"public.url-name";
//

BOOL gTerminate = YES;
BOOL gPrivateMode = NO;
BOOL gSingleSession = NO;
BOOL gIconShelf = NO;
BOOL gIconEditor = NO;
BOOL gStatusBar = YES;
BOOL gChildClient = NO;

SInt32 gOSVersion;

int main(int argc, char *argv[])
{
#if defined(MallocStackLogging)
	atexit(sleepForLeaks);
#endif

    if (getenv("WEBKIT_UNSET_DYLD_FRAMEWORK_PATH")) {
        unsetenv("DYLD_FRAMEWORK_PATH");
        unsetenv("WEBKIT_UNSET_DYLD_FRAMEWORK_PATH");
    }

	Gestalt(gestaltSystemVersion, &gOSVersion);

	[StainlessCookieJar sharedCookieJar];
	[StainlessApplication sharedApplication];

	return NSApplicationMain(argc,  (const char **) argv);
}

#if defined(MallocStackLogging)
void sleepForLeaks(void)
{
	for(;;)
		sleep(60);
}
#endif

