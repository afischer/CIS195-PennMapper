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
#import "BuildingDetailViewController.h"
#import "MapManipulations.h"
#import "BusAnnotation.h"
#import "DirectionViewController.h"

static const CGFloat CalloutYOffset = 5.0f;

@interface MapViewController () <CLLocationManagerDelegate, MKMapViewDelegate, UISearchBarDelegate, UITableViewDelegate>
@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic, retain) MKPolyline *routeLine; //your line
@property (nonatomic, retain) MKPolylineView *routeLineView; //overlay view

@property (strong, nonatomic) MapManipulations *manipulations;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) SMCalloutView *calloutView;
@property (nonatomic) CLLocationCoordinate2D calloutAnchor;
@property (strong, nonatomic) UIView *emptyCalloutView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *trackingBtn;
@property (nonatomic) CGPoint point;
@property BOOL isUpdatingLocation;
@property NSMutableArray *locations;
@property NSMutableArray *filteredSearch;
@property BOOL isFiltered;
@property MKRoute *routeDetails;
@property (strong, nonatomic) NSString *allSteps;
@property MKPolyline *lastOverlay;
@end

@implementation MapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self populateSearchBar];
    
    self.isUpdatingLocation = NO;
    self.manipulations = [[MapManipulations alloc]init];
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];
    [self  setUpMap];

    
    // Testing UICallout View
    self.calloutView = [[SMCalloutView alloc] init];
    UIButton *disclosure = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    [disclosure addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(disclosureTapped)]];
    self.calloutView.rightAccessoryView = disclosure;
    self.emptyCalloutView = [[UIView alloc] initWithFrame:CGRectZero];
    
    self.searchBar = [[UISearchBar alloc] init];
    [self.searchBar sizeToFit];
    self.searchBar.delegate = self;
    self.navigationItem.titleView = self.searchBar;
    self.searchBar.barStyle = UISearchBarStyleMinimal;
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
    
    [self showBusLines];
}

- (void)showBusLines {
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(backgroundQueue, ^{
        NSDictionary *stops = [[self.manipulations getPennBusLines] valueForKey:@"result_data"];
            for (NSDictionary *stop in stops) {
                float stopLat = [[stop valueForKey:@"Latitude"] floatValue];
                float stopLon = [[stop valueForKey:@"Longitude"] floatValue];
                BusAnnotation *annotation = [[BusAnnotation alloc] init];
                annotation.routes = [[NSMutableArray alloc] init];

                
                dispatch_async(dispatch_get_main_queue(), ^{
                    annotation.coordinate = CLLocationCoordinate2DMake(stopLat, stopLon);
                    annotation.title = [stop valueForKey:@"BusStopName"];
                    annotation.color = @"Blue";
                    NSDictionary *routes = [stop valueForKey:@"routes"];
                    for (NSString *route in [routes allKeys]) {
                        [annotation.routes addObject:route];
                        [self.mapView addAnnotation:annotation];

                    }
            });
        }

    });
}

//TODO: Factor this stuff out b/c repeated in DirectionView Controller
#pragma mark - UITableViewDelegate
- (void)populateSearchBar {
    self.tableView.delegate = self;
    self.tableView.hidden = YES;
    self.locations = [[NSMutableArray alloc] init];
    NSURL *URL = [[NSBundle mainBundle] URLForResource:@"map" withExtension:@"geojson"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSDictionary *formattedJSON = [JSON valueForKey:@"features"];
    for (NSDictionary *location in formattedJSON) {
        [self.locations addObject: [location valueForKey:@"properties"]];
    }
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rowCount;
    if(self.isFiltered)
        rowCount = self.filteredSearch.count;
    else
        rowCount = self.locations.count;
    
    return rowCount;
}




- (UITableViewCell *)tableView:(UITableView *)tableVIew cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *searchCell = [self.tableView dequeueReusableCellWithIdentifier:@"searchCell" forIndexPath:indexPath];
    if (!searchCell) {
        searchCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"searchCell"];
    }
    NSDictionary *location = [[NSDictionary alloc] init];
    if (self.isFiltered) {
        location = self.filteredSearch[indexPath.row];
    } else {
        location = self.locations[indexPath.row];
    }
    
    NSString *locName = [location valueForKey:@"Name"];
    UILabel *titleLabel = (UILabel *)[searchCell viewWithTag:0];
    titleLabel.text = locName;

    return searchCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"TAOP BRING TO PLACE PLS");
    for (NSDictionary *loc in self.locations) {
        if ([loc valueForKey:@"Name"] == [tableView cellForRowAtIndexPath:indexPath].textLabel.text) {
            // found building with name
            float lat = [[loc valueForKey:@"lat"] floatValue];
            float lon = [[loc valueForKey:@"lon"] floatValue];
            
            MKCoordinateRegion region;
            
            region.center.latitude  = lat;
            region.center.longitude = lon;
            
            double radius = .01;
            MKCoordinateSpan span;
            span.latitudeDelta = radius / 50;
            region.span = span;

            [self.mapView setRegion:region animated:YES];
        }
    }
}




#pragma mark - MKMapViewDelegate
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    
    if ([annotation isKindOfClass:[BusAnnotation class]]) {
        MKAnnotationView *view = [[MKAnnotationView alloc] initWithAnnotation:annotation
                                                              reuseIdentifier:@"identifier"];
        BusAnnotation *busAnnotation = view.annotation;
        
//        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(50, 0, 50, 11)] ;
//        lbl.backgroundColor = [UIColor blackColor];
//        [view addSubview:lbl];
//        view.frame = lbl.frame;
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(17,3,22,11)];
//        label.backgroundColor = [
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor whiteColor];
        [label setFont:[UIFont systemFontOfSize:6 weight:100]];
        label.tag = 42;
        label.layer.backgroundColor = [UIColor colorWithRed:0.431 green:0.741 blue:0.98 alpha:1].CGColor; /*#6ebdfa*/
        label.layer.borderWidth = 1.0;
        label.layer.borderColor = [UIColor colorWithRed:0.431 green:0.741 blue:0.98 alpha:1].CGColor;
        label.layer.cornerRadius = 4;
        [view addSubview:label];
//        [label release];
        
        view.enabled = YES;
        view.canShowCallout = YES;
        busAnnotation.subtitle = [busAnnotation.routes componentsJoinedByString:@", "];

        if ([busAnnotation.routes containsObject:@"PennBUS East"] && [busAnnotation.routes containsObject:@"PennBUS West"]) {
            label.frame = CGRectMake(17, 3, 42, 11);
            view.image = [UIImage imageNamed:@"RedBlueBus"];
            UILabel *label = (UILabel *)[view viewWithTag:42];
            label.text = @"EAST WEST";
        } else if ([busAnnotation.routes containsObject:@"PennBUS East"]){
            view.image = [UIImage imageNamed:@"RedBus"];
            UILabel *label = (UILabel *)[view viewWithTag:42];
            label.text = @"EAST";
        } else if ([busAnnotation.routes containsObject:@"PennBUS West"]) {
            view.image = [UIImage imageNamed:@"BlueBus"];
            UILabel *label = (UILabel *)[view viewWithTag:42];
            label.text = @"WEST";
        } else {
//            view.image = [UIImage imageNamed:@"GrayBus"];
            view.enabled = NO;
            label.frame = CGRectMake(0, 0, 0, 0);
        }
        
        return view;
    }
    
    return nil;
}


- (void)trackUser {
    self.locationManager = [[CLLocationManager alloc] init];
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

#pragma mark - UISearchBarDelegate
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [self.tableView setHidden:NO];
    
}

-(void)searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)text {
    if (text.length == 0) {
        self.isFiltered = NO;
    } else {
        self.isFiltered = YES;
        self.filteredSearch = [[NSMutableArray alloc] init];
        
        for (NSDictionary* loc in self.locations){
            NSRange nameRange = [[loc valueForKey:@"Name"] rangeOfString:text options:NSCaseInsensitiveSearch];
//            NSRange descriptionRange = [loc.description rangeOfString:text options:NSCaseInsensitiveSearch];
            if(nameRange.location != NSNotFound)
            {
                [self.filteredSearch addObject:loc];
            }
        }
    }
    
    [self.tableView reloadData];
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self.searchBar endEditing:YES]; //end editing
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
                    
                    // Damn you, floating point math.
                    if ((fabs(polygon.coordinate.latitude - lat) < 0.00001) && (fabs(polygon.coordinate.longitude - lon) < 0.00001)) {
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
    [self.searchBar endEditing:YES];
    if (!self.tableView.hidden) {
        self.tableView.hidden = YES;
    }
    if (!self.calloutView.hidden){
        if (!_timer) {
            _timer = [NSTimer scheduledTimerWithTimeInterval:0.06f
                                                      target:self
                                                    selector:@selector(_timerFired:)
                                                    userInfo:nil
                                                     repeats:YES];
        }
    }
}


-(void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    // Start timer for callout movement
    if ([_timer isValid]) {
        [_timer invalidate];
    }
    _timer = nil;
    
    // Show or hide annotations
    NSArray *annotations = [_mapView annotations];
    BusAnnotation *annotation = nil;
    for (int i=0; i<[annotations count]; i++)
    {
        annotation = (BusAnnotation*)[annotations objectAtIndex:i];
        if (_mapView.region.span.latitudeDelta > .050)
        {
            [[_mapView viewForAnnotation:annotation] setHidden:YES];
        }
        else {
            [[_mapView viewForAnnotation:annotation] setHidden:NO];
        }
    }
}

- (void)_timerFired:(NSTimer *)timer {
    if (!self.calloutView.hidden){
        
        // TODO: Figure out how to get markers to move correctly.
        
        dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 2);
        dispatch_async(backgroundQueue, ^{
            CLLocationCoordinate2D anchor = self.calloutAnchor;
            CGPoint arrowPt = self.calloutView.backgroundView.arrowPoint;
            
            self.point = [self.mapView convertCoordinate:anchor toPointToView:NULL];
            
            CGPoint temp = self.point;
            temp.x -= arrowPt.x;
            temp.y -= arrowPt.y + CalloutYOffset;
            self.point = temp;

            dispatch_async(dispatch_get_main_queue(), ^{
                self.calloutView.frame = (CGRect) {.origin = self.point, .size = self.calloutView.frame.size };

            });
        });
        
    } else {
        self.calloutView.hidden = YES;
    }
}
- (IBAction)presentDirectionsModal:(id)sender {
    DirectionViewController *dirView = [self.storyboard instantiateViewControllerWithIdentifier:@"DirectionViewController"];
    dirView.parentView = self;
    [self.navigationController presentViewController:dirView animated:YES completion:^{}];
}

- (void)disclosureTapped {
    NSLog(@"TAP!");
    // Initialize View Controller
    BuildingDetailViewController *detailView = [self.storyboard instantiateViewControllerWithIdentifier:@"BuildingDetailView"];
    
    NSString *buildingName = self.calloutView.title;
    detailView.buildingName = buildingName;
    NSDictionary *details = [self.manipulations getBuildingWithName:buildingName];
    detailView.buildingDesc = [details valueForKeyPath:@"description"];
    detailView.buildingImg = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://www.geoguessr.com/images/dd05effb76800125147b1b4b86956f0c.jpg"]]];
    [self.navigationController pushViewController:detailView animated:YES];

}

//
//- (void)drawBusLine {
//    
//    // remove polyline if one exists
//    [self.mapView removeOverlay:self.polyline];
//    
//    // create an array of coordinates from allPins
//    int i = 0;
//    for (MKAnnotationView *currentPin in self.mapView.annotations) {
//        coordinates[i] = currentPin.annotation.;
//        i++;
//    }
//    
//    // create a polyline with all cooridnates
//    MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coordinates count:self.allPins.count];
//    [self.mapView addOverlay:polyline];
//    self.polyline = polyline;
//    
//    // create an MKPolylineView and add it to the map view
//    self.lineView = [[MKPolylineView alloc]initWithPolyline:self.polyline];
//    self.lineView.strokeColor = [UIColor redColor];
//    self.lineView.lineWidth = 5;
//    
//}

- (void)userDidRequestRouteWithStartLat:(float)startLat StartLon:(float)startLon EndLon:(float)endLon endLat:(float)endLat {
    [self.mapView removeOverlay:self.lastOverlay];
    MKDirectionsRequest *directionsRequest = [[MKDirectionsRequest alloc] init];
    MKPlacemark *start = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(startLat, startLon) addressDictionary:NULL];
    MKPlacemark *end   = [[MKPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(endLat, endLon) addressDictionary:NULL];
    [directionsRequest setSource:[[MKMapItem alloc] initWithPlacemark:start]];
    [directionsRequest setDestination:[[MKMapItem alloc] initWithPlacemark:end]];
    directionsRequest.transportType = MKDirectionsTransportTypeWalking;
    MKDirections *directions = [[MKDirections alloc] initWithRequest:directionsRequest];
    [directions calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error %@", error.description);
        } else {
            self.routeDetails = response.routes.lastObject;
            self.lastOverlay = self.routeDetails.polyline;
            [self.mapView addOverlay:self.lastOverlay];
            self.allSteps = @"";
            for (int i = 0; i < self.routeDetails.steps.count; i++) {
                MKRouteStep *step = [self.routeDetails.steps objectAtIndex:i];
                NSString *newStep = step.instructions;
                self.allSteps = [self.allSteps stringByAppendingString:newStep];
                self.allSteps = [self.allSteps stringByAppendingString:@"\n\n"];
            }
        }
    }];
}


@end
