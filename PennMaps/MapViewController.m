//
//  MapViewController.m
//  PennMaps
//
//  Created by Andrew Fischer on 4/21/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import "MapViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>


@interface MapViewController () <CLLocationManagerDelegate, MKMapViewDelegate, UISearchBarDelegate>
@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) IBOutlet UISearchBar *searchBar;
@property BOOL isUpdatingLocation;
@end

@implementation MapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self  setUpMap];
    self.isUpdatingLocation = NO;
}


// Set up map to inital state for app
- (void)setUpMap {
    CLLocationCoordinate2D location = CLLocationCoordinate2DMake(39.9520,  -75.1932);
    MKCoordinateRegion viewRegion   = MKCoordinateRegionMakeWithDistance(location, 3000, 0);
    [self.mapView setShowsCompass:NO];
    [self.mapView setRegion:viewRegion];
    [self.mapView setShowsBuildings:YES];
}

- (void)trackUser {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];

    [self.mapView setShowsUserLocation:YES];
    [self.mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
    
    self.isUpdatingLocation = YES;
}

// Tracking button
- (IBAction)userDidToggleTracking:(id)sender {
    if (self.isUpdatingLocation) {
        [self.locationManager stopUpdatingLocation];
        [self.mapView setShowsUserLocation:NO];
        self.isUpdatingLocation = NO;
    } else {
        [self trackUser];
    }
}

-(void) searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSLog(@"hi");
    [searchBar resignFirstResponder];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder geocodeAddressString:searchBar.text completionHandler:^(NSArray *placemarks, NSError *error) {
        // Initialize placemark for map center, annotation pin
        CLPlacemark *placemark = [placemarks objectAtIndex:0];
        MKCoordinateRegion region;

        double lat = [(CLCircularRegion *)placemark.region center].latitude;
        double lon = [(CLCircularRegion *)placemark.region center].longitude;
        
        NSLog(@"%@", placemark.addressDictionary);
        
        
        
        region.center.latitude  = lat;
        region.center.longitude = lon;
        
        double radius = [(CLCircularRegion *)placemark.region radius] / 1000;
        
        MKCoordinateSpan span;
        span.latitudeDelta = radius / 112.0;
        region.span = span;


        if (radius > 0) { // If given a result, show it, mark with pin
            MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
            pin.coordinate = CLLocationCoordinate2DMake(lat, lon);
            pin.title = placemark.addressDictionary[@"Name"];
            pin.subtitle = [NSString stringWithFormat:@"%@, %@", placemark.addressDictionary[@"SubLocality"], placemark.addressDictionary[@"SubAdministrativeArea"]];
            
            [self.mapView selectAnnotation:pin animated:YES];
            [self.mapView addAnnotation:pin];
            [self.mapView selectAnnotation:pin animated:YES];
            [self.mapView setRegion:region animated:YES];
        } // TODO: Handle no result
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
