//
//  MapManipulations.m
//  PennMaps
//
//  Created by Andrew Fischer on 4/30/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import "MapManipulations.h"

#define kPennTransitEndpoint @"https://api.pennlabs.org/transit/routes"

@interface MapManipulations () <MKMapViewDelegate>
@end

@implementation MapManipulations

- (NSDictionary *)getBuildingWithName:(NSString *)name {
    NSDictionary *ans;
    NSURL *URL = [[NSBundle mainBundle] URLForResource:@"map" withExtension:@"geojson"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    NSMutableArray *buildingList = [json objectForKey:@"features"];
    for (NSArray *building in buildingList) {
        if ([name isEqualToString:[[building valueForKey:@"properties"] valueForKey:@"Name"]]) {
            ans = [building valueForKey:@"properties"];
        }
    }
    return ans;
}

- (NSDictionary *)getPennBusLines {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:kPennTransitEndpoint]];
    
    NSError *error = [[NSError alloc] init];
    NSHTTPURLResponse *responseCode = nil;
    
    NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];
    
    if([responseCode statusCode] != 200){
        NSLog(@"Error with penn transit get");
        return nil;
    }
    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:oResponseData options:0 error:nil];

    return JSON;
}


@end

