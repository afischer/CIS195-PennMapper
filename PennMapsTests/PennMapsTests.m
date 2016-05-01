//
//  PennMapsTests.m
//  PennMapsTests
//
//  Created by Andrew Fischer on 4/21/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface PennMapsTests : XCTestCase

@end

@implementation PennMapsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testHasCorrectBuildingNames {
    NSString *bldgFilePath = [[NSBundle mainBundle] pathForResource:@"buildingList" ofType:@"txt"];
    NSString *strLines = [[NSString alloc] initWithContentsOfFile:bldgFilePath encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [strLines componentsSeparatedByString:@"\n"];
    
    NSURL *URL = [[NSBundle mainBundle] URLForResource:@"map" withExtension:@"geojson"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    NSMutableArray *buildingList = [json objectForKey:@"features"];
    for (NSArray *building in buildingList) {
        NSString *buildingName = [[building valueForKey:@"properties"] valueForKey:@"Name"];
        XCTAssert([lines containsObject:buildingName]);
    }
}

- (void)testHasAllBuildingsPlaced {
    NSString *bldgFilePath = [[NSBundle mainBundle] pathForResource:@"buildingList" ofType:@"txt"];
    NSString *strLines = [[NSString alloc] initWithContentsOfFile:bldgFilePath encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [strLines componentsSeparatedByString:@"\n"];
    
    NSURL *URL = [[NSBundle mainBundle] URLForResource:@"map" withExtension:@"geojson"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    NSMutableArray *buildingList = [json objectForKey:@"features"];
    NSMutableArray *placedBuildings;
    
    for (NSArray *building in buildingList) {
        [placedBuildings addObject:[NSString stringWithFormat:@"%@", [[building valueForKey:@"properties"] valueForKey:@"Name"]]];
    }
    
    
    for (NSString *line in lines) {
        NSLog(@"%@", line);
        XCTAssert([placedBuildings containsObject:line]);
    }
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
