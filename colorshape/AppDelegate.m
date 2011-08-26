//
//  AppDelegate.m
//  colorshape
//
//  Created by Nathan Demick on 8/8/11.
//  Copyright Ganbaru Games 2011. All rights reserved.
//

#import "cocos2d.h"

#import "AppDelegate.h"
#import "GameConfig.h"
#import "TitleScene.h"
#import "GameScene.h"
#import "RootViewController.h"
#import "GameSingleton.h"
#import "SimpleAudioEngine.h"

@implementation AppDelegate

@synthesize window;

- (void) removeStartupFlicker
{
	//
	// THIS CODE REMOVES THE STARTUP FLICKER
	//
	// Uncomment the following code if you Application only supports landscape mode
	//
#if GAME_AUTOROTATION == kGameAutorotationUIViewController

//	CC_ENABLE_DEFAULT_GL_STATES();
//	CCDirector *director = [CCDirector sharedDirector];
//	CGSize size = [director winSize];
//	CCSprite *sprite = [CCSprite spriteWithFile:@"Default.png"];
//	sprite.position = ccp(size.width/2, size.height/2);
//	sprite.rotation = -90;
//	[sprite visit];
//	[[director openGLView] swapBuffers];
//	CC_ENABLE_DEFAULT_GL_STATES();
	
#endif // GAME_AUTOROTATION == kGameAutorotationUIViewController	
}
- (void) applicationDidFinishLaunching:(UIApplication*)application
{
	// Init the window
	window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	// Try to use CADisplayLink director
	// if it fails (SDK < 3.1) use the default director
	if( ! [CCDirector setDirectorType:kCCDirectorTypeDisplayLink] )
		[CCDirector setDirectorType:kCCDirectorTypeDefault];
	
	
	CCDirector *director = [CCDirector sharedDirector];
	
	// Init the View Controller
	viewController = [[RootViewController alloc] initWithNibName:nil bundle:nil];
	viewController.wantsFullScreenLayout = YES;
	
	//
	// Create the EAGLView manually
	//  1. Create a RGB565 format. Alternative: RGBA8
	//	2. depth format of 0 bit. Use 16 or 24 bit for 3d effects, like CCPageTurnTransition
	//
	//
	EAGLView *glView = [EAGLView viewWithFrame:[window bounds]
								   pixelFormat:kEAGLColorFormatRGB565	// kEAGLColorFormatRGBA8
								   depthFormat:0						// GL_DEPTH_COMPONENT16_OES
						];
	
	// attach the openglView to the director
	[director setOpenGLView:glView];
	
	// Init the shared game singleton and load serialized data
	[GameSingleton loadState];
	
	// Enables High Res mode (Retina Display) on iPhone 4 and maintains low res on all other devices
	if ([director enableRetinaDisplay:YES])
	{
		[GameSingleton sharedGameSingleton].isRetina = YES;
	}
	
	//
	// VERY IMPORTANT:
	// If the rotation is going to be controlled by a UIViewController
	// then the device orientation should be "Portrait".
	//
	// IMPORTANT:
	// By default, this template only supports Landscape orientations.
	// Edit the RootViewController.m file to edit the supported orientations.
	//
#if GAME_AUTOROTATION == kGameAutorotationUIViewController
	[director setDeviceOrientation:kCCDeviceOrientationPortrait];
#else
	//[director setDeviceOrientation:kCCDeviceOrientationLandscapeLeft];
#endif
	
	[director setAnimationInterval:1.0/60];
	//[director setDisplayFPS:YES];
	
	
	// make the OpenGLView a child of the view controller
	[viewController setView:glView];
	
	// make the View Controller a child of the main window
	[window addSubview: viewController.view];
	
	[window makeKeyAndVisible];
	
	// Default texture format for PNG/BMP/TIFF/JPEG/GIF images
	// It can be RGBA8888, RGBA4444, RGB5_A1, RGB565
	// You can change anytime.
	[CCTexture2D setDefaultAlphaPixelFormat:kCCTexture2DPixelFormat_RGBA8888];

	// Removes the startup flicker
	[self removeStartupFlicker];

	// Get user defaults
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Register default high scores - this could be more easily done by loading a .plist instead of manually creating this nested object
	NSDictionary *defaultDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
									 [NSArray arrayWithObjects:[NSNumber numberWithInt:0],
																		[NSNumber numberWithInt:0],
																		[NSNumber numberWithInt:0],
																		[NSNumber numberWithInt:0],
																		[NSNumber numberWithInt:0],
																		nil], @"scores",
									[NSNumber numberWithBool:YES], @"showInstructions", nil];
	
	[defaults registerDefaults:defaultDefaults];
	[defaults synchronize];
	
	NSString *hdSuffix;
	// This string gets appended onto all image filenames based on whether the game is on iPad or not
	if ([GameSingleton sharedGameSingleton].isPad)
	{
		hdSuffix = @"-hd";
	}
	else
	{
		hdSuffix = @"";
	}
	
	// If first time player has run the app, preload the "tutorial" images
	if ([defaults boolForKey:@"showInstructions"] == YES)
	{
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"1%@.png", hdSuffix]];
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"1%@.png", hdSuffix]];
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"1%@.png", hdSuffix]];
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"1%@.png", hdSuffix]];
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"1%@.png", hdSuffix]];
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"1%@.png", hdSuffix]];
	}
	
	// Preload particle image
	[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"particle%@.png", hdSuffix]];
	
	// Preload background images
	for (int i = 0; i < 10; i++)
	{
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"background-%i%@.png", i, hdSuffix]];
		[[CCTextureCache sharedTextureCache] addImage:[NSString stringWithFormat:@"grid-background-%i%@.png", i, hdSuffix]];
	}
	
	// Preload some simple audio
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"button.caf"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"move.caf"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"match2.caf"];
	
	// Preload a BGM track
	[[SimpleAudioEngine sharedEngine] preloadBackgroundMusic:@"1.caf"];
	
	// Turn down the BGM volume a bit
	[[SimpleAudioEngine sharedEngine] setBackgroundMusicVolume:0.35];
	
	// Run the intro Scene
	[[CCDirector sharedDirector] runWithScene: [TitleScene scene]];
}


- (void)applicationWillResignActive:(UIApplication *)application {
	[[CCDirector sharedDirector] pause];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	[[CCDirector sharedDirector] resume];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
	[[CCDirector sharedDirector] purgeCachedData];
}

-(void) applicationDidEnterBackground:(UIApplication*)application {
	[[CCDirector sharedDirector] stopAnimation];
}

-(void) applicationWillEnterForeground:(UIApplication*)application {
	[[CCDirector sharedDirector] startAnimation];
	
	[[GameSingleton sharedGameSingleton] authenticateLocalPlayer];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Serialize/save the contents of the shared game data singleton
	[GameSingleton saveState];
	
	CCDirector *director = [CCDirector sharedDirector];
	
	[[director openGLView] removeFromSuperview];
	
	[viewController release];
	
	[window release];
	
	[director end];	
}

- (void)applicationSignificantTimeChange:(UIApplication *)application {
	[[CCDirector sharedDirector] setNextDeltaTimeZero:YES];
}

- (void)dealloc {
	[[CCDirector sharedDirector] end];
	[window release];
	[super dealloc];
}

@end
