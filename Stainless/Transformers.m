//
//  Transformers.m
//  Stainless
//
//  Created by Danny Espinoza on 9/11/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "Transformers.h"


@implementation SelectionIsNotOther
+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
    if([value intValue] == 400)
		return [NSNumber numberWithBool:NO];
	
	return [NSNumber numberWithBool:YES];
}
@end
