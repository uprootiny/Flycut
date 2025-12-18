//
//  FlycutOperatorTests.m
//  ConchisTests
//
//  Unit tests for FlycutOperator - the coordinator between stores and UI.
//  Tests cover stack navigation, favorites, clipping operations, and state management.
//

#import <XCTest/XCTest.h>
#import "FlycutOperator.h"
#import "FlycutStore.h"
#import "FlycutClipping.h"

@interface FlycutOperatorTests : XCTestCase
@property (nonatomic, retain) FlycutOperator *operator;
@end

@implementation FlycutOperatorTests

- (void)setUp {
    [super setUp];

    // Reset user defaults for consistent testing
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:100] forKey:@"rememberNum"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:40] forKey:@"favoritesRememberNum"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"removeDuplicates"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"pasteMovesToTop"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.operator = [[FlycutOperator alloc] init];
    [self.operator awakeFromNibDisplaying:10 withDisplayLength:40 withSaveSelector:nil forTarget:nil];
}

- (void)tearDown {
    [self.operator release];
    self.operator = nil;
    [super tearDown];
}

#pragma mark - Helper Methods

- (void)addTestClippings:(int)count {
    for (int i = 0; i < count; i++) {
        [self.operator addClipping:[NSString stringWithFormat:@"Clipping %d", i]
                            ofType:@"public.utf8-plain-text"
                           fromApp:@"TestApp"
                    withAppBundleURL:nil
                            target:nil
              clippingAddedSelector:nil];
    }
}

#pragma mark - Initialization Tests

- (void)testInitialization {
    XCTAssertNotNil(self.operator, @"Operator should initialize");
    XCTAssertEqual([self.operator jcListCount], 0, @"New operator should have empty store");
    XCTAssertEqual([self.operator stackPosition], 0, @"Initial stack position should be 0");
}

- (void)testRememberNum {
    XCTAssertEqual([self.operator rememberNum], 100, @"Remember num should match user defaults");
}

#pragma mark - Add Clipping Tests

- (void)testAddClipping {
    bool result = [self.operator addClipping:@"Test content"
                                      ofType:@"public.utf8-plain-text"
                                     fromApp:@"Safari"
                              withAppBundleURL:nil
                                      target:nil
                        clippingAddedSelector:nil];

    XCTAssertTrue(result, @"Adding valid clipping should succeed");
    XCTAssertEqual([self.operator jcListCount], 1, @"Store should have one clipping");
}

- (void)testAddMultipleClippings {
    [self addTestClippings:5];
    XCTAssertEqual([self.operator jcListCount], 5, @"Store should have 5 clippings");
}

- (void)testAddEmptyClipping {
    bool result = [self.operator addClipping:@""
                                      ofType:@"text"
                                     fromApp:@"App"
                              withAppBundleURL:nil
                                      target:nil
                        clippingAddedSelector:nil];

    XCTAssertFalse(result, @"Adding empty clipping should fail");
    XCTAssertEqual([self.operator jcListCount], 0, @"Store should remain empty");
}

#pragma mark - Stack Position Tests

- (void)testStackPositionWithEmptyStore {
    XCTAssertEqual([self.operator stackPosition], 0, @"Stack position in empty store should be 0");
    XCTAssertFalse([self.operator stackPositionIsInBounds], @"Position should be out of bounds in empty store");
}

- (void)testStackPositionWithClippings {
    [self addTestClippings:5];
    XCTAssertEqual([self.operator stackPosition], 0, @"Stack position should be 0 after adding");
    XCTAssertTrue([self.operator stackPositionIsInBounds], @"Position should be in bounds");
}

- (void)testSetStackPositionToOneMoreRecent {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:3];

    bool result = [self.operator setStackPositionToOneMoreRecent];

    XCTAssertTrue(result, @"Moving more recent should succeed");
    XCTAssertEqual([self.operator stackPosition], 2, @"Stack position should decrease by 1");
}

- (void)testSetStackPositionToOneMoreRecentAtBeginning {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:0];

    bool result = [self.operator setStackPositionToOneMoreRecent];

    XCTAssertFalse(result, @"Cannot move more recent from position 0");
    XCTAssertEqual([self.operator stackPosition], 0, @"Stack position should remain 0");
}

- (void)testSetStackPositionToOneLessRecent {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:2];

    bool result = [self.operator setStackPositionToOneLessRecent];

    XCTAssertTrue(result, @"Moving less recent should succeed");
    XCTAssertEqual([self.operator stackPosition], 3, @"Stack position should increase by 1");
}

- (void)testSetStackPositionToOneLessRecentAtEnd {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:4];

    bool result = [self.operator setStackPositionToOneLessRecent];

    XCTAssertFalse(result, @"Cannot move less recent from last position");
    XCTAssertEqual([self.operator stackPosition], 4, @"Stack position should remain at last");
}

- (void)testSetStackPositionToFirstItem {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:3];

    bool result = [self.operator setStackPositionToFirstItem];

    XCTAssertTrue(result, @"Moving to first should succeed");
    XCTAssertEqual([self.operator stackPosition], 0, @"Stack position should be 0");
}

- (void)testSetStackPositionToLastItem {
    [self addTestClippings:5];

    bool result = [self.operator setStackPositionToLastItem];

    XCTAssertTrue(result, @"Moving to last should succeed");
    XCTAssertEqual([self.operator stackPosition], 4, @"Stack position should be last index");
}

- (void)testSetStackPositionToTenMoreRecent {
    [self addTestClippings:20];
    [self.operator setStackPositionTo:15];

    bool result = [self.operator setStackPositionToTenMoreRecent];

    XCTAssertTrue(result, @"Moving 10 more recent should succeed");
    XCTAssertEqual([self.operator stackPosition], 5, @"Stack position should decrease by 10");
}

- (void)testSetStackPositionToTenMoreRecentClampsToZero {
    [self addTestClippings:20];
    [self.operator setStackPositionTo:5];

    [self.operator setStackPositionToTenMoreRecent];

    XCTAssertEqual([self.operator stackPosition], 0, @"Stack position should clamp to 0");
}

- (void)testSetStackPositionToTenLessRecent {
    [self addTestClippings:20];
    [self.operator setStackPositionTo:5];

    bool result = [self.operator setStackPositionToTenLessRecent];

    XCTAssertTrue(result, @"Moving 10 less recent should succeed");
    XCTAssertEqual([self.operator stackPosition], 15, @"Stack position should increase by 10");
}

- (void)testSetStackPositionToTenLessRecentClampsToEnd {
    [self addTestClippings:20];
    [self.operator setStackPositionTo:15];

    [self.operator setStackPositionToTenLessRecent];

    XCTAssertEqual([self.operator stackPosition], 19, @"Stack position should clamp to last index");
}

- (void)testAdjustStackPositionIfOutOfBounds {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:10]; // Beyond bounds

    [self.operator adjustStackPositionIfOutOfBounds];

    XCTAssertTrue([self.operator stackPositionIsInBounds], @"Position should be adjusted to valid range");
}

#pragma mark - Get Paste Tests

- (void)testGetPasteFromStackPosition {
    [self.operator addClipping:@"First" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Second" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Third" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    // Stack position 0 = most recent = "Third"
    NSString *paste = [self.operator getPasteFromStackPosition];

    XCTAssertEqualObjects(paste, @"Third", @"Should get most recent clipping");
}

- (void)testGetPasteFromIndex {
    [self.operator addClipping:@"First" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Second" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Third" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    NSString *paste = [self.operator getPasteFromIndex:2];

    XCTAssertEqualObjects(paste, @"First", @"Index 2 should be oldest clipping");
}

- (void)testGetPasteFromEmptyStore {
    NSString *paste = [self.operator getPasteFromStackPosition];

    XCTAssertEqualObjects(paste, @"", @"Empty store should return empty string");
}

#pragma mark - Clear Tests

- (void)testClearItemAtStackPosition {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:2];

    bool result = [self.operator clearItemAtStackPosition];

    XCTAssertTrue(result, @"Clearing should succeed");
    XCTAssertEqual([self.operator jcListCount], 4, @"Store should have 4 clippings");
}

- (void)testClearList {
    [self addTestClippings:5];

    [self.operator clearList];

    XCTAssertEqual([self.operator jcListCount], 0, @"Store should be empty after clear");
}

#pragma mark - Favorites Store Tests

- (void)testFavoritesStoreInitiallyNotSelected {
    XCTAssertFalse([self.operator favoritesStoreIsSelected], @"Favorites should not be selected initially");
}

- (void)testSwitchToFavoritesStore {
    [self addTestClippings:3];

    [self.operator switchToFavoritesStore];

    XCTAssertTrue([self.operator favoritesStoreIsSelected], @"Favorites should be selected");
    XCTAssertEqual([self.operator jcListCount], 0, @"Favorites store should be empty initially");
}

- (void)testRestoreStashedStore {
    [self addTestClippings:3];
    [self.operator switchToFavoritesStore];

    bool result = [self.operator restoreStashedStore];

    XCTAssertTrue(result, @"Restore should succeed");
    XCTAssertFalse([self.operator favoritesStoreIsSelected], @"Should be back to main store");
    XCTAssertEqual([self.operator jcListCount], 3, @"Main store should have original clippings");
}

- (void)testRestoreWithNoStashedStore {
    bool result = [self.operator restoreStashedStore];
    XCTAssertFalse(result, @"Restore should fail when nothing stashed");
}

- (void)testToggleToFromFavoritesStore {
    [self addTestClippings:3];

    // Toggle to favorites
    [self.operator toggleToFromFavoritesStore];
    XCTAssertTrue([self.operator favoritesStoreIsSelected], @"Should switch to favorites");

    // Toggle back
    [self.operator toggleToFromFavoritesStore];
    XCTAssertFalse([self.operator favoritesStoreIsSelected], @"Should switch back to main");
}

- (void)testSaveFromStackToFavorites {
    [self.operator addClipping:@"Important" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    bool result = [self.operator saveFromStackToFavorites];

    XCTAssertTrue(result, @"Save to favorites should succeed");

    // Verify it's in favorites
    [self.operator switchToFavoritesStore];
    XCTAssertEqual([self.operator jcListCount], 1, @"Favorites should have 1 clipping");
    XCTAssertEqualObjects([self.operator getPasteFromStackPosition], @"Important", @"Favorites should contain saved clipping");
}

#pragma mark - Disable Store Tests

- (void)testDisableStore {
    XCTAssertFalse([self.operator storeDisabled], @"Store should not be disabled initially");

    [self.operator setDisableStoreTo:YES];

    XCTAssertTrue([self.operator storeDisabled], @"Store should be disabled");
}

- (void)testEnableStore {
    [self.operator setDisableStoreTo:YES];
    [self.operator setDisableStoreTo:NO];

    XCTAssertFalse([self.operator storeDisabled], @"Store should be enabled");
}

#pragma mark - Search Tests

- (void)testPreviousDisplayStrings {
    [self.operator addClipping:@"Apple pie" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Banana bread" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Apple cider" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    NSArray *results = [self.operator previousDisplayStrings:10 containing:@"Apple"];

    XCTAssertEqual([results count], 2, @"Should find 2 matches");
}

- (void)testPreviousIndexes {
    [self.operator addClipping:@"Apple pie" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Banana bread" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Apple cider" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    NSArray *indexes = [self.operator previousIndexes:10 containing:@"Apple"];

    XCTAssertEqual([indexes count], 2, @"Should find 2 matching indexes");
}

#pragma mark - Index of Clipping Tests

- (void)testIndexOfClipping {
    [self.operator addClipping:@"First" ofType:@"text" fromApp:@"App1" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Second" ofType:@"text" fromApp:@"App2" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Third" ofType:@"text" fromApp:@"App3" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    int index = [self.operator indexOfClipping:@"Second" ofType:@"text" fromApp:@"App2" withAppBundleURL:nil];

    XCTAssertEqual(index, 1, @"Second should be at index 1");
}

- (void)testIndexOfNonexistentClipping {
    [self.operator addClipping:@"Content" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    int index = [self.operator indexOfClipping:@"Nonexistent" ofType:@"text" fromApp:@"" withAppBundleURL:nil];

    XCTAssertEqual(index, -1, @"Nonexistent clipping should return -1");
}

#pragma mark - Clipping At Stack Position Tests

- (void)testClippingAtStackPosition {
    [self.operator addClipping:@"Test" ofType:@"text" fromApp:@"App" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    FlycutClipping *clipping = [self.operator clippingAtStackPosition];

    XCTAssertNotNil(clipping, @"Should return clipping");
    XCTAssertEqualObjects([clipping contents], @"Test", @"Content should match");
}

- (void)testClippingAtStackPositionEmpty {
    FlycutClipping *clipping = [self.operator clippingAtStackPosition];
    XCTAssertNil(clipping, @"Empty store should return nil");
}

#pragma mark - Valid Clipping Number Tests

- (void)testIsValidClippingNumber {
    [self addTestClippings:5];

    XCTAssertTrue([self.operator isValidClippingNumber:@0], @"0 should be valid");
    XCTAssertTrue([self.operator isValidClippingNumber:@4], @"4 should be valid");
    XCTAssertFalse([self.operator isValidClippingNumber:@5], @"5 should be invalid");
    XCTAssertFalse([self.operator isValidClippingNumber:@-1], @"-1 should be invalid");
}

#pragma mark - Clipping String With Count Tests

- (void)testClippingStringWithCount {
    [self.operator addClipping:@"First" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Second" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    NSString *content = [self.operator clippingStringWithCount:1];

    XCTAssertEqualObjects(content, @"First", @"Count 1 should be first added (oldest)");
}

- (void)testClippingStringWithInvalidCount {
    [self addTestClippings:3];

    NSString *content = [self.operator clippingStringWithCount:10];

    XCTAssertEqualObjects(content, @"", @"Invalid count should return empty string");
}

#pragma mark - Merge List Tests

- (void)testMergeList {
    [self.operator addClipping:@"First" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Second" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];
    [self.operator addClipping:@"Third" ofType:@"text" fromApp:@"" withAppBundleURL:nil target:nil clippingAddedSelector:nil];

    int countBefore = [self.operator jcListCount];
    [self.operator mergeList];
    int countAfter = [self.operator jcListCount];

    XCTAssertEqual(countAfter, countBefore + 1, @"Merge should add one clipping");

    NSString *merged = [self.operator getPasteFromStackPosition];
    XCTAssertTrue([merged containsString:@"First"], @"Merged should contain First");
    XCTAssertTrue([merged containsString:@"Second"], @"Merged should contain Second");
    XCTAssertTrue([merged containsString:@"Third"], @"Merged should contain Third");
}

#pragma mark - Edge Cases

- (void)testOperationsOnEmptyStore {
    // These should not crash
    XCTAssertFalse([self.operator clearItemAtStackPosition], @"Clear on empty should fail gracefully");
    XCTAssertEqualObjects([self.operator getPasteFromStackPosition], @"", @"Get paste on empty should return empty");
    XCTAssertFalse([self.operator setStackPositionToOneMoreRecent], @"Navigation on empty should fail");
    XCTAssertFalse([self.operator setStackPositionToOneLessRecent], @"Navigation on empty should fail");
}

- (void)testStackPositionAfterClear {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:4];

    [self.operator clearItemAtStackPosition];

    // Position should be adjusted if it was at the end
    XCTAssertTrue([self.operator stackPositionIsInBounds] || [self.operator jcListCount] == 0,
                  @"Position should be valid after clear");
}

- (void)testStackPositionAfterClearList {
    [self addTestClippings:5];
    [self.operator setStackPositionTo:3];

    [self.operator clearList];

    XCTAssertEqual([self.operator stackPosition], 0, @"Position should reset after clear all");
}

@end
