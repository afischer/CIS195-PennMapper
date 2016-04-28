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
#import "GeoJSONSerialization.h"
#import <SMCalloutView/SMCalloutView.h>

static const CGFloat CalloutYOffset = 5.0f;

@interface MapViewController () <CLLocationManagerDelegate, MKMapViewDelegate, UISearchBarDelegate, UIToolbarDelegate>
@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) SMCalloutView *calloutView;
@property (nonatomic) CLLocationCoordinate2D calloutAnchor;
@property (strong, nonatomic) UIView *emptyCalloutView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *trackingBtn;
@property (strong, nonatomic) IBOutlet UIToolbar *toolbarTop;
@property BOOL isUpdatingLocation;
@end

@implementation MapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self  setUpMap];
    self.isUpdatingLocation = NO;

//    [self setStatusBarBackgroundColor];
    [self.toolbarTop setDelegate:self];
    // Testing UICallout View
    self.calloutView = [[SMCalloutView alloc] init];
    UIButton *disclosure = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    [disclosure addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(disclosureTapped)]];
    self.calloutView.rightAccessoryView = disclosure;
    self.emptyCalloutView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (UIBarPosition)positionForBar:(id<UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (void)setStatusBarBackgroundColor {
    // Jesus there has to be a better way to do this
    UIView *statusBar = [[[UIApplication sharedApplication] valueForKey:@"statusBarWindow"] valueForKey:@"statusBar"];
    
    if ([statusBar respondsToSelector:@selector(setBackgroundColor:)]) {
        statusBar.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }
    statusBar.alpha = 0.75;
}
// Set up map to inital state for app
- (void)setUpMap {
    self.mapView.delegate = self;

    CLLocationCoordinate2D location = CLLocationCoordinate2DMake(39.9520,  -75.1932);
    MKCoordinateRegion viewRegion   = MKCoordinateRegionMakeWithDistance(location, 3000, 0);
    [self.mapView setShowsCompass:NO];
    [self.mapView setRegion:viewRegion];
    [self.mapView setShowsBuildings:NO];
    [self.mapView setShowsPointsOfInterest:NO];

    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapTap:)];
    tap.cancelsTouchesInView = NO;
    tap.numberOfTapsRequired = 1;
    
    UITapGestureRecognizer *tap2 = [[UITapGestureRecognizer alloc] init];
    tap2.cancelsTouchesInView = NO;
    tap2.numberOfTapsRequired = 2;
    
    [self.mapView addGestureRecognizer:tap2];
    [self.mapView addGestureRecognizer:tap];
    [tap requireGestureRecognizerToFail:tap2]; // Ignore single tap if the user actually double taps
        
    NSURL *URL = [[NSBundle mainBundle] URLForResource:@"map" withExtension:@"geojson"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    NSDictionary *geoJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *shapes = [GeoJSONSerialization shapesFromGeoJSONFeatureCollection:geoJSON error:nil];
    
    for (MKShape *shape in shapes) {
        if ([shape isKindOfClass:[MKPointAnnotation class]]) {
            [self.mapView addAnnotation:shape];
        } else if ([shape conformsToProtocol:@protocol(MKOverlay)]) {
            [self.mapView addOverlay:(id <MKOverlay>)shape];
        }
    }

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
        [self.trackingBtn setImage:[UIImage imageNamed:@"Location"]];
    } else {
        [self trackUser];
        [self.trackingBtn setImage:[UIImage imageNamed:@"Locating"]];

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

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay {
    MKOverlayRenderer *renderer = nil;
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        renderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline *)overlay];
        ((MKPolylineRenderer *)renderer).strokeColor = [UIColor greenColor];
        ((MKPolylineRenderer *)renderer).lineWidth = 3.0f;
    } else if ([overlay isKindOfClass:[MKPolygon class]]) {
        renderer = [[MKPolygonRenderer alloc] initWithPolygon:(MKPolygon *)overlay];
//        ((MKPolygonRenderer *)renderer).strokeColor = [UIColor blueColor];
        ((MKPolygonRenderer *)renderer).fillColor = [UIColor grayColor];
        ((MKPolygonRenderer *)renderer).lineWidth = 0.0f;
        
    }
    
    renderer.alpha = 0.5;
    
    return renderer;
}

-(void)handleMapTap:(UIGestureRecognizer*)tap{
    CGPoint tapPoint = [tap locationInView:self.mapView];
    
    CLLocationCoordinate2D tapCoord = [self.mapView convertPoint:tapPoint toCoordinateFromView:self.mapView];
    MKMapPoint mapPoint = MKMapPointForCoordinate(tapCoord);
    CGPoint mapPointAsCGP = CGPointMake(mapPoint.x, mapPoint.y);
    
    for (id<MKOverlay> overlay in self.mapView.overlays) {
        if([overlay isKindOfClass:[MKPolygon class]]){
            MKPolygon *polygon = (MKPolygon*) overlay;
            
            CGMutablePathRef mpr = CGPathCreateMutable();
            
            MKMapPoint *polygonPoints = polygon.points;
            
            for (int p=0; p < polygon.pointCount; p++){
                MKMapPoint mp = polygonPoints[p];
                if (p == 0)
                    CGPathMoveToPoint(mpr, NULL, mp.x, mp.y);
                else
                    CGPathAddLineToPoint(mpr, NULL, mp.x, mp.y);
            }
            
            if(CGPathContainsPoint(mpr , NULL, mapPointAsCGP, FALSE)){
                // User tapped on building, show SMCalloutView w/ correct data
                NSURL *URL = [[NSBundle mainBundle] URLForResource:@"map" withExtension:@"geojson"];
                NSData *data = [NSData dataWithContentsOfURL:URL];
                NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                NSMutableArray *buildingList = [json objectForKey:@"features"];
                for (NSArray *building in buildingList) {
                    double lat = [[[building valueForKey:@"properties"] valueForKey:@"lat"] doubleValue];
                    double lon = [[[building valueForKey:@"properties"] valueForKey:@"lon"] doubleValue];
                    NSString *buildingName = [[building valueForKey:@"properties"] valueForKey:@"Name"];
//                    NSLog(@"%f", lat);
//                    NSLog(@"%f", polygon.coordinate.latitude);
//                    NSLog(@"%f", lon);
//                    NSLog(@"%f", polygon.coordinate.longitude);
                    
                    // Damn you, floating point math.
                    if ((fabs(polygon.coordinate.latitude - lat) < 0.00001) && (fabs(polygon.coordinate.longitude - lon) < 0.00001)) {
                        NSLog(@"FOUND BUILDING");
                        [self createCalloutWithLatitude:polygon.coordinate.latitude
                                          withLongitude:polygon.coordinate.longitude
                                              withTitle:buildingName];
                    }
                }
                NSLog(@"\"lat\": \"%f\", \n \"lon\": \"%f\"", polygon.coordinate.latitude, polygon.coordinate.longitude);
                
                
                
            } else {
                self.calloutView.hidden = YES;
            }
            
            CGPathRelease(mpr);
        }
    }
}

// CALLOUT VIEWS

- (void)calloutAccessoryButtonTapped:(id)sender {
    NSLog(@"Tappy Tap");
}


- (UIView *)createCalloutWithLatitude:(float)latitude withLongitude:(float)longitude withTitle:(NSString *)title {
    CLLocationCoordinate2D anchor = CLLocationCoordinate2DMake(latitude, longitude);
    CGPoint point = [self.mapView convertCoordinate:anchor toPointToView:NULL];
    self.calloutAnchor = anchor;
    
    self.calloutView.title = title;
    self.calloutView.calloutOffset = CGPointMake(0, -CalloutYOffset);
    self.calloutView.hidden = NO;
    
    CGRect calloutRect = CGRectZero;
    calloutRect.origin = point;
    calloutRect.size = CGSizeZero;
    
    [self.calloutView presentCalloutFromRect:calloutRect
                                      inView:self.mapView
                           constrainedToView:self.mapView
                                    animated:YES];
    
    return self.emptyCalloutView;

}


- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
    if (!self.calloutView.hidden){
        if (!_timer) {
            _timer = [NSTimer scheduledTimerWithTimeInterval:0.01f
                                                      target:self
                                                    selector:@selector(_timerFired:)
                                                    userInfo:nil
                                                     repeats:YES];
        }
    }
}


// TODO: Multithreading
-(void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if ([_timer isValid]) {
        [_timer invalidate];
    }
    _timer = nil;
}

- (void)_timerFired:(NSTimer *)timer {
    if (!self.calloutView.hidden){
        CLLocationCoordinate2D anchor = self.calloutAnchor;
        CGPoint arrowPt = self.calloutView.backgroundView.arrowPoint;
        
        CGPoint point = [self.mapView convertCoordinate:anchor toPointToView:NULL];
        
        point.x -= arrowPt.x;
        point.y -= arrowPt.y + CalloutYOffset;
        
        self.calloutView.frame = (CGRect) {.origin = point, .size = self.calloutView.frame.size };
        // TODO: Figure out how to get markers to move correctly.
    } else {
        self.calloutView.hidden = YES;
    }
}

- (void)disclosureTapped {
    NSLog(@"TAP!");
//        WHY DOESNT THIS WORK
    [self performSegueWithIdentifier:@"buildingDetailSegue" sender:self];

}

@end
