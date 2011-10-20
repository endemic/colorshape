//
//  Block.m
//  Yotsu Iro
//
//  Created by Nathan Demick on 5/9/11.
//  Copyright 2011 Ganbaru Games. All rights reserved.
//

#import "Block.h"
#import "GameSingleton.h"
#import "GameConfig.h"

@implementation Block

@synthesize colour, shape, gridPosition;

// The init method we have to override - http://www.cocos2d-iphone.org/wiki/doku.php/prog_guide:sprites (bottom of page)
- (id)initWithTexture:(CCTexture2D*)texture rect:(CGRect)rect
{
	// Call the init method of the parent class (CCSprite)
	if ((self = [super initWithTexture:texture rect:rect]))
	{
		// Set a default grid position so other helper methods don't bork if grid position isn't set
		[self setGridPosition:ccp(0, 0)];
	}
	return self;
}

+ (Block *)random
{
	int randomColorNumber = (float)(arc4random() % 100) / 100 * 4;
	int randomShapeNumber = (float)(arc4random() % 100) / 100 * 4;
	NSString *color;
	NSString *shape;
	
	switch (randomColorNumber)
	{
		case 0: color = @"red"; break;
		case 1: color = @"green"; break;
		case 2: color = @"blue"; break;
		case 3: color = @"yellow"; break;
	}
	
	switch (randomShapeNumber)
	{
		case 0: shape = @"star"; break;
		case 1: shape = @"clover"; break;
		case 2: shape = @"heart"; break;
		case 3: shape = @"diamond"; break;
	}
	
	Block *b;
	
	if ([GameSingleton sharedGameSingleton].isPad)
	{
		// Use different sprites for iPad
		b = [self spriteWithFile:[NSString stringWithFormat:@"%@-%@-hd.png", color, shape]];
	}
	else
	{
		// Use normal/Retina sprites
		b = [self spriteWithFile:[NSString stringWithFormat:@"%@-%@.png", color, shape]];
	}
	
	[b setColour:color];
	[b setShape:shape];
	
	return b;
}

- (void)snapToGridPosition
{
	CGPoint gridOffset;
	
	if ([GameSingleton sharedGameSingleton].isPad)
	{
		// Offset of the grid's position when using iPad
		gridOffset = CGPointMake(64, 64);
	}
	else
	{
		gridOffset = CGPointMake(0, 0);
	}
	
	// Determine the correct x/y position of the block by using its' grid indices, sprite size, and the "offset" (for iPad display)
	int x = (self.gridPosition.x * self.contentSize.width) - (self.contentSize.width / 2) + gridOffset.x;
	int y = (self.gridPosition.y * self.contentSize.height) - (self.contentSize.height / 2) + gridOffset.y;
	
	[self setPosition:ccp(x, y)];
}

- (void)animateToGridPosition
{
	CGPoint gridOffset;
	
	if ([GameSingleton sharedGameSingleton].isPad)
	{
		// Offset of the grid's position when using iPad
		gridOffset = CGPointMake(64, 64);
	}
	else
	{
		gridOffset = CGPointMake(0, 0);
	}
	
	// Determine the correct x/y position of the block by using its' grid indices, sprite size, and the "offset" (for iPad display)
	int x = (self.gridPosition.x * self.contentSize.width) - (self.contentSize.width / 2) + gridOffset.x;
	int y = (self.gridPosition.y * self.contentSize.height) - (self.contentSize.height / 2) + gridOffset.y;
	
	id action = [CCMoveTo actionWithDuration:kAnimationDuration position:ccp(x, y)];
//	id ease = [CCEaseBackOut actionWithAction:action];		// original easing action
	id ease = [CCEaseIn actionWithAction:action rate:4];
	[self runAction:ease];
}

// Debug helper method
- (void)flash
{
	//+(id) actionWithDuration: (ccTime) t blinks: (unsigned int) b
	id action = [CCBlink actionWithDuration:1.0f blinks:5];
	[self runAction:action];
}

- (void)embiggen
{
	// Make totally invisibly small!
	[self setScale:0];
	
	// Create action to scale back to normal
	id action = [CCScaleTo actionWithDuration:0.25f scale:1.0];
	
	// Run the action!
	[self runAction:action];
}

- (void)shrink
{
	// Create action to scale down to ZERO
	id action = [CCScaleTo actionWithDuration:kAnimationDuration scale:0.0];
	id ease = [CCEaseBackIn actionWithAction:action];
	
	// Run the action!
	[self runAction:ease];
}

@end
