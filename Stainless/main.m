//
//  main.m
//  Stainless
//
//  Created by Danny Espinoza on 9/3/08.
//  Copyright Mesa Dynamics, LLC 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StainlessApplication.h"

//#define MallocStackLogging 1

#if defined(MallocStackLogging)
#include <stdlib.h>
void sleepForLeaks(void);
#endif

SInt32 gOSVersion;

int main(int argc, char *argv[])
{
#if defined(MallocStackLogging)
	atexit(sleepForLeaks);
#endif

	Gestalt(gestaltSystemVersion, &gOSVersion);

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
