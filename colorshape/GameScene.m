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
		
		// Set up timer AKA "move counter"
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
		
		// Fill grid with puzzle blocks
		// Ensure that each block is sufficiently different from adjacent ones so that no matches will occur when the board is generated
		for (int i = 0; i < gridCapacity; i++) 
		{
			BOOL valid = YES;

			do 
			{
				[self newBlockAtIndex:i];
				
				// Check the current block color/shape vs. the one to the left and the one below
				Block *b = [grid objectAtIndex:i];
				
				// Check against left
				if (i > 0)
				{
					Block *c = [grid objectAtIndex:i - 1];
					//NSLog(@"Comparing index %i vs. %i", i, i - 1);
					if ([c.colour isEqualToString:b.colour] || [c.shape isEqualToString:b.shape])
					{
						valid = NO;
					}
					else
					{
						valid = YES;
					}
				}
				
				// Check against below
				if (i > cols)
				{
					Block *d = [grid objectAtIndex:i - cols];
					//NSLog(@"Comparing index %i vs. %i", i, i - cols);
					if ([d.colour isEqualToString:b.colour] || [d.shape isEqualToString:b.shape])
					{
						valid = NO;
					}
					else
					{
						valid = YES;
					}
				}
			} 
			while (valid == NO);
		}
		
		// Reset the "buffer" blocks hidden around the outside of the screen
		[self resetBuffer];
		
		// Schedule an update method
		[self scheduleUpdate];
		
		// Play random music track
		int trackNumber = (float)(arc4random() % 100) / 100 * 3 + 1;	// 1 - 3
		[[SimpleAudioEngine sharedEngine] playBackgroundMusic:[NSString stringWithFormat:@"%i.caf", trackNumber]];
		
		// Set the layer to not respond to touch events - will wait until "ready?" "start!" message is displayed
		[self setIsTouchEnabled:NO];
		
		// Get user defaults
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		if ([defaults boolForKey:@"showInstructions"] == YES)
		{
			// Run the "show instructions" method
			[self showInstructions];
			
			// Save defaults so the instructions aren't shown again
			[defaults setObject:[NSNumber numberWithBool:NO] forKey:@"showInstructions"];
			[defaults synchronize];
		}
		else
		{
			// Show the "ready" "start" message
			[self showReadyMessage];
		}
	}
	return self;
}

- (void)showReadyMessage
{
	// ask director the the window size
	CGSize windowSize = [[CCDirector sharedDirector] winSize];
	
	// This string gets appended onto all image filenames based on whether the game is on iPad or not
	if ([GameSingleton sharedGameSingleton].isPad)
	{
		hdSuffix = @"-hd";
	}
	else
	{
		hdSuffix = @"";
	}
	
	// Display "ready?" "start!" text
	CCSprite *ready = [CCSprite spriteWithFile:[NSString stringWithFormat:@"ready%@.png", hdSuffix]];
	ready.position = ccp(windowSize.width / 2, windowSize.height / 2 - ready.contentSize.height / 2);
	ready.opacity = 0;
	[self addChild:ready z:2];
	
	CCSprite *start = [CCSprite spriteWithFile:[NSString stringWithFormat:@"start%@.png", hdSuffix]];
	start.position = ccp(windowSize.width / 2, windowSize.height / 2 - start.contentSize.height / 2);
	start.opacity = 0;
	[self addChild:start z:2];
	
	// Move/fade the "ready?" "start!" text into place, and enable layer touch when finished
	id move = [CCMoveTo actionWithDuration:0.4 position:ccp(windowSize.width / 2, windowSize.height / 2)];
	id ease = [CCEaseBackOut actionWithAction:move];
	id fadeIn = [CCFadeIn actionWithDuration:0.3];
	id wait = [CCDelayTime actionWithDuration:0.8];
	id fadeOut = [CCFadeOut actionWithDuration:0.2];
	id remove = [CCCallFuncN actionWithTarget:self selector:@selector(removeNodeFromParent:)];
	id enableTouch = [CCCallBlock actionWithBlock:^{
		[self setIsTouchEnabled:YES];
	}];
	id next = [CCCallBlock actionWithBlock:^{
		id startSequence = [CCSequence actions:[CCSpawn actions:ease, fadeIn, nil], wait, fadeOut, remove, enableTouch, nil];
		[start runAction:startSequence];
	}];
	
	id readySequence = [CCSequence actions:wait, [CCSpawn actions:ease, fadeIn, nil], wait, fadeOut, remove, next, nil];
	
	// Run the move/fade simultaneously
	[ready runAction:readySequence];
}

- (void)showInstructions
{
	// ask director the the window size
	CGSize windowSize = [[CCDirector sharedDirector] winSize];
	
	// This string gets appended onto all image filenames based on whether the game is on iPad or not
	if ([GameSingleton sharedGameSingleton].isPad)
	{
		hdSuffix = @"-hd";
	}
	else
	{
		hdSuffix = @"";
	}
	
	/*
	 Actions
	 */
	
	// Move/fade the instructional images into place, then show the "ready" "start" message when finished
	id move = [CCMoveTo actionWithDuration:0.4 position:ccp(windowSize.width / 2, windowSize.height / 2)];
	id ease = [CCEaseBackOut actionWithAction:move];
	id fadeIn = [CCFadeIn actionWithDuration:0.3];
	id wait = [CCDelayTime actionWithDuration:0.8];
	id fadeOut = [CCFadeOut actionWithDuration:0.2];
	id remove = [CCCallFuncN actionWithTarget:self selector:@selector(removeNodeFromParent:)];
	
	id show = [CCSpawn actions:ease, fadeIn, nil];
		
	/* 
	 Create all "tutorial" sprites 
	 */
	
	CCSprite *stepOne = [CCSprite spriteWithFile:[NSString stringWithFormat:@"1%@.png", hdSuffix]];
	stepOne.position = ccp(windowSize.width / 2, windowSize.height / 2 - windowSize.height / 10);	// Slightly below the final place where the image will be displayed
	stepOne.opacity = 0;	// Hide the image initially
	[self addChild:stepOne z:4];
	
	CCSprite *stepTwo = [CCSprite spriteWithFile:[NSString stringWithFormat:@"2%@.png", hdSuffix]];
	stepTwo.position = ccp(windowSize.width / 2, windowSize.height / 2 - windowSize.height / 10);	// Slightly below the final place where the image will be displayed
	stepTwo.opacity = 0;	// Hide the image initially
	[self addChild:stepTwo z:4];
	
	CCSprite *stepThree = [CCSprite spriteWithFile:[NSString stringWithFormat:@"3%@.png", hdSuffix]];
	stepThree.position = ccp(windowSize.width / 2, windowSize.height / 2 - windowSize.height / 10);	// Slightly below the final place where the image will be displayed
	stepThree.opacity = 0;	// Hide the image initially
	[self addChild:stepThree z:4];
	
	CCSprite *stepFour = [CCSprite spriteWithFile:[NSString stringWithFormat:@"4%@.png", hdSuffix]];
	stepFour.position = ccp(windowSize.width / 2, windowSize.height / 2 - windowSize.height / 10);	// Slightly below the final place where the image will be displayed
	stepFour.opacity = 0;	// Hide the image initially
	[self addChild:stepFour z:4];
	
	CCSprite *stepFive = [CCSprite spriteWithFile:[NSString stringWithFormat:@"5%@.png", hdSuffix]];
	stepFive.position = ccp(windowSize.width / 2, windowSize.height / 2 - windowSize.height / 10);	// Slightly below the final place where the image will be displayed
	stepFive.opacity = 0;	// Hide the image initially
	[self addChild:stepFive z:4];
	
	CCSprite *stepSix = [CCSprite spriteWithFile:[NSString stringWithFormat:@"6%@.png", hdSuffix]];
	stepSix.position = ccp(windowSize.width / 2, windowSize.height / 2 - windowSize.height / 10);	// Slightly below the final place where the image will be displayed
	stepSix.opacity = 0;	// Hide the image initially
	[self addChild:stepSix z:4];
	
	/*
	 Create button and menu
	 */
	CCMenuItemImage *nextButton = [CCMenuItemImage itemFromNormalImage:[NSString stringWithFormat:@"next-button%@.png", hdSuffix] selectedImage:[NSString stringWithFormat:@"next-button-selected%@.png", hdSuffix] block:^(id sender) {
		
		[[SimpleAudioEngine sharedEngine] playEffect:@"button.caf"];
		
		// Increase the step value - will this work?
		static int step = 1;
		step++;
		
		switch (step)
		{
			case 2:
				// Hide the first step, then remove it from the layer
				[stepOne runAction:[CCSequence actions:fadeOut, remove, nil]];
				
				// Show the second step
				[stepTwo runAction:show];
				break;
			case 3:
				// Hide the second step, then remove it from the layer
				[stepTwo runAction:[CCSequence actions:fadeOut, remove, nil]];
				
				// Show the third step
				[stepThree runAction:show];
				break;
			case 4:
				// Hide the third step, then remove it from the layer
				[stepThree runAction:[CCSequence actions:fadeOut, remove, nil]];
				
				// Show the fourth step
				[stepFour runAction:show];
				break;
			case 5:
				// Hide the fourth step, then remove it from the layer
				[stepFour runAction:[CCSequence actions:fadeOut, remove, nil]];
				
				// Show the fifth step
				[stepFive runAction:show];
				break;
			case 6:
				// Hide the fifth step, then remove it from the layer
				[stepFive runAction:[CCSequence actions:fadeOut, remove, nil]];
				
				// Show the sixth step
				[stepSix runAction:show];
				break;
			case 7:
				// Hide the sixth step, then remove it from the layer
				[stepSix runAction:[CCSequence actions:fadeOut, remove, nil]];
				
				// Hide the button and remove it from the layer
				[sender runAction:[CCSequence actions:fadeOut, remove, nil]];
				
				// Show the "ready?" "start!" message
				[self showReadyMessage];
				break;
		}
	}];
	
	// Hide the button
	nextButton.opacity = 0;
	
	// Create menu that contains our buttons
	CCMenu *nextMenu = [CCMenu menuWithItems:nextButton, nil];
	
	// Set position of menu to be at bottom of screen
	nextMenu.position = ccp(windowSize.width / 2, nextButton.contentSize.height / 1.5);
	
	// Add menu to layer
	[self addChild:nextMenu z:2];
	
	// Tell the first step to show
	[stepOne runAction:[CCSequence actions:wait, show, [CCCallBlock actionWithBlock:^{
		// Tell the first button to show after the first step appears
		[nextButton runAction:[CCSequence actions:wait, fadeIn, nil]];
	}], nil]];
	
	//NSLog(@"Trying to show instructions!");
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
	// Prevent any block movement
	[self setIsTouchEnabled:NO];
	
	// Unschedule the update method
	[self unscheduleUpdate];
	
	// Unschedule the block match-checking method
	[self unschedule:@selector(matchCheck:)];
	
	// Visual effeckuts
	[self flash];
	
	// Stop playing muzak
	[[SimpleAudioEngine sharedEngine] stopBackgroundMusic];

	// ask director the the window size
	CGSize windowSize = [[CCDirector sharedDirector] winSize];
	
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
			
			//NSLog(@"Saved new high score of %i", score);
			
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
	
	// Prevent "out of bounds" touches
	if (touchRow > rows - 1 || touchCol > cols - 1)
	{
		horizontalMove = verticalMove = NO;
	}
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
	
	// Prevent "out of bounds" touches
	if (touchRow > rows - 1 || touchCol > cols - 1)
	{
		horizontalMove = verticalMove = NO;
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
	[self schedule:@selector(matchCheck:) interval:kAnimationDuration];
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
	}
}

- (void)matchCheck:(ccTime)dt
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
				if ([colorArray count] >= kMinimumMatchCount)
				{
					[removeArray addObject:[NSArray arrayWithArray:colorArray]];
				}
                
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
				if ([shapeArray count] >= kMinimumMatchCount)
				{
					[removeArray addObject:[NSArray arrayWithArray:shapeArray]];
				}
                
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
		if ([shapeArray count] >= kMinimumMatchCount)
		{
			[removeArray addObject:[NSArray arrayWithArray:shapeArray]];
		}
		
		if ([colorArray count] >= kMinimumMatchCount)
		{
			[removeArray addObject:[NSArray arrayWithArray:colorArray]];
		}
		
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
				if ([colorArray count] >= kMinimumMatchCount)
				{
					[removeArray addObject:[NSArray arrayWithArray:colorArray]];
				}
				
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
				if ([shapeArray count] >= kMinimumMatchCount)
				{
					[removeArray addObject:[NSArray arrayWithArray:shapeArray]];
				}
				
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
		if ([shapeArray count] >= kMinimumMatchCount)
		{
			[removeArray addObject:[NSArray arrayWithArray:shapeArray]];
		}
		
		if ([colorArray count] >= kMinimumMatchCount)
		{
			[removeArray addObject:[NSArray arrayWithArray:colorArray]];
		}
		
		// Remove all blocks in matching arrays at the end of a column
		[shapeArray removeAllObjects];
		[colorArray removeAllObjects];
	}
    
	// Play SFX if blocks are removed and run the check again after the specified interval
	if ([removeArray count] > 0)
	{
		[[SimpleAudioEngine sharedEngine] playEffect:@"match2.caf"];
		
		// Increment combo counter - each object in the removeArray is actually another array containing matched blocks
		// so the length of removeArray equals the number of simultaneous matches
		combo += [removeArray count];
		[comboLabel setString:[NSString stringWithFormat:@"%ix", combo]];
		
		// Unschedule the method which depletes the combo counter
		[self unschedule:@selector(updateCombo)];
	}
	// If no matches, unschedule the check
	else
	{
		[self unschedule:@selector(matchCheck:)];
		
		// Re-enable player input
		[self setIsTouchEnabled:YES];
		
		// If there was a high combo count, display to player
		if (combo > 0)
		{
			// "count down" the chain counter after a short delay
			[self runAction:[CCSequence actions:
							 [CCDelayTime actionWithDuration:kChainCountdownDelay],
							 [CCCallFunc actionWithTarget:self selector:@selector(comboCountdown)],
							 nil]];
		}
	}
	
	// Remove all blocks with indices in removeArray
	for (int i = 0, j = [removeArray count]; i < j; i++)
	{
		// Each object in removeArray is another array that contains block indices
		NSArray *match = [removeArray objectAtIndex:i];
		
		// Try to determine the "center point" of each match
		CGPoint averagePosition = ccp(0, 0);
		
		for (int k = 0, l = [match count]; k < l; k++)
		{
			// Each object in each "match" array is a grid index
			int gridIndex = [[match objectAtIndex:k] intValue];
			Block *b = [grid objectAtIndex:gridIndex];
			
			if (b)
			{
				// Figure out the average "position" of the blocks in order to show a status message/effect
				averagePosition = ccpAdd(averagePosition, b.position);
				
				// Remove the matched block
				[self removeChild:b cleanup:YES];
				
				// Replace it with a "null" object
				[grid replaceObjectAtIndex:gridIndex withObject:[NSNull null]];
				
				// Call the method which replaces each "null" object in the game grid with a new block
				[self dropBlocks];
				
				// Update score, using the current combo count as a multiplier
				[self updateScore:kPointsPerBlock * combo];
				
				// Update time limit
				[self updateTime];
			}
		}	// End of each block in match loop
		
		// Average the position points, then create a particle effect there
		averagePosition = ccpMult(averagePosition, 1.0 / [match count]);
		
		// Create particles at that position
		[self createParticlesAt:averagePosition];
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
		for (int j = i + cols; j < (cols - gridOffset) * rows; j += rows)
		{
			if ([grid objectAtIndex:j] == [NSNull null])
			{
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
    
	// Do a check here to see if we need to replace an object or insert
	if ([grid count] > index && [grid objectAtIndex:index] != nil)
	{
		// Remove the previous block sprite from the scene, if necessary
		if ([self.children containsObject:[grid objectAtIndex:index]])
		{
			[self removeChild:[grid objectAtIndex:index] cleanup:YES];
		}
		
		[grid replaceObjectAtIndex:index withObject:b];
	}
	else
	{
		[grid insertObject:b atIndex:index];
	}
	
	// Add to layer
	[self addChild:b z:1];
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
	[particleSystem setBlendAdditive:YES];
	
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
	int defaultFontSize = 16;
	// Create a label and add it to the layer
	CCLabelBMFont *label = [CCLabelBMFont labelWithString:text 
												  fntFile:[NSString stringWithFormat:@"chalkduster-%i.fnt", defaultFontSize * fontMultiplier]];
	label.position = position;
	[self addChild:label z:10];		// Should be z-positioned on top of everything
	
	// Run some move/fade actions
	CCMoveBy *move = [CCMoveBy actionWithDuration:1.5 position:ccp(0, label.contentSize.height)];
	CCEaseBackOut *ease = [CCEaseBackOut actionWithAction:move];
	CCFadeOut *fade = [CCFadeOut actionWithDuration:1];
	CCCallFuncN *remove = [CCCallFuncN actionWithTarget:self selector:@selector(removeNodeFromParent:)];
	
	[label runAction:[CCSequence actions:[CCSpawn actions:ease, fade, nil], remove, nil]];
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
	
	//NSLog(@"Combo countdown interval is %f", interval);
	
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
