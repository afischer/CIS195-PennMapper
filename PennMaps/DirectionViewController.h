//
//  DirectionViewController.h
//  PennMaps
//
//  Created by Andrew Fischer on 5/1/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MapViewController.h"

@interface DirectionViewController : UIViewController
@property (nonatomic, strong) MapViewController *parentView;
@end
