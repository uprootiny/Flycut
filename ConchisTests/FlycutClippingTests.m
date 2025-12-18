//
//  FlycutClippingTests.m
//  ConchisTests
//
//  Unit tests for FlycutClipping - the core data model for clipboard entries.
//  Tests cover initialization, display string truncation, equality, and edge cases.
//

#import <XCTest/XCTest.h>
#import "FlycutClipping.h"

@interface FlycutClippingTests : XCTestCase
@end

@implementation FlycutClippingTests

#pragma mark - Initialization Tests

- (void)testDefaultInitialization {
    FlycutClipping *clipping = [[FlycutClipping alloc] init];

    XCTAssertNotNil(clipping, @"Clipping should not be nil after init");
    XCTAssertEqualObjects([clipping contents], @"", @"Default contents should be empty string");
    XCTAssertEqualObjects([clipping type], @"", @"Default type should be empty string");
    XCTAssertEqual([clipping displayLength], 40, @"Default display length should be 40");
    XCTAssertEqual([clipping hasName], NO, @"Default hasName should be NO");
    XCTAssertEqual([clipping timestamp], 0, @"Default timestamp should be 0");

    [clipping release];
}

- (void)testFullInitialization {
    NSString *contents = @"Test clipboard content";
    NSString *type = @"public.utf8-plain-text";
    NSString *appName = @"Safari";
    NSString *bundleURL = @"file:///Applications/Safari.app";
    NSInteger timestamp = 1702900000;

    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:contents
                                                               withType:type
                                                      withDisplayLength:50
                                                   withAppLocalizedName:appName
                                                       withAppBundleURL:bundleURL
                                                          withTimestamp:timestamp];

    XCTAssertEqualObjects([clipping contents], contents, @"Contents should match");
    XCTAssertEqualObjects([clipping type], type, @"Type should match");
    XCTAssertEqual([clipping displayLength], 50, @"Display length should be 50");
    XCTAssertEqualObjects([clipping appLocalizedName], appName, @"App name should match");
    XCTAssertEqualObjects([clipping appBundleURL], bundleURL, @"Bundle URL should match");
    XCTAssertEqual([clipping timestamp], timestamp, @"Timestamp should match");

    [clipping release];
}

#pragma mark - Display String Tests

- (void)testDisplayStringShortContent {
    // Content shorter than display length should not be truncated
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Short"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqualObjects([clipping displayString], @"Short", @"Short content should not be truncated");

    [clipping release];
}

- (void)testDisplayStringLongContent {
    // Content longer than display length should be truncated with ellipsis
    NSString *longContent = @"This is a very long string that should definitely be truncated because it exceeds the display length";
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:longContent
                                                               withType:@"text"
                                                      withDisplayLength:20
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    NSString *expected = @"This is a very long …";
    XCTAssertEqualObjects([clipping displayString], expected, @"Long content should be truncated with ellipsis");
    XCTAssertEqual([[clipping displayString] length], 21, @"Display string should be displayLength + 1 (for ellipsis)");

    [clipping release];
}

- (void)testDisplayStringExactLength {
    // Content exactly at display length should not be truncated
    NSString *exactContent = @"ExactlyTwentyChars!!";  // 20 characters
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:exactContent
                                                               withType:@"text"
                                                      withDisplayLength:20
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqualObjects([clipping displayString], exactContent, @"Content at exact length should not be truncated");

    [clipping release];
}

- (void)testDisplayStringMultiline {
    // Multiline content should only show first line
    NSString *multilineContent = @"First line\nSecond line\nThird line";
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:multilineContent
                                                               withType:@"text"
                                                      withDisplayLength:100
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqualObjects([clipping displayString], @"First line", @"Only first line should be displayed");

    [clipping release];
}

- (void)testDisplayStringWithLeadingWhitespace {
    // Leading whitespace should be trimmed
    NSString *paddedContent = @"   \n  Actual content starts here";
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:paddedContent
                                                               withType:@"text"
                                                      withDisplayLength:100
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqualObjects([clipping displayString], @"Actual content starts here",
                          @"Leading whitespace should be trimmed");

    [clipping release];
}

- (void)testDisplayStringEmptyContent {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@""
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqualObjects([clipping displayString], @"", @"Empty content should yield empty display string");

    [clipping release];
}

- (void)testDisplayStringWhitespaceOnly {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"   \n\t  \n   "
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqualObjects([clipping displayString], @"", @"Whitespace-only content should yield empty display string");

    [clipping release];
}

#pragma mark - Setter Tests

- (void)testSetContentsUpdatesDisplayString {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Original"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqualObjects([clipping displayString], @"Original");

    [clipping setContents:@"Updated"];

    XCTAssertEqualObjects([clipping contents], @"Updated", @"Contents should be updated");
    XCTAssertEqualObjects([clipping displayString], @"Updated", @"Display string should be updated");

    [clipping release];
}

- (void)testSetDisplayLengthUpdatesDisplayString {
    NSString *content = @"This is some content that is reasonably long";
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:content
                                                               withType:@"text"
                                                      withDisplayLength:100
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    // Initially not truncated
    XCTAssertEqualObjects([clipping displayString], content);

    // Change display length to truncate
    [clipping setDisplayLength:10];

    XCTAssertEqual([clipping displayLength], 10);
    XCTAssertEqualObjects([clipping displayString], @"This is so…", @"Display string should be truncated");

    [clipping release];
}

- (void)testSetDisplayLengthZeroIgnored {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Content"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    [clipping setDisplayLength:0];

    XCTAssertEqual([clipping displayLength], 40, @"Zero display length should be ignored");

    [clipping release];
}

- (void)testSetDisplayLengthNegativeIgnored {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Content"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    [clipping setDisplayLength:-5];

    XCTAssertEqual([clipping displayLength], 40, @"Negative display length should be ignored");

    [clipping release];
}

#pragma mark - Equality Tests

- (void)testEqualityWithSameContents {
    FlycutClipping *clipping1 = [[FlycutClipping alloc] initWithContents:@"Same content"
                                                                withType:@"type1"
                                                       withDisplayLength:40
                                                    withAppLocalizedName:@"App1"
                                                        withAppBundleURL:nil
                                                           withTimestamp:100];

    FlycutClipping *clipping2 = [[FlycutClipping alloc] initWithContents:@"Same content"
                                                                withType:@"type2"
                                                       withDisplayLength:50
                                                    withAppLocalizedName:@"App2"
                                                        withAppBundleURL:nil
                                                           withTimestamp:200];

    // Equality is based on contents only (not type, app, timestamp, etc.)
    XCTAssertTrue([clipping1 isEqual:clipping2], @"Clippings with same contents should be equal");
    XCTAssertTrue([clipping2 isEqual:clipping1], @"Equality should be symmetric");

    [clipping1 release];
    [clipping2 release];
}

- (void)testEqualityWithDifferentContents {
    FlycutClipping *clipping1 = [[FlycutClipping alloc] initWithContents:@"Content A"
                                                                withType:@"text"
                                                       withDisplayLength:40
                                                    withAppLocalizedName:@""
                                                        withAppBundleURL:nil
                                                           withTimestamp:0];

    FlycutClipping *clipping2 = [[FlycutClipping alloc] initWithContents:@"Content B"
                                                                withType:@"text"
                                                       withDisplayLength:40
                                                    withAppLocalizedName:@""
                                                        withAppBundleURL:nil
                                                           withTimestamp:0];

    XCTAssertFalse([clipping1 isEqual:clipping2], @"Clippings with different contents should not be equal");

    [clipping1 release];
    [clipping2 release];
}

- (void)testEqualityWithSelf {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Content"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertTrue([clipping isEqual:clipping], @"Clipping should be equal to itself");

    [clipping release];
}

- (void)testEqualityWithNil {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Content"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertFalse([clipping isEqual:nil], @"Clipping should not be equal to nil");

    [clipping release];
}

- (void)testEqualityWithDifferentClass {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Content"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    NSString *notAClipping = @"Content";

    XCTAssertFalse([clipping isEqual:notAClipping], @"Clipping should not be equal to a string");

    [clipping release];
}

#pragma mark - Description Tests

- (void)testDescription {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Test content"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    NSString *description = [clipping description];

    XCTAssertTrue([description containsString:@"Test content"],
                  @"Description should contain the display string");

    [clipping release];
}

#pragma mark - Edge Cases

- (void)testUnicodeContent {
    NSString *unicodeContent = @"Hello 世界 🌍 مرحبا";
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:unicodeContent
                                                               withType:@"text"
                                                      withDisplayLength:100
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqualObjects([clipping contents], unicodeContent, @"Unicode content should be preserved");
    XCTAssertEqualObjects([clipping displayString], unicodeContent, @"Unicode display string should be preserved");

    [clipping release];
}

- (void)testUnicodeTruncation {
    NSString *unicodeContent = @"Hello 世界 🌍 مرحبا wonderful world";
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:unicodeContent
                                                               withType:@"text"
                                                      withDisplayLength:10
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    // Should truncate at character level, not byte level
    XCTAssertTrue([[clipping displayString] hasSuffix:@"…"], @"Truncated unicode should end with ellipsis");
    XCTAssertTrue([[clipping displayString] length] <= 11, @"Truncated unicode should respect display length");

    [clipping release];
}

- (void)testVeryLongContent {
    // Test with content that's much longer than typical
    NSMutableString *veryLong = [NSMutableString string];
    for (int i = 0; i < 10000; i++) {
        [veryLong appendString:@"x"];
    }

    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:veryLong
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqual([[clipping contents] length], 10000, @"Full content should be preserved");
    XCTAssertEqual([[clipping displayString] length], 41, @"Display string should be truncated (40 + ellipsis)");

    [clipping release];
}

- (void)testTimestampPreservation {
    NSInteger timestamp = (NSInteger)[[NSDate date] timeIntervalSince1970];
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Content"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:timestamp];

    XCTAssertEqual([clipping timestamp], timestamp, @"Timestamp should be preserved exactly");

    [clipping release];
}

- (void)testClippingMethodReturnsSelf {
    FlycutClipping *clipping = [[FlycutClipping alloc] initWithContents:@"Content"
                                                               withType:@"text"
                                                      withDisplayLength:40
                                                   withAppLocalizedName:@""
                                                       withAppBundleURL:nil
                                                          withTimestamp:0];

    XCTAssertEqual([clipping clipping], clipping, @"clipping method should return self");

    [clipping release];
}

@end
