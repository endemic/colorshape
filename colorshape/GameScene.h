//
//  GameScene.h
//  colorshape
//
//  Created by Nathan Demick on 8/8/11.
//  Copyright 2011 Ganbaru Games. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"
#import "GameConfig.h"

@interface GameScene : CCLayer 
{
	// Array which stores references to puzzle objects
	NSMutableArray *grid;
	
	// References to size of the playing grid
	int rows, cols, blockSize, gridOffset, visibleRows, visibleCols;
	
	// Variables for user interaction
	int touchRow, touchCol;
	CGPoint touchStart, touchPrevious, touchOffset;
	BOOL horizontalMove, verticalMove;
	
	// Various display bits
	int score, combo, level;
	CCLabelTTF *scoreLabel;
	CCLabelTTF *comboLabel;
	CCLabelTTF *levelLabel;
	
	// Patterned backgrounds that change as the game progresses
	CCSprite *bg;
	CCSprite *gridBg;
	
	float timeRemaining;						// Say a maximum of 30 seconds
	float timePlayed;							// Records how long the player has been playing
	CCProgressTimer *timeRemainingDisplay;		// kCCProgressTimerTypeVerticalBarBT
	
	// String to be appended to sprite filenames if required to use a high-rez file (e.g. iPhone 4 assets on iPad)
	NSString *hdSuffix;
	int fontMultiplier;    
}

+ (id)scene;

- (void)update:(ccTime)dt;
- (void)gameOver;

- (void)shiftLeft;
- (void)shiftRight;
- (void)shiftUp;
- (void)shiftDown;

- (void)resetBuffer;
- (void)matchCheck;

- (void)dropBlocks;
- (void)newBlockAtIndex:(int)index;
- (void)createParticlesAt:(CGPoint)position;
- (void)createStatusMessageAt:(CGPoint)position withText:(NSString *)text;
- (void)flash;

- (void)updateTime;
- (void)updateScore:(int)points;
- (void)comboCountdown;
- (void)updateCombo;
- (void)removeNodeFromParent:(CCNode *)node;

@end
