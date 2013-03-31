//
//  StainlessAutoComplete.mm
//  Stainless
//
//  Created by Danny Espinoza on 4/16/09.
//  Copyright 2009 Mesa Dynamics, LLC. All rights reserved.
//

#import "StainlessAutoComplete.h"


static QL_Node* QL_dictionary = NULL;
static QL_Node* QL_pointer = NULL;
static char* QL_entry = NULL;
static void* QL_data = NULL;

static NSMutableArray* QL_bag = NULL;

void QL_init();
void QL_dealloc();
QL_Node* QL_newNode();
void QL_addEntryToDictionary(const char* entry, void* data);
NSMutableArray* QL_allEntriesForNode(const char* entry);

void QL_findLastNodeForEntry(QL_Node* node);
void QL_addNextEntryTokenToNode(QL_Node* node);
void QL_packAllNodeData(QL_Node* node, bool include);
char* QL_nodeToString(QL_Node* node);

void
QL_init()
{
	QL_dictionary = QL_newNode();
}

void
QL_dealloc()
{
}

QL_Node*
QL_newNode()
{
	QL_Node* outNode = (QL_Node*) malloc(sizeof(QL_Node));
	
	for(int i = 0; i < QL_MAX; i++)
		outNode->next[i] = NULL;
	
	outNode->prev = NULL;
	outNode->token = 0;
	outNode->data = NULL;
	outNode->depth = 0;
	
	return outNode;
}

void
QL_addEntryToDictionary(
						const char* entry,
						void* data)
{
	QL_entry = (char*) entry;
	QL_data = data;
	
	QL_addNextEntryTokenToNode(QL_dictionary);
}

NSMutableArray* QL_allEntriesForNode(
			   const char* entry)
{
	QL_entry = (char*) entry;
	QL_pointer = NULL;
	QL_bag = [NSMutableArray array];
	
	QL_findLastNodeForEntry(QL_dictionary);
	if(QL_pointer != NULL) {
		QL_packAllNodeData(QL_pointer, true);
	}
	
	return QL_bag;
}

void
QL_findLastNodeForEntry(
						   QL_Node* node)
{
	int x = 0;
	
skip:
	if(*QL_entry == '\0') {
		QL_pointer = node;
		return;
	}
	
	x = *QL_entry - ' ';
	if(x < 0 || x >= QL_MAX) {
		QL_entry++;
		goto skip;
	}
	
	QL_Node* next = node->next[x];
	if(next) {
		QL_entry++;
		QL_findLastNodeForEntry(next);
	}
}

void
QL_addNextEntryTokenToNode(
						   QL_Node* node)
{
	int x = 0;
	
skip:
	if(*QL_entry == '\0') {
		node->data = QL_data;
		return;
	}
	
	x = *QL_entry - ' ';
	if(x < 0 || x >= QL_MAX) {
		QL_entry++;
		goto skip;
	}
	
	QL_Node* next = node->next[x];
	if(next == NULL) {
		next = QL_newNode();
		next->prev = node;
		next->token = *QL_entry;
		next->depth = node->depth + 1;
		
		node->next[x] = next;
	}
	
	QL_entry++;
	QL_addNextEntryTokenToNode(next);
}

void QL_packAllNodeData(
						QL_Node* node,
						bool include)
{
	if(node == NULL)
		return;
	
	if(include && node->data)
		[QL_bag addObject:(id)node->data];
	
	for(int i = 0; i < QL_MAX; i++)
		QL_packAllNodeData(node->next[i], true);
}

char*
QL_nodeToString(
				QL_Node* node)
{
	char* outString = (char*) malloc(node->depth + 1);

	char* p = &(outString[node->depth]);
	*p-- = 0;
	
	while(node->prev) {
		*p-- = node->token;
		node = node->prev;
	}
	
	return outString;
}

@implementation StainlessAutoComplete

- (id)init
{
	if(self = [super init]) {
		objectCollector = [[NSMutableArray alloc] init];
		
		QL_Node* saveDictionary = QL_dictionary;
		QL_init();
		swapDictionary = QL_dictionary;
		if(saveDictionary)
			QL_dictionary = saveDictionary;
	}
	
	return self;
}

- (void)dealloc
{
	[self swap];
	[objectCollector release];
	QL_dealloc();
	
	[super dealloc];
}

- (void)swap
{
	QL_Node* saveDictionary = QL_dictionary;
	QL_dictionary = swapDictionary;
	swapDictionary = saveDictionary;
}

- (void)addString:(NSString*)string withObject:(id)object
{
	[objectCollector addObject:object];
	QL_addEntryToDictionary([string UTF8String], (void*)object);
}

- (NSMutableArray*)arrayOfDataMatchingString:(NSString*)string
{
	return QL_allEntriesForNode([string UTF8String]);
}

@end
