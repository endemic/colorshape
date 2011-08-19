//
//  GameScene.m
//  colorshape
//
//  Created by Nathan Demick on 8/8/11.
//  Copyright 2011 Ganbaru Games. All rights reserved.
//

#import "GameScene.h"

#import "Block.h"
#import "TitleScene.h"

#import "CocosDenshion.h"
#import "SimpleAudioEngine.h"

#import "GameSingleton.h"
#import "GameConfig.h"

@implementation GameScene

+(id) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	GameScene *layer = [GameScene node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if ((self = [super init]))
	{
		// ask director the the window size
		CGSize windowSize = [[CCDirector sharedDirector] winSize];
		
		// This string gets appended onto all image filenames based on whether the game is on iPad or not
		if ([GameSingleton sharedGameSingleton].isPad)
		{
			hdSuffix = @"-hd";
			fontMultiplier = 2;
			blockSize = 80;
			touchOffset = CGPointMake(64, 64);
		}
		else
		{
			hdSuffix = @"";
			fontMultiplier = 1;
			blockSize = 40;
			touchOffset = CGPointMake(0, 0);
		}
		
		// Initialize some gameplay variables
		score = 0;
		combo = 0;
		level = 1;
		timeRemaining = kMaxTimeLimit;
		timePlayed = 0;
		
		// Background
		bg = [CCSprite spriteWithFile:[NSString stringWithFormat:@"background-%i%@.png", level, hdSuffix]];
		bg.position = ccp(windowSize.width / 2, windowSize.height / 2);
		if ([GameSingleton sharedGameSingleton].isRetina == YES)
		{
			// This is a hacky workaround to allow the iPad/iPhone4 to share backgrounds
			// MAGIC NUMBERS, SORRY
			bg.position = ccp(windowSize.width / 2, windowSize.height / 2 - 16);
			CCLOG(@"Trying to move the background position");
		}
        
		[self addChild:bg z:2];
		
		// Grid/puzzle background
		gridBg = [CCSprite spriteWithFile:[NSString stringWithFormat:@"grid-background-%i%@.png", level, hdSuffix]];
		gridBg.position = ccp(windowSize.width / 2, gridBg.contentSize.height / 2 + touchOffset.y);
		[self addChild:gridBg z:0];
		
		// Add game status UI
		CCSprite *topUi = [CCSprite spriteWithFile:[NSString stringWithFormat:@"top-ui-background%@.png", hdSuffix]];
		[topUi setPosition:ccp(windowSize.width / 2, windowSize.height - topUi.contentSize.height / 2)];
		[self addChild:topUi z:3];
		
		// Set combo counter
		comboLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%ix", combo] dimensions:CGSizeMake(97 * fontMultiplier, 58 * fontMultiplier) alignment:CCTextAlignmentRight fontName:@"Chalkduster.ttf" fontSize:36 * fontMultiplier];
		comboLabel.position = ccp(133, 38);
		if ([GameSingleton sharedGameSingleton].isPad)
			comboLabel.position = ccp(260, 76);
		comboLabel.color = ccc3(0, 0, 0);
		[topUi addChild:comboLabel z:4];
		
		// Set up level counter display
		levelLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%02d", level] dimensions:CGSizeMake(97 * fontMultiplier, 58 * fontMultiplier) alignment:CCTextAlignmentCenter fontName:@"Chalkduster.ttf" fontSize:36 * fontMultiplier];
		levelLabel.position = ccp(258, 38);
		if ([GameSingleton sharedGameSingleton].isPad)
			levelLabel.position = ccp(516, 76);
		levelLabel.color = ccc3(0, 0, 0);
		[topUi addChild:levelLabel z:4];
		
		// Set up score label
		scoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%08d", score] dimensions:CGSizeMake(210 * fontMultiplier, 57 * fontMultiplier) alignment:CCTextAlignmentRight fontName:@"Chalkduster.ttf" fontSize:32 * fontMultiplier];
		scoreLabel.position = ccp(183, 108);
		if ([GameSingleton sharedGameSingleton].isPad)
			scoreLabel.position = ccp(365, 216);
		[scoreLabel setColor:ccc3(0, 0, 0)];
		[topUi addChild:scoreLabel z:4];
		
		// Set up timer
		timeRemainingDisplay = [CCProgressTimer progressWithFile:[NSString stringWithFormat:@"timer-gradient%@.png", hdSuffix]];
		timeRemainingDisplay.type = kCCProgressTimerTypeVerticalBarBT;
		timeRemainingDisplay.percentage = 100.0;
		timeRemainingDisplay.position = ccp(48, 80);
		if ([GameSingleton sharedGameSingleton].isPad)
			timeRemainingDisplay.position = ccp(95, 158);
		[topUi addChild:timeRemainingDisplay z:4];
		
		rows = 10;
		cols = 10;
		gridOffset = 1;
		
		visibleRows = rows - gridOffset * 2;
		visibleCols = cols - gridOffset * 2;
        
		// Array w/ 100 spaces - 10x10
		int gridCapacity = rows * cols;
		grid = [[NSMutableArray arrayWithCapacity:gridCapacity] retain];
		
		// array[x + y*size] === array[x][y]
		for (int i = 0; i < gridCapacity; i++)
			[self newBlockAtIndex:i];
		
		// Reset the "buffer" blocks hidden around the outside of the screen
		[self resetBuffer];
		
		// Preload particle image
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"particle%@.png", hdSuffix]];
		
		// Preload background images
		for (int i = 0; i < 10; i++)
		{
			[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"background-%i%@.png", i, hdSuffix]];
			[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"grid-background-%i%@.png", i, hdSuffix]];
		}
		
		// Schedule an update method
		[self scheduleUpdate];
		
		// Play random music track
		int trackNumber = (float)(arc4random() % 100) / 100 * 3 + 1;	// 1 - 3
		[[SimpleAudioEngine sharedEngine] playBackgroundMusic:[NSString stringWithFormat:@"%i.caf", trackNumber]];
		
		// Set the layer to respond to touch events
		[self setIsTouchEnabled:YES];
		
		// Display "ready?" "go!" text
//		CCSprite *ready = [CCSprite spriteWithFile:[NSString stringWithFormat:@"ready%@.png", hdSuffix]];
//		ready.position = ccp(windowSize.width / 2, windowSize.height / 2);
//		ready.visible = false;
//		[self addChild:ready];

		/* example code */
		
//		id move = [CCMoveTo actionWithDuration:randomTime position:ccp(x * blockSize - blockSize / 2, y * blockSize + blockSize / 2)];
//		id ease = [CCEaseIn actionWithAction:move rate:2];
//		id sfx = [CCCallBlock actionWithBlock:^{
//			[[SimpleAudioEngine sharedEngine] playEffect:@"block-fall.caf"];
//		}];
//		id recursive = [CCCallFuncN actionWithTarget:self selector:@selector(dropNextBlockAfter:)];
//		
//		[b runAction:[CCSequence actions:ease, sfx, recursive, nil]];
		
	}
	return self;
}

- (void)update:(ccTime)dt
{
	// Increment the total time played this game
	timePlayed += dt;
	
	// Game over condition
	if (timeRemaining < 0)
	{
		timeRemaining = 0;
		
		[self gameOver];
	}
	
	// 30 seconds is max time limit; multipy by 100 to get value between 0 - 100
	timeRemainingDisplay.percentage = timeRemaining / kMaxTimeLimit * 100;
}


/*
 Do all sorts of nonsense after time runs out
 */
- (void)gameOver
{
	[self setIsTouchEnabled:NO];
	
	// Unschedule this update method
	[self unscheduleUpdate];
	
	// ask director the the window size
	CGSize windowSize = [[CCDirector sharedDirector] winSize];
	
	[self flash];
	
	// Game over, man!
	CCSprite *gameOverText = [CCSprite spriteWithFile:[NSString stringWithFormat:@"game-over%@.png", hdSuffix]];
	[gameOverText setPosition:ccp(windowSize.width / 2, windowSize.height / 2)];
	[self addChild:gameOverText z:3];
    
	CCMenuItemImage *retryButton = [CCMenuItemImage itemFromNormalImage:[NSString stringWithFormat:@"retry-button%@.png", hdSuffix] selectedImage:[NSString stringWithFormat:@"retry-button-selected%@.png", hdSuffix] block:^(id sender) {
		// Play SFX
		[[SimpleAudioEngine sharedEngine] playEffect:@"button.caf"];
		
		// Reload this scene
		CCTransitionFlipX *transition = [CCTransitionFlipX transitionWithDuration:0.5 scene:[GameScene scene] orientation:kOrientationUpOver];
		[[CCDirector sharedDirector] replaceScene:transition];
	}];
	
	CCMenuItemImage *quitButton = [CCMenuItemImage itemFromNormalImage:[NSString stringWithFormat:@"quit-button%@.png", hdSuffix] selectedImage:[NSString stringWithFormat:@"quit-button-selected%@.png", hdSuffix] block:^(id sender) {
		// Play SFX
		[[SimpleAudioEngine sharedEngine] playEffect:@"button.caf"];
		
		// Go to title scene
		CCTransitionFlipX *transition = [CCTransitionFlipX transitionWithDuration:0.5 scene:[TitleScene node] orientation:kOrientationUpOver];
		[[CCDirector sharedDirector] replaceScene:transition];
	}];
	
	CCMenu *gameOverMenu = [CCMenu menuWithItems:retryButton, quitButton, nil];
	[gameOverMenu alignItemsVerticallyWithPadding:10];
	[gameOverMenu setPosition:ccp(windowSize.width / 2, gameOverText.position.y - retryButton.contentSize.height * 3)];
	[self addChild:gameOverMenu z:3];
	
	// Send score to Game Center based on game type
	if ([GameSingleton sharedGameSingleton].gameMode == kGameModeNormal)
	{
		[[GameSingleton sharedGameSingleton] reportScore:score forCategory:@"com.ganbarugames.colorshape.normal"];
		NSLog(@"Trying to report a high score!");
	}
	
	// Get scores array stored in user defaults
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Get high scores array from "defaults" object
	NSMutableArray *highScores = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"scores"]];
	
	// Iterate thru high scores; see if current point value is higher than any of the stored values
	for (int i = 0; i < [highScores count]; i++)
	{
		if (score >= [[highScores objectAtIndex:i] intValue])
		{
			// Insert new high score, which pushes all others down
			[highScores insertObject:[NSNumber numberWithInt:score] atIndex:i];
			
			// Remove last score, so as to ensure only 5 entries in the high score array
			[highScores removeLastObject];
			
			// Re-save scores array to user defaults
			[defaults setObject:highScores forKey:@"scores"];
			
			[defaults synchronize];
			
			NSLog(@"Saved new high score of %i", score);
			
			// Bust out of the loop 
			break;
		}
	}
}

- (void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Determine touched row/column and store starting touch point
	UITouch *touch = [touches anyObject];
	
	CGPoint touchPoint = [[CCDirector sharedDirector] convertToGL:[touch locationInView:[touch view]]];
	
	touchStart = touchPrevious = touchPoint;
	horizontalMove = verticalMove = NO;
	
	touchRow = (touchPoint.y - touchOffset.y) / blockSize + gridOffset;
	touchCol = (touchPoint.x - touchOffset.x) / blockSize + gridOffset;
	
    //	NSMutableString *tmp = [NSMutableString stringWithString:@""];
    //	for (int i = touchRow * rows; i < touchRow * rows + cols; i++)	// Check row values
    //	//for (int i = touchCol; i < rows * cols; i += cols)					// Check column values
    //		[tmp appendFormat:@"%i ", [[grid objectAtIndex:i] number]];
    //	NSLog(tmp);
}

- (void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Determine the row/column that is touched
	// Determine whether movement is vertical or horizontal
	UITouch *touch = [touches anyObject];
	
	CGPoint touchPoint = [[CCDirector sharedDirector] convertToGL:[touch locationInView:[touch view]]];
	CGPoint touchDiff = ccp(touchPoint.x - touchPrevious.x, touchPoint.y - touchPrevious.y);
	
	// Determine whether the movement is horiz/vert
	int startDiffX = fabs(touchPoint.x - touchStart.x);
	int startDiffY = fabs(touchPoint.y - touchStart.y);
	
	if (!horizontalMove && !verticalMove)
	{
		if (startDiffX > startDiffY)
		{
			horizontalMove = YES;
		}
		else
		{
			verticalMove = YES;
		}
	}
	
	// Allow some leniency if player moves slightly vertically, but then wants to move horizontally (or vice versa)
	if (horizontalMove && startDiffY > startDiffX && startDiffX < 5)
	{		
		// Snap row back to position
		for (int i = 0; i < cols; i++)
		{
			Block *s = [grid objectAtIndex:touchRow * cols + i];
			[s snapToGridPosition];
		}
		
		// Change to vertical move
		verticalMove = YES;
		horizontalMove = NO;
		
		// Reset the row/column being stored
		touchRow = touchPoint.y / blockSize + gridOffset;
		touchCol = touchPoint.x / blockSize + gridOffset;
		
		// Reset the starting touch
		touchStart = touchPoint;
	}
	else if (verticalMove && startDiffX > startDiffY && startDiffY < 5)
	{		
		// Snap row back to position
		for (int i = 0; i < cols; i++)
		{
			Block *s = [grid objectAtIndex:touchCol + cols * i];
			[s snapToGridPosition];
		}
		
		// Change to horizontal move
		verticalMove = NO;
		horizontalMove = YES;
		
		// Reset the row/column being stored
		touchRow = touchPoint.y / blockSize + gridOffset;
		touchCol = touchPoint.x / blockSize + gridOffset;
		
		// Reset the starting touch
		touchStart = touchPoint;
	}
	
	if (horizontalMove)
	{
		// Move each block in the row based on the difference on the x-axis
		int touchDiffX = touchDiff.x;
		for (int i = 0; i < cols; i++)
		{
			Block *s = [grid objectAtIndex:touchRow * cols + i];
			[s setPosition:ccp(s.position.x + touchDiffX % blockSize, s.position.y)];
		}
		
		int d = touchStart.x - touchPoint.x;
		
		// Move left
		if (d >= blockSize)
		{
			// Handle very fast movement
			for (int i = 0; i < floor(d / blockSize); i++)
			{
				[self shiftLeft];
				
				for (int i = 0; i < cols; i++)
				{
					// Move to position
					Block *s = [grid objectAtIndex:touchRow * cols + i];
					[s snapToGridPosition];
				}
			}
            
			// Reset the "start" position
			touchStart = touchPoint;
            
			// Play SFX
			[[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
			
			// Decrement the "move" counter
			timeRemaining--;
		}
		// Move right
		else if (d <= -blockSize)
		{
			for (int i = 0; i > floor(d / blockSize); i--)
			{
				[self shiftRight];
				
				for (int i = 0; i < cols; i++)
				{
					// Move to position
					Block *s = [grid objectAtIndex:touchRow * cols + i];
					[s snapToGridPosition];
				}
			}
			
			// Reset the "start" position
			touchStart = touchPoint;
            
			// Play SFX
			[[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
			
			// Decrement the "move" counter
			timeRemaining--;
		}
	}
	else if (verticalMove)
	{
		// Move each block in the row based on the difference on the y-axis
		int touchDiffY = touchDiff.y;
		for (int i = 0; i < cols; i++)
		{
			Block *s = [grid objectAtIndex:touchCol + cols * i];
			[s setPosition:ccp(s.position.x, s.position.y + touchDiffY % blockSize)];
		}
		
		int d = touchStart.y - touchPoint.y;
		
		// Move down
		if (d >= blockSize)
		{
			for (int i = 0; i < floor(d / blockSize); i++)
			{
				[self shiftDown];
				
				for (int i = 0; i < cols; i++)
				{
					// Move to position
					Block *s = [grid objectAtIndex:touchCol + cols * i];
					[s snapToGridPosition];
				}
			}
			
			// Reset the "start" position
			touchStart = touchPoint;
            
			// Play SFX
			[[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
			
			// Decrement the "move" counter
			timeRemaining--;
		}
		// Move up
		else if (d <= -blockSize)
		{
			for (int i = 0; i > floor(d / blockSize); i--)
			{
				[self shiftUp];
				
				for (int i = 0; i < cols; i++)
				{
					// Move to position
					Block *s = [grid objectAtIndex:touchCol + cols * i];
					[s snapToGridPosition];
				}
			}
			
			// Reset the "start" position
			touchStart = touchPoint;
            
			// Play SFX
			[[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
			
			// Decrement the "move" counter
			timeRemaining--;
		}
	}
	
	touchPrevious = touchPoint;
}

- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Initiate action to snap row/column back to nearest grid position
	UITouch *touch = [touches anyObject];
	
	CGPoint touchPoint = [[CCDirector sharedDirector] convertToGL:[touch locationInView:[touch view]]];
	CGPoint touchDiff = ccp(touchPoint.x - touchStart.x, touchPoint.y - touchStart.y);
	
	if (horizontalMove)
	{
		// Move back to original position
		if (touchDiff.x <= blockSize / 2 && touchDiff.x >= -blockSize / 2)
		{
			for (int i = touchRow * rows; i < touchRow * rows + cols; i++)
			{
				Block *s = [grid objectAtIndex:i];
				[s animateToGridPosition];
				
			}
		}
		// Shift either left or right
		else if (touchDiff.x < -blockSize / 2)
		{
			// Shift grid
			[self shiftLeft];
			
			// Need to move last sprite in array row to its' correct display position
			Block *last = [grid objectAtIndex:touchRow * rows + (cols - 1)];
			[last snapToGridPosition];
			
			// Animate the entire row to snap back to position
			for (int i = touchRow * rows; i < touchRow * rows + cols; i++)
			{
				Block *s = [grid objectAtIndex:i];
				[s animateToGridPosition];
			}
			
			// Play SFX
			[[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
			
			// Decrement the "move" counter
			timeRemaining--;
		}
		else if (touchDiff.x > blockSize / 2)
		{
			// Shift grid
			[self shiftRight];
			
			// Need to move first sprite in array row to its' correct display position
			Block *first = [grid objectAtIndex:touchRow * rows];
			[first snapToGridPosition];
            
			// Animate the entire row to snap back to position
			for (int i = touchRow * rows; i < touchRow * rows + cols; i++)
			{
				Block *s = [grid objectAtIndex:i];
				[s animateToGridPosition];
			}
			
			// Play SFX
			[[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
			
			// Decrement the "move" counter
			timeRemaining--;
		}
	}
	else if (verticalMove)
	{
		// Move back to original position
		if (touchDiff.y <= blockSize / 2 && touchDiff.y >= -blockSize / 2)
		{
			for (int i = touchCol; i < rows * cols; i += cols)
			{
				Block *s = [grid objectAtIndex:i];
				[s animateToGridPosition];
			}
		}
		// Shift either up or down
		else if (touchDiff.y < -blockSize / 2)
		{
			// Shift down
			[self shiftDown];
			
			// Need to move last sprite in array column to its' correct display position
			Block *last = [grid objectAtIndex:touchCol + (cols - 1) * cols];
			[last snapToGridPosition];
            
			// Animate the entire column to snap back to position
			for (int i = touchCol; i < rows * cols; i += cols)
			{
				Block *s = [grid objectAtIndex:i];
				[s animateToGridPosition];
			}
			
			// Play SFX
			[[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
			
			// Decrement the "move" counter
			timeRemaining--;
		}
		else if (touchDiff.y > blockSize / 2)
		{
			// Shift up
			[self shiftUp];
			
			// Need to move first sprite in array column to its' correct display position
			Block *first = [grid objectAtIndex:touchCol];
			[first snapToGridPosition];
			
			// Animate the entire column to snap back to position
			for (int i = touchCol; i < rows * cols; i += cols)
			{
				Block *s = [grid objectAtIndex:i];
				[s animateToGridPosition];
			}
			
			// Play SFX
			[[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
			
			// Decrement the "move" counter
			timeRemaining--;
		}
	}
	
	// Schedule the matchCheck method to be run after everything finishes animating
	[self schedule:@selector(matchCheck) interval:kAnimationDuration];
}

- (void)shiftLeft
{
	// Store first value
	Block *tmp = [grid objectAtIndex:touchRow * rows];
	
	// Cycle through the rest of the blocks in a row
	for (int i = touchRow * rows; i < touchRow * rows + (cols - 1); i++)
	{
		// Shift left
		[grid replaceObjectAtIndex:i withObject:[grid objectAtIndex:i + 1]];
		
		// Update index of Block obj
		int x = i % cols;
		int y = floor(i / rows);
		[[grid objectAtIndex:i] setGridPosition:ccp(x, y)];
	}
    
	// Place first value at end of array row
	int i = touchRow * rows + (cols - 1);
	[grid replaceObjectAtIndex:i withObject:tmp];
	
	// Update index of Block obj
	int x = i % cols;
	int y = floor(i / rows);
	[[grid objectAtIndex:i] setGridPosition:ccp(x, y)];
	
	[self resetBuffer];
	
	//NSLog(@"Shift left");
}

- (void)shiftRight
{
	// Store last value
	Block *tmp = [grid objectAtIndex:touchRow * rows + (cols - 1)];
	
	// Shift right
	for (int i = touchRow * rows + (cols - 1); i > touchRow * rows; i--)
	{
		[grid replaceObjectAtIndex:i withObject:[grid objectAtIndex:i - 1]];
		
		// Update index of Block obj
		int x = i % cols;
		int y = floor(i / rows);
		[[grid objectAtIndex:i] setGridPosition:ccp(x, y)];
	}
    
	// Place last value in front of array row
	int i = touchRow * rows;
	[grid replaceObjectAtIndex:i withObject:tmp];
	
	// Update index of Block obj
	int x = i % cols;
	int y = floor(i / rows);
	[[grid objectAtIndex:i] setGridPosition:ccp(x, y)];
    
	[self resetBuffer];
	
	//NSLog(@"Shift right");
}

- (void)shiftUp
{
	// Store last value
	Block *tmp = [grid objectAtIndex:touchCol + rows * (cols - 1)];
	
	// Shift up
	for (int i = touchCol + rows * (cols - 1); i > touchCol; i -= cols)
	{
		[grid replaceObjectAtIndex:i withObject:[grid objectAtIndex:i - cols]];
		
		// Update index of Block obj
		int x = i % cols;
		int y = floor(i / rows);
		[[grid objectAtIndex:i] setGridPosition:ccp(x, y)];
	}
	
	// Place last value in front of array row
	int i = touchCol;
	[grid replaceObjectAtIndex:i withObject:tmp];
	
	// Update index of Block obj
	int x = i % cols;
	int y = floor(i / rows);
	[[grid objectAtIndex:i] setGridPosition:ccp(x, y)];
	
	[self resetBuffer];
	
	//NSLog(@"Shift up");
}

- (void)shiftDown
{
	// Store first value
	Block *tmp = [grid objectAtIndex:touchCol];
	
	// Shift down
	for (int i = touchCol; i < touchCol + rows * (cols - 1); i += cols)
	{
		[grid replaceObjectAtIndex:i withObject:[grid objectAtIndex:i + cols]];
		
		// Update index of Block obj
		int x = i % cols;
		int y = floor(i / rows);
		[[grid objectAtIndex:i] setGridPosition:ccp(x, y)];
	}
	
	// Place first value at end of array row
	int i = touchCol + rows * (cols - 1);
	[grid replaceObjectAtIndex:i withObject:tmp];
	
	// Update index of Block obj
	int x = i % cols;
	int y = floor(i / rows);
	[[grid objectAtIndex:i] setGridPosition:ccp(x, y)];
	
	[self resetBuffer];
	
	//NSLog(@"Shift down");
}

- (void)resetBuffer
{
	// Bottom
	for (int i = 1; i < rows - 1; i++)
	{
		Block *source = [grid objectAtIndex:(rows * (cols - 2)) + i];
		Block *destination = [grid objectAtIndex:i];
		destination.colour = source.colour;
		destination.shape = source.shape;
		destination.texture = source.texture;
	}
	
	// Put blocks from first visible row (bottom) into top offscreen buffer
	for (int i = 1; i < rows - 1; i++)
	{
		Block *source = [grid objectAtIndex:rows + i];
		Block *destination = [grid objectAtIndex:(rows * (cols - 1)) + i];
		destination.colour = source.colour;
		destination.shape = source.shape;
		destination.texture = source.texture;
	}
	
	// Left
	for (int i = 1; i < cols - 1; i++)
	{
		Block *source = [grid objectAtIndex:i * rows + (cols - 2)];
		Block *destination = [grid objectAtIndex:i * rows];
		destination.colour = source.colour;
		destination.shape = source.shape;
		destination.texture = source.texture;
	}
	
	// Right
	for (int i = 1; i < cols - 1; i++)
	{
		Block *source = [grid objectAtIndex:i * rows + 1];
		Block *destination = [grid objectAtIndex:i * rows + (cols - 1)];
		destination.colour = source.colour;
		destination.shape = source.shape;
		destination.texture = source.texture;
		
		//NSLog(@"Source: %i, desintation: %i", i * rows + 1, i * rows + (cols - 1));
	}
}

- (void)matchCheck
{
	// Go thru and check for matching colors/shapes - first horizontally, then vertically
	// Only go through indices 1 - 8
	
	// Temporarily disable player input
	[self setIsTouchEnabled:NO];
	
	NSMutableArray *colorArray = [NSMutableArray arrayWithCapacity:8];
	NSMutableArray *shapeArray = [NSMutableArray arrayWithCapacity:8];
	NSMutableArray *removeArray = [NSMutableArray arrayWithCapacity:16];	// Arbitrary capacity
	NSMutableString *previousColor = [NSMutableString stringWithString:@""];
	NSMutableString *previousShape = [NSMutableString stringWithString:@""];
	
	int minimumMatchCount = kMinimumMatchCount;		// Number of adjacent blocks needed to disappear
	Block *b;
	
	// Find horizontal matches
	for (int i = gridOffset; i < rows - gridOffset; i++)
	{
		// for each block in row
		for (int j = i * rows + gridOffset; j < i * rows + cols - gridOffset; j++)
		{
			b = [grid objectAtIndex:j];
			
			// Condition in order to add the first block to the "set"
			if (j == i * rows + gridOffset)
			{
				[previousColor setString:b.colour];
				[previousShape setString:b.shape];
			}
			
			// Check color
			if ([b.colour isEqualToString:previousColor])
			{
				[colorArray addObject:[NSNumber numberWithInt:j]];
			}
			else
			{
				// If the set array has enough objects, add them to the "removal" array
				if ([colorArray count] >= minimumMatchCount)
					[removeArray addObjectsFromArray:colorArray];
                
				// Reset the set
				[colorArray removeAllObjects];
				
				// Add current block
				[colorArray addObject:[NSNumber numberWithInt:j]];
			}
			
			// Check shape
			if ([b.shape isEqualToString:previousShape])
			{
				[shapeArray addObject:[NSNumber numberWithInt:j]];
			}
			else
			{
				// If the set array has enough objects, add them to the "removal" array
				if ([shapeArray count] >= minimumMatchCount)
					[removeArray addObjectsFromArray:shapeArray];
                
				// Reset the set
				[shapeArray removeAllObjects];
				
				// Add current block
				[shapeArray addObject:[NSNumber numberWithInt:j]];
			}
			
			// reset the previous color comparison
			[previousColor setString:b.colour];
			
			// reset the previous shape comparison
			[previousShape setString:b.shape];
			
		}	// End col for loop
		
		// Do another check here at the end of the row for both shape & color
		if ([shapeArray count] >= minimumMatchCount)
			[removeArray addObjectsFromArray:shapeArray];
		
		if ([colorArray count] >= minimumMatchCount)
			[removeArray addObjectsFromArray:colorArray];
		
		// Remove all blocks in matching arrays at the end of a row
		[shapeArray removeAllObjects];
		[colorArray removeAllObjects];
	}	// End row for loop
	
	// Find vertical matches
	for (int i = gridOffset; i < cols - gridOffset; i++)
	{
		// For each block in column
		for (int j = i + rows; j < rows * (cols - gridOffset) + i; j += rows)
		{
			b = [grid objectAtIndex:j];
			
			// Condition in order to add the first block to the "set"
			if (j == i + rows)
			{
				[previousColor setString:b.colour];
				[previousShape setString:b.shape];
			}
			
			// Check color
			if ([b.colour isEqualToString:previousColor])
			{
				[colorArray addObject:[NSNumber numberWithInt:j]];
			}
			else
			{
				// If the set array has enough objects, add them to the "removal" array
				if ([colorArray count] >= minimumMatchCount)
					[removeArray addObjectsFromArray:colorArray];
				
				// Reset the set
				[colorArray removeAllObjects];
				
				// Add current block
				[colorArray addObject:[NSNumber numberWithInt:j]];
			}
			
			// Check shape
			if ([b.shape isEqualToString:previousShape])
			{
				[shapeArray addObject:[NSNumber numberWithInt:j]];
			}
			else
			{
				// If the set array has enough objects, add them to the "removal" array
				if ([shapeArray count] >= minimumMatchCount)
					[removeArray addObjectsFromArray:shapeArray];
				
				// Reset the set
				[shapeArray removeAllObjects];
				
				// Add current block
				[shapeArray addObject:[NSNumber numberWithInt:j]];
			}
			
			// reset the previous color comparison
			[previousColor setString:b.colour];
			
			// reset the previous shape comparison
			[previousShape setString:b.shape];
		}	// End of each block in column
		
		// Do another check here at the end of the row for both shape & color
		if ([shapeArray count] >= minimumMatchCount)
			[removeArray addObjectsFromArray:shapeArray];
		
		if ([colorArray count] >= minimumMatchCount)
			[removeArray addObjectsFromArray:colorArray];
		
		// Remove all blocks in matching arrays at the end of a column
		[shapeArray removeAllObjects];
		[colorArray removeAllObjects];
	}
    
	// Play SFX if blocks are removed and run the check again after the specified interval
	if ([removeArray count] > 0)
	{
		[[SimpleAudioEngine sharedEngine] playEffect:@"match2.caf"];
		
		// Increment combo counter
		combo++;
		[comboLabel setString:[NSString stringWithFormat:@"%ix", combo]];
		
		// Unschedule the method which depletes the combo counter
		[self unschedule:@selector(updateCombo)];
	}
	// If no matches, unschedule the check
	else
	{
		[self unschedule:@selector(matchCheck)];
		
		// Re-enable player input
		[self setIsTouchEnabled:YES];
		
		// If there was a high combo count, display to player
		if (combo > 0)
		{
			// "count down" the combo counter after a short delay
			[self runAction:[CCSequence actions:
							 [CCDelayTime actionWithDuration:1.5],
							 [CCCallFunc actionWithTarget:self selector:@selector(comboCountdown)],
							 nil]];
		}
	}
	
	// Remove all blocks with indices in removeArray
	for (int i = 0, j = [removeArray count]; i < j; i++)
        //for (NSNumber num in removeArray)
	{
		int gridIndex = [[removeArray objectAtIndex:i] intValue];
		Block *remove = [grid objectAtIndex:gridIndex];
		
		if (remove)
		{
			[self createParticlesAt:remove.position];
			[self removeChild:remove cleanup:NO];
			[grid replaceObjectAtIndex:gridIndex withObject:[NSNull null]];
			
			// Drop more blocks in to replace the ones that were removed
			[self dropBlocks];
			
			// Update score, using the current combo count as a multiplier
			[self updateScore:10 * combo];
			
			// Update time limit
			[self updateTime];
			
			if (combo < 1)
				NSLog(@"ZOMG, combo is less than one!");
		}
	}
    
	// Finally, clear out the removeSet array
	[removeArray removeAllObjects];
}

/**
 * Iterate through the puzzle grid and cause blocks to "fall" into openings made by matches
 */
- (void)dropBlocks
{
	// ask director the the window size
	CGSize windowSize = [[CCDirector sharedDirector] winSize];
	
	// Array to store any open positions within the game grid columns
	NSMutableArray *open = [NSMutableArray arrayWithCapacity:rows];
	
	for (int i = gridOffset; i <= visibleCols; i++)
	{
		//NSLog(@"Checking column %i", i);
		for (int j = i + cols; j < (cols - gridOffset) * rows; j += rows)
		{
			//NSLog(@"Checking block %i: %@", j, [grid objectAtIndex:j]);
			if ([grid objectAtIndex:j] == [NSNull null])
			{
				//NSLog(@"Empty space at %i", j);
				[open addObject:[NSNumber numberWithInt:j]];
			}
			else if ([open count] > 0)
			{
				// Move this block into the first open space, then add this space into the open space array
				// NSMutableArray removeObjectAtIndex:0 behaves the same as a "shift" operation -- all other indices are moved by subtracting 1 from their index
				int newIndex = [[open objectAtIndex:0] intValue];
				[open removeObjectAtIndex:0];
				
				// Move the block down
				[grid replaceObjectAtIndex:newIndex withObject:[grid objectAtIndex:j]];
				
				// Update the x/y grid values here
				int x = newIndex % cols;
				int y = floor(newIndex / rows);
				[[grid objectAtIndex:newIndex] setGridPosition:ccp(x, y)];
				[[grid objectAtIndex:newIndex] animateToGridPosition];
				
				// Replace old index w/ null obj
				[grid replaceObjectAtIndex:j withObject:[NSNull null]];
				
				// Add old index to open array
				[open addObject:[NSNumber numberWithInt:j]];
			}
		}
		// End of a column; go through remaining indices in "open" and add new blocks
		for (int k = 0; k < [open count]; k++)
		{
			int newIndex = [[open objectAtIndex:k] intValue];
			[open removeObjectAtIndex:k];
			
            //			if ([grid objectAtIndex:newIndex] != [NSNull null])
            //				NSLog(@"Trying to replace non-null object at %i", newIndex);
			
			[self newBlockAtIndex:newIndex];
			
			Block *b = [grid objectAtIndex:newIndex];
			b.position = ccp(b.position.x, b.position.y + windowSize.height);
			[b animateToGridPosition];
		}
	}
}

- (void)newBlockAtIndex:(int)index
{
	// Create new random block
	Block *b = [Block random];
	
	// Determine its x/y position within the game grid
	int x = index % cols;
	int y = floor(index / rows);
	[b setGridPosition:ccp(x, y)];
	
	// Move it to the correct location in grid
	[b snapToGridPosition];
    
	// Add to layer
	[self addChild:b z:1];
	
	// Do a check here to see if we need to replace an object or insert
	if ([grid count] > index && [grid objectAtIndex:index] != nil)
	{
		[grid replaceObjectAtIndex:index withObject:b];
	}
	else
	{
		[grid insertObject:b atIndex:index];
	}
}

- (void)createParticlesAt:(CGPoint)position
{
	// Create quad particle system (faster on 3rd gen & higher devices, only slightly slower on 1st/2nd gen)
	CCParticleSystemQuad *particleSystem = [[CCParticleSystemQuad alloc] initWithTotalParticles:25];
	
	// duration is for the emitter
	[particleSystem setDuration:0.25f];
	
	[particleSystem setEmitterMode:kCCParticleModeGravity];
	
	// Gravity Mode: gravity
	[particleSystem setGravity:ccp(0, -200)];
	
	// Gravity Mode: speed of particles
	[particleSystem setSpeed:140];
	[particleSystem setSpeedVar:40];
	
	// Gravity Mode: radial
	[particleSystem setRadialAccel:-150];
	[particleSystem setRadialAccelVar:-100];
	
	// Gravity Mode: tagential
	[particleSystem setTangentialAccel:0];
	[particleSystem setTangentialAccelVar:0];
	
	// angle
	[particleSystem setAngle:90];
	[particleSystem setAngleVar:360];
	
	// emitter position
	[particleSystem setPosition:position];
	[particleSystem setPosVar:CGPointZero];
	
	// life is for particles particles - in seconds
	[particleSystem setLife:0.5f];
	[particleSystem setLifeVar:0.25f];
	
	// size, in pixels
	[particleSystem setStartSize:8.0f];
	[particleSystem setStartSizeVar:2.0f];
	[particleSystem setEndSize:kCCParticleStartSizeEqualToEndSize];
	
	// emits per second
	[particleSystem setEmissionRate:[particleSystem totalParticles] / [particleSystem duration]];
	
	// color of particles
	ccColor4F startColor = {1.0f, 1.0f, 1.0f, 1.0f};
	ccColor4F endColor = {1.0f, 1.0f, 1.0f, 1.0f};
	[particleSystem setStartColor:startColor];
	[particleSystem setEndColor:endColor];
	
	[particleSystem setTexture:[[CCTextureCache sharedTextureCache] addImage:@"particle.png"]];
	// [[CCTextureCache sharedTextureCache] textureForKey:@"particle.png"]];
	
	// additive
	[particleSystem setBlendAdditive:NO];
	
	// Auto-remove the emitter when it is done!
	[particleSystem setAutoRemoveOnFinish:YES];
	
	// Add to layer
	[self addChild:particleSystem z:10];
	
	//NSLog(@"Tryin' to make a particle emitter at %f, %f", position.x, position.y);
}

/**
 Create a bitmap font label, add to layer, then animate off the screen
 */
- (void)createStatusMessageAt:(CGPoint)position withText:(NSString *)text
{
	// Create a label and add it to the layer
	CCLabelBMFont *label = [CCLabelBMFont labelWithString:text fntFile:[NSString stringWithFormat:@"chalkduster-16%@.fnt", hdSuffix]];
	label.position = position;
	[self addChild:label z:10];		// Should be z-positioned on top of everything
	
	// Run some move/fade actions
	CCMoveBy *move = [CCMoveBy actionWithDuration:1.5 position:ccp(0, label.contentSize.height)];
	CCFadeOut *fade = [CCFadeOut actionWithDuration:1];
	CCCallFuncN *remove = [CCCallFuncN actionWithTarget:self selector:@selector(removeNodeFromParent:)];
	
	[label runAction:[CCSequence actions:[CCSpawn actions:move, fade, nil], remove, nil]];
}

- (void)flash
{
	// ask director the the window size
	CGSize windowSize = [[CCDirector sharedDirector] winSize];
	
	// Add a white, screen-sized .png to scene
	CCSprite *flash = [CCSprite spriteWithFile:[NSString stringWithFormat:@"flash%@.png", hdSuffix]];
	flash.position = ccp(windowSize.width / 2, windowSize.height / 2);
	[self addChild:flash z:10];
	
	// Fade the .png out, then remove it
	[flash runAction:[CCSequence actions:
                      [CCFadeOut actionWithDuration:0.5],
                      [CCCallFuncN actionWithTarget:self selector:@selector(removeNodeFromParent:)],
                      nil]];
	
	// Play SFX
	[[SimpleAudioEngine sharedEngine] playEffect:@"explode.caf"];
}

- (void)updateTime
{
	// Only allow player to gain back time if playing in "Normal" mode
	if ([GameSingleton sharedGameSingleton].gameMode == kGameModeNormal)
	{
		// Calculate how much extra time the player gets
		float additionalTime = (0.5 / level) * combo;
		timeRemaining += additionalTime;
		
		CGPoint location;
		if ([GameSingleton sharedGameSingleton].isPad)
		{
			location = ccp(160, 770);
		}
		else
		{
			location = ccp(50, 380);
		}
		
		// Create a "+1" status message
		[self createStatusMessageAt:location withText:[NSString stringWithFormat:@"+%0.1f", additionalTime]];
		
		// Enforce max time limit
		if (timeRemaining > kMaxTimeLimit)
		{
			timeRemaining = kMaxTimeLimit;
		}
	}
	// In "Time Attack", player has to make the most matches within the set time limit
}

- (void)updateScore:(int)points
{
	score += points;
	[scoreLabel setString:[NSString stringWithFormat:@"%08d", score]];
	
	if (floor(score / 1500) >= level)
	{
		level++;
		[levelLabel setString:[NSString stringWithFormat:@"%02d", level]];
		
		// Change game background!
		[bg setTexture:[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"background-%i%@.png", level % 10, hdSuffix]]];
		[gridBg setTexture:[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"grid-background-%i%@.png", level % 10, hdSuffix]]];
	}
}

- (void)comboCountdown
{	
	// Speed at which counter counts down is dependent on how large the counter is
	float interval = 2.0 / combo;
	
	NSLog(@"Combo countdown interval is %f", interval);
	
	// Schedule a method which counts down
	[self schedule:@selector(updateCombo) interval:interval];
}

- (void)updateCombo
{
	// Decrement and update display
	if (combo > 0)
	{	
		combo--;
	}
    
	[comboLabel setString:[NSString stringWithFormat:@"%ix", combo]];
	
	// Unschedule this if count is zero
	if (combo < 1)
	{
		[self unschedule:@selector(updateCombo)];
	}
}

- (void)removeNodeFromParent:(CCNode *)node
{
	[node.parent removeChild:node cleanup:YES];
	
	// Trying this from forum post http://www.cocos2d-iphone.org/forum/topic/981#post-5895
	// Apparently fixes a memory error?
    //	CCNode *parent = node.parent;
    //	[node retain];
    //	[parent removeChild:node cleanup:YES];
    //	[node autorelease];
}

// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	// in case you have something to dealloc, do it in this method
	// in this particular example nothing needs to be released.
	// cocos2d will automatically release all the children (Label)
	[grid release];
	
	
	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
