//
//  BusAnnotation.h
//  PennMaps
//
//  Created by Andrew Fischer on 5/1/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface BusAnnotation : NSObject <MKAnnotation>

@property(nonatomic, assign) CLLocationCoordinate2D coordinate;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subtitle;
@property(nonatomic, copy) NSString *color;
@property(strong, nonatomic) NSMutableArray *routes;
@end
