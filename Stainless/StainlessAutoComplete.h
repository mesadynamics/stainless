//
//  StainlessAutoComplete.h
//  Stainless
//
//  Created by Danny Espinoza on 4/16/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define QL_MAX	96 // printable ASCII (UTF8)

typedef struct QL_Node QL_Node;

struct QL_Node {
	QL_Node* next[QL_MAX];
	QL_Node* prev;
	char token;
	void* data;
	int depth;
};


@interface StainlessAutoComplete : NSObject {
	NSMutableArray* objectCollector;
	QL_Node* swapDictionary;
}

- (void)swap;
- (void)addString:(NSString*)string withObject:(id)object;
- (NSMutableArray*)arrayOfDataMatchingString:(NSString*)string;

@end
