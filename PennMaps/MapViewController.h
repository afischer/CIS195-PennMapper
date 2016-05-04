//
//  MapViewController.h
//  PennMaps
//
//  Created by Andrew Fischer on 4/21/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MapViewController : UIViewController
{NSTimer *_timer;}
- (void)_timerFired:(NSTimer *)timer;
- (void)userDidRequestRouteWithStartLat:(float)startLat StartLon:(float)startLon EndLon:(float)endLon endLat:(float)endLat;
@end

