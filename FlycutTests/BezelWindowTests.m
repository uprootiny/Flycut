#import <XCTest/XCTest.h>
#import "BezelWindow.m"

@interface BezelWindowTests : XCTestCase
@property (nonatomic, strong) BezelWindow *window;
@end

@implementation BezelWindowTests

- (void)setUp {
    [super setUp];
    NSRect frame = NSMakeRect(0, 0, 400, 400);
    self.window = [[BezelWindow alloc] initWithContentRect:frame
                                                styleMask:NSWindowStyleMaskBorderless
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
}

- (void)tearDown {
    self.window = nil;
    [super tearDown];
}

- (void)testVisualEffectPresence {
    XCTAssertNotNil(self.window.visualEffectView, @"Visual effect view should be initialized");
    XCTAssertTrue([self.window.contentView.subviews containsObject:self.window.visualEffectView], @"Visual effect view should be in hierarchy");
}

- (void)testGimbalMappingConstraints {
    // Test that extreme gimbal inputs don't crash and maintain sanity
    [self.window updateWithGimbalX:1.0 y:1.0];
    XCTAssertGreaterThan(self.window.alphaValue, 0.0, @"Alpha should remain visible");
    
    [self.window updateWithGimbalX:-10.0 y:-10.0]; // Stress test
    XCTAssertLessThanOrEqual(self.window.alphaValue, 1.0, @"Alpha should never exceed 1.0");
}

- (void)testLayoutRobustness {
    XCTAssertNotNil(self.window.iconView, @"Icon view must be present");
    XCTAssertNotNil(self.window.previewLabel, @"Preview label must be present");
    
    // Ensure views are within window bounds
    XCTAssertTrue(NSContainsRect(self.window.contentView.bounds, self.window.iconView.frame), @"Icon view should be within bounds");
}

@end
