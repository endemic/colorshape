//
//  TitleScene.h
//  Yotsu Iro
//
//  Created by Nathan Demick on 5/25/11.
//  Copyright 2011 Ganbaru Games. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"

@interface TitleScene : CCLayer <UIAlertViewDelegate>
{
	// The "default" image
	CCSprite *bg;
	
	// Variables for the grid of colored blocks used as a background for this scene
	NSMutableArray *grid;
	int rows, cols, lastRow;
	
	// "Container" nodes used to move certain UI elements around
	CCNode *titleNode;
	CCNode *scoresNode;
	CCNode *infoNode;
	
	// Array used to store high scores labels
	NSMutableArray *highScoresLabels;
	
	// Button that shows Game Center leaderboards; disabled if no Game Center auth
	CCMenuItemImage *leaderboardsButton;
	
	// String to be appended to sprite filenames if required to use a high-rez file (e.g. iPhone 4 assests on iPad)
	NSString *hdSuffix;
	int fontMultiplier;
}

+ (id)scene;
- (void)showUI;
- (void)update:(ccTime)dt;
- (void)flash;
- (void)removeNodeFromParent:(CCNode *)node;

@end
