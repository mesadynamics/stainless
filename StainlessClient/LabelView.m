//
//  LabelView.m
//  StainlessClient
//
//  Created by Danny Espinoza on 3/18/09.
//  Copyright 2009 Mea Dynamics, LLC. All rights reserved.
//

#import "LabelView.h"


@implementation LabelView

@synthesize labelString;
@synthesize labelRect;

@synthesize font;
@synthesize color;
@synthesize shadowColor;
@synthesize backgroundColor;
@synthesize height;
@synthesize padX;
@synthesize padY;
@synthesize rounded;
@synthesize shadowed;

- (id)initWithFrame:(NSRect)frame
{
	if(self = [super initWithFrame:frame]) {
       // _label = nil;
		_oval = nil;
		
		NSFont* controlFont = [NSFont controlContentFontOfSize:14.5];
		self.font = [[NSFontManager sharedFontManager] convertFont:controlFont toHaveTrait:NSBoldFontMask+NSCondensedFontMask];
		self.color = [NSColor whiteColor];
		self.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.62];
		self.backgroundColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.4];
		
		height = 20.0;
		padX = 10.0;
		padY = 2.0;
		rounded = YES;
		shadowed = YES;
    }
	
    return self;
}

- (void)dealloc
{
	[color release];
	[shadowColor release];
	[backgroundColor release];
	[font release];
	
	[labelString release];
	//[_label release];
	[_oval release];
	
	[super dealloc];
}

- (NSBezierPath*)_renderLabelBackground
{
	NSRect inRect = [self bounds];
	float inRadiusX = height * .5;
	float inRadiusY = inRadiusX;
	const float kEllipseFactor = 0.55228474983079;
	
	float theMaxRadiusX = NSWidth(inRect) / 2.0;
	float theMaxRadiusY = NSHeight(inRect) / 2.0;
	float theRadiusX = (inRadiusX < theMaxRadiusX) ? inRadiusX : theMaxRadiusX;
	float theRadiusY = (inRadiusY < theMaxRadiusY) ? inRadiusY : theMaxRadiusY;
	float theControlX = theRadiusX * kEllipseFactor;
	float theControlY = theRadiusY * kEllipseFactor;
	NSRect theEdges = NSInsetRect(inRect, theRadiusX, theRadiusY);
	NSBezierPath* theResult = [NSBezierPath bezierPath];
	
	//	Lower edge and lower-right corner
	[theResult moveToPoint:NSMakePoint(theEdges.origin.x, inRect.origin.y)];
	[theResult lineToPoint:NSMakePoint(NSMaxX(theEdges), inRect.origin.y)];
	[theResult curveToPoint:NSMakePoint(NSMaxX(inRect), theEdges.origin.y)
			  controlPoint1:NSMakePoint(NSMaxX(theEdges) + theControlX, inRect.origin.y)
			  controlPoint2:NSMakePoint(NSMaxX(inRect), theEdges.origin.y - theControlY)];
	
	//	Right edge and upper-right corner
	[theResult lineToPoint:NSMakePoint(NSMaxX(inRect), NSMaxY (theEdges))];
	[theResult curveToPoint:NSMakePoint(NSMaxX(theEdges), NSMaxY (inRect))
			  controlPoint1:NSMakePoint(NSMaxX(inRect), NSMaxY (theEdges) + theControlY)
			  controlPoint2:NSMakePoint(NSMaxX(theEdges) + theControlX, NSMaxY(inRect))];
	
	//	Top edge and upper-left corner
	[theResult lineToPoint:NSMakePoint(theEdges.origin.x, NSMaxY (inRect))];
	[theResult curveToPoint:NSMakePoint(inRect.origin.x, NSMaxY (theEdges))
			  controlPoint1:NSMakePoint(theEdges.origin.x - theControlX, NSMaxY(inRect))
			  controlPoint2:NSMakePoint(inRect.origin.x, NSMaxY (theEdges) + theControlY)];
	
	//	Left edge and lower-left corner
	[theResult lineToPoint:NSMakePoint(inRect.origin.x, theEdges.origin.y)];
	[theResult curveToPoint:NSMakePoint(theEdges.origin.x, inRect.origin.y)
			  controlPoint1:NSMakePoint(inRect.origin.x, theEdges.origin.y - theControlY)
			  controlPoint2:NSMakePoint(theEdges.origin.x - theControlX, inRect.origin.y)];
	
	
    //	Finish up and return
    [theResult closePath];
    return theResult;
}

/*- (NSBezierPath *) _renderLabelString: (NSString *)string
{
	float x = padX;
	float y = padY;
	
    NSTextView *textview;
    textview = [[NSTextView alloc] init];

    [textview setString: string];
    [textview setFont: font];
	
    NSLayoutManager *layoutManager;
    layoutManager = [textview layoutManager];
	
    NSRange range;
    range = [layoutManager glyphRangeForCharacterRange:
			 NSMakeRange (0, [string length])
								  actualCharacterRange: nil];
    NSGlyph *glyphs;
    glyphs = (NSGlyph *) malloc (sizeof(NSGlyph)
                                 * (range.length * 2));
    [layoutManager getGlyphs: glyphs  range: range];
	
    NSBezierPath *path;
    path = [NSBezierPath bezierPath];
	
    [path moveToPoint: NSMakePoint (x, y)];
    [path appendBezierPathWithGlyphs: glyphs
							   count: range.length  inFont: font];

    free (glyphs);
    [textview release];
	
    return (path);
	
} // makePathFromString*/

- (void)drawRect:(NSRect)rect
{
	if(rounded) {
		NSRect bounds = [self bounds];
		if(_oval && NSEqualRects(bounds, _ovalRect) == NO) {
			[_oval release];
			_oval = nil;
		}

		if(_oval == nil) {
			_oval = [[self _renderLabelBackground] retain];
			_ovalRect = bounds;
		}
		
		if(_oval) {
			[backgroundColor set];
			[_oval fill];
		}
	}
	else {
		[backgroundColor set];
		NSRectFill([self frame]);
	}
	
	if(labelString == nil || [labelString length] == 0)
	   return;
	   
	NSDictionary* attributes = nil;
	
	//if(_label) {
		if(shadowed) {
			//[NSGraphicsContext saveGraphicsState]; 
			
			NSShadow* theShadow = [[[NSShadow alloc] init] autorelease]; 
			[theShadow setShadowOffset:NSMakeSize(0, -1.0)]; 
			[theShadow setShadowBlurRadius:1.1]; 
			[theShadow setShadowColor:shadowColor]; 
			[theShadow set];
			
			//[color set];
			//[_label fill];
			
			attributes = [[[NSDictionary alloc] initWithObjectsAndKeys:
								  font, NSFontAttributeName,
								  color, NSForegroundColorAttributeName,
								  theShadow, NSShadowAttributeName,
								  nil] autorelease];
			[labelString drawInRect:NSOffsetRect(labelRect, padX, padY) withAttributes:attributes];
			
			//[NSGraphicsContext restoreGraphicsState]; 
		}
		else {
			attributes = [[[NSDictionary alloc] initWithObjectsAndKeys:
										 font, NSFontAttributeName,
										 color, NSForegroundColorAttributeName,
										 nil] autorelease];

			//[color set];
			//[_label fill];
		}
	//}
	
	[labelString drawInRect:NSOffsetRect(labelRect, padX, padY) withAttributes:attributes];
}

- (void)setLabel:(NSString*)string
{
	if(labelString && [labelString isEqualToString:string])
		return;
	
	self.labelString = string;
	
	//[_label release];
	//_label = [[self _renderLabelString:string] retain];
	
	//labelRect = [_label bounds];
	if(string) {
		NSDictionary* attributes = [[[NSDictionary alloc] initWithObjectsAndKeys:
									font, NSFontAttributeName,
									nil] autorelease];
		NSSize size = [labelString sizeWithAttributes:attributes];
		labelRect = NSMakeRect(0.0, 0.0, size.width, size.height);
	}
}

@end
