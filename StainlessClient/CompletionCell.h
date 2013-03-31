//
//  CompletionCell.h
//  StainlessClient
//
//  Created by Danny Espinoza on 10/19/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CompletionCell : NSActionCell {
	NSDictionary* attributes;
}

@property(nonatomic, retain) NSDictionary* attributes;

@end
