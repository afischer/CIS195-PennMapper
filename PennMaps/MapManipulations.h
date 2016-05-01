//
//  MapManipulations.h
//  PennMaps
//
//  Created by Andrew Fischer on 4/30/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>


@interface MapManipulations : NSObject
- (NSDictionary *)getBuildingWithName:(NSString *)name;
- (NSDictionary *)getPennBusLines;
@end
