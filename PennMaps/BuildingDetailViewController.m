//
//  BuildingDetailViewController.m
//  PennMaps
//
//  Created by Andrew Fischer on 4/26/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import "BuildingDetailViewController.h"
#import "MapViewController.h"

@interface BuildingDetailViewController ()
@property (strong, nonatomic) IBOutlet UILabel *name;
@property (strong, nonatomic) IBOutlet UILabel *subtitle;
@property (strong, nonatomic) IBOutlet UIImageView *image;

@end

@implementation BuildingDetailViewController
- (void) viewDidLoad {
    self.navigationItem.title = self.buildingName;
    self.name.text = self.buildingName;
    self.subtitle.text = self.buildingDesc;
    self.image.image = self.buildingImg;
}

@end
