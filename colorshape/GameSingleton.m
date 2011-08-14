//
//  GameSingleton.m
//  Yotsu Iro
//
//  Created by Nathan Demick on 6/11/11.
//  Copyright 2011 Ganbaru Games. All rights reserved.
//

#import "SynthesizeSingleton.h"
#import "GameSingleton.h"

@implementation GameSingleton

@synthesize isPad, isRetina, showIntroAnimation, gameMode, restoreGame, points, combo, level, timeRemaining, timePlayed, hasGameCenter, unsentScores;

SYNTHESIZE_SINGLETON_FOR_CLASS(GameSingleton);

- (id)init 
{
	if ((self = [super init]))
	{
		// Check if running on iPad
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
			isPad = YES;
		else
			isPad = NO;
		
		// Check if Game Center exists
		if ([self isGameCenterAPIAvailable])
			hasGameCenter = YES;
		else
			hasGameCenter = NO;
		
		// Trigger the intro animation to be shown once
		showIntroAnimation = YES;
		
		isRetina = NO;
	}
	return self;
}

#pragma mark -
#pragma mark Game Center methods

- (BOOL)isGameCenterAPIAvailable
{
	// Check for presence of GKLocalPlayer class
	BOOL localPlayerClassAvailable = (NSClassFromString(@"GKLocalPlayer")) != nil;
	
	// Device must be running 4.1 or later
	NSString *reqSysVer = @"4.1";
	NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
	BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
	
	return (localPlayerClassAvailable && osVersionSupported);
}

- (void)authenticateLocalPlayer
{
	if ([self isGameCenterAPIAvailable])
	{
		GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
		[localPlayer authenticateWithCompletionHandler:^(NSError *error) {
			if (localPlayer.isAuthenticated)
			{
				// Perform additional tasks for the authenticated player
				hasGameCenter = YES;
				
				// If unsent scores array has length > 0, try to send saved scores here
				if ([unsentScores count] > 0)
				{
					// Create new array to help remove successfully sent scores
					NSMutableArray *removedScores = [NSMutableArray array];
					
					for (GKScore *score in unsentScores)
					{
						[score reportScoreWithCompletionHandler:^(NSError *error) {
							if (error != nil)
							{
								// If there's an error reporting the score (again!), leave the score in the array
							}
							else
							{
								// If success, remove that obj
								[removedScores addObject:score];
							}
						}];
					}
					
					// Remove successfully sent scores from stored array
					[unsentScores removeObjectsInArray:removedScores];
				}
			}
			else
			{
				// Disable Game Center
				hasGameCenter = NO;
			}
		}];
	}
}

- (void) reportScore:(int64_t)score forCategory:(NSString *)category
{
	if (hasGameCenter)
	{
		GKScore *scoreReporter = [[[GKScore alloc] initWithCategory:category] autorelease];
		scoreReporter.value = score;
		
		[scoreReporter reportScoreWithCompletionHandler:^(NSError *error) {
			if (error != nil)
			{
				// Handle reporting error here by adding object to a serializable array, to be sent again later
				[unsentScores addObject:scoreReporter];
				
				//NSLog(@"Error sending score!");
			}
		}];
	}
}

- (void)showLeaderboardForCategory:(NSString *)category
{
	if (hasGameCenter)
	{
		GKLeaderboardViewController *leaderboardController = [[GKLeaderboardViewController alloc] init];
		if (leaderboardController != nil)
		{
			// Leaderboard config
			leaderboardController.leaderboardDelegate = self;	// The leaderboard view controller will send messages to this object
			leaderboardController.category = category;	// Set category here
			leaderboardController.timeScope = GKLeaderboardTimeScopeAllTime;	// GKLeaderboardTimeScopeToday, GKLeaderboardTimeScopeWeek, GKLeaderboardTimeScopeAllTime
			
			// Create an additional UIViewController to attach the GKLeaderboardViewController to
			myViewController = [[UIViewController alloc] init];
			
			// Add the temporary UIViewController to the main OpenGL view
			[[[CCDirector sharedDirector] openGLView] addSubview:myViewController.view];
			
			// Tell UIViewController to present the leaderboard
			[myViewController presentModalViewController:leaderboardController animated:YES];
		}
	}
}

- (void)leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController
{
	[myViewController dismissModalViewControllerAnimated:YES];
	//[myViewController.view.superview removeFromSuperview];
	[myViewController release];
}

#pragma mark -
#pragma mark Object Serialization

+ (void)loadState
{
	@synchronized([GameSingleton class]) 
	{
		// just in case loadState is called before GameSingleton inits
		if(!sharedGameSingleton)
			[GameSingleton sharedGameSingleton];
		
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
		// NSString *file = [documentsDirectory stringByAppendingPathComponent:kSaveFileName];
		NSString *file = [documentsDirectory stringByAppendingPathComponent:@"GameSingleton.bin"];
		Boolean saveFileExists = [[NSFileManager defaultManager] fileExistsAtPath:file];
		
		if(saveFileExists) 
		{
			// don't need to set the result to anything here since we're just getting initwithCoder to be called.
			// if you try to overwrite sharedGameSingleton here, an assert will be thrown.
			[NSKeyedUnarchiver unarchiveObjectWithFile:file];
		}
	}
}

+ (void)saveState
{
	@synchronized([GameSingleton class]) 
	{  
		GameSingleton *state = [GameSingleton sharedGameSingleton];
		
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
		// NSString *saveFile = [documentsDirectory stringByAppendingPathComponent:kSaveFileName];
		NSString *saveFile = [documentsDirectory stringByAppendingPathComponent:@"GameSingleton.bin"];
		
		[NSKeyedArchiver archiveRootObject:state toFile:saveFile];
	}
}

#pragma mark -
#pragma mark NSCoding Protocol Methods

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeBool:self.isPad forKey:@"isPad"];
	[coder encodeBool:self.restoreGame forKey:@"restoreGame"];
	
	[coder encodeInt:self.points forKey:@"points"];
	[coder encodeInt:self.combo forKey:@"combo"];
	[coder encodeInt:self.level forKey:@"level"];
	
	[coder encodeFloat:self.timeRemaining forKey:@"timeRemaining"];
	[coder encodeFloat:self.timePlayed forKey:@"timePlayed"];
	
	[coder encodeBool:self.hasGameCenter forKey:@"hasGameCenter"];
	[coder encodeObject:self.unsentScores forKey:@"unsentScores"];
}

- (id)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init])) 
	{
		self.isPad = [coder decodeBoolForKey:@"isPad"];
		self.restoreGame = [coder decodeBoolForKey:@"restoreGame"];
		
		self.points = [coder decodeIntForKey:@"points"];
		self.combo = [coder decodeIntForKey:@"combo"];
		self.level = [coder decodeIntForKey:@"level"];
		
		self.timeRemaining = [coder decodeFloatForKey:@"timeRemaining"];
		self.timePlayed = [coder decodeFloatForKey:@"timePlayed"];
		
		self.hasGameCenter = [coder decodeBoolForKey:@"hasGameCenter"];
		self.unsentScores = [coder decodeObjectForKey:@"unsentScores"];
	}
	return self;
}

@end
