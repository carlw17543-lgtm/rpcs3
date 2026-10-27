#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wold-style-cast"
#import <UIKit/UIKit.h>

#include "core_bridge.h"

@interface RPCS3ViewController : UIViewController
@end

@implementation RPCS3ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.backgroundColor = UIColor.systemBackgroundColor;

	UILabel* label = [[UILabel alloc] init];
	label.translatesAutoresizingMaskIntoConstraints = NO;
	label.numberOfLines = 0;
	label.textAlignment = NSTextAlignmentCenter;

	NSString* status = [NSString stringWithUTF8String:rpcs3_ios_core_status().c_str()];
	label.text = [@"RPCS3 for iOS\n\n" stringByAppendingString:status];
	[self.view addSubview:label];

	UILayoutGuide* margins = self.view.layoutMarginsGuide;
	[NSLayoutConstraint activateConstraints:@[
		[label.centerYAnchor constraintEqualToAnchor:margins.centerYAnchor],
		[label.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
		[label.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
	]];
}

@end

@interface RPCS3SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow* window;
@end

@implementation RPCS3SceneDelegate

- (void)scene:(UIScene*)scene willConnectToSession:(UISceneSession*)session options:(UISceneConnectionOptions*)connectionOptions
{
	self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene*)scene];
	self.window.rootViewController = [[RPCS3ViewController alloc] init];
	[self.window makeKeyAndVisible];
}

@end

// The scene configuration in Info.plist names RPCS3SceneDelegate, so the app delegate needs no code yet
@interface RPCS3AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation RPCS3AppDelegate
@end

int main(int argc, char* argv[])
{
	@autoreleasepool
	{
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([RPCS3AppDelegate class]));
	}
}
#pragma GCC diagnostic pop
