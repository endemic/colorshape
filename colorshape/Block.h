//
//  Block.h
//  Yotsu Iro
//
//  Created by Nathan Demick on 5/9/11.
//  Copyright 2011 Ganbaru Games. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"

@interface Block : CCSprite 
{
	NSString *colour;
	NSString *shape;
	CGPoint gridPosition;
}

@property (readwrite, retain) NSString *colour;
@property (readwrite, retain) NSString *shape;
@property (readwrite) CGPoint gridPosition;

// Have to override this method in order to subclass CCSprite
- (id)initWithTexture:(CCTexture2D *)texture rect:(CGRect)rect;

+ (id)random;	// Returns a random block

- (void)snapToGridPosition;
- (void)animateToGridPosition;
- (void)flash;
- (void)embiggen;
- (void)shrink;

@end
