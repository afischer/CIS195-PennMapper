//
//  DirectionViewController.m
//  PennMaps
//
//  Created by Andrew Fischer on 5/1/16.
//  Copyright © 2016 University of Pennsylvania. All rights reserved.
//

#import "DirectionViewController.h"
#import "MapViewController.h"

@interface DirectionViewController () <UIToolbarDelegate, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UITextField *fromField;
@property (nonatomic, strong) UITextField *toField;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property BOOL isFiltered;
@property NSMutableArray *locations;
@property NSMutableArray *filteredSearch;
@property float startLat;
@property float startLon;
@property float endLat;
@property float endLon;
@end

@implementation DirectionViewController
- (void) viewDidLoad {
    [super viewDidLoad];

    self.tableView.delegate = self;
    [self populateSearchBar];
    
    self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, (3*44)+22)];
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    self.fromField = [[UITextField alloc] initWithFrame:CGRectMake(20, 60, self.view.frame.size.width - 40, 30)];
    self.fromField.placeholder = @"Start";
    self.fromField.borderStyle = UITextBorderStyleRoundedRect;
    self.fromField.tag = 0;
    self.fromField.delegate = self;

    self.toField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, self.view.frame.size.width - 40, 30)];
    self.toField.placeholder = @"End";
    self.toField.borderStyle = UITextBorderStyleRoundedRect;
    self.fromField.tag = 1;
    self.toField.delegate = self;
    
    // Sorry for janky possitioning :(
    // TODO: Fix positioning
    UIButton *routeBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 100, 20, 100, 40)];
    [routeBtn setTitleColor:self.view.tintColor forState:UIControlStateNormal];
    [routeBtn setTitle:@"Route" forState:UIControlStateNormal];
    
    UIButton *cancelBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 20, 100, 40)];
    [cancelBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [cancelBtn setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(closeView) forControlEvents:UIControlEventTouchUpInside];
    [routeBtn addTarget:self action:@selector(userDidRequestRoute) forControlEvents:UIControlEventTouchUpInside];

    UILabel *dirLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2-40, 20, 100, 40)];
    dirLabel.text = @"Directions";
    
    [self.toolbar addSubview:self.fromField];
    [self.toolbar addSubview:self.toField];
    [self.toolbar addSubview:routeBtn];
    [self.toolbar addSubview:cancelBtn];
    [self.toolbar addSubview:dirLabel];
    
    [self.view addSubview:self.toolbar];

}

#pragma mark UIToolBarDelegate
- (UIBarPosition)positionForBar:(id<UIBarPositioning>)bar {
    return UIBarPositionTop;
}

- (void)closeView {
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITableViewDelegate
- (void)populateSearchBar {
    self.tableView.delegate = self;
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

-(void)userDidRequestRoute {
    
    [self.parentView userDidRequestRouteWithStartLat:self.startLat StartLon:self.startLon EndLon:self.endLon endLat:self.endLat];
    [self closeView];
    
}

- (BOOL)textField: (UITextField *) textField shouldChangeCharactersInRange: (NSRange) range replacementString: (NSString *) string {
    self.isFiltered = YES;
    self.filteredSearch = [[NSMutableArray alloc] init];
    for (NSDictionary* loc in self.locations){
        NSRange nameRange = [[loc valueForKey:@"Name"] rangeOfString:textField.text options:NSCaseInsensitiveSearch];
        if(nameRange.location != NSNotFound)
        {
            [self.filteredSearch addObject:loc];
        }
    }
    [self.tableView reloadData];
    return true;
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
    for (NSDictionary *loc in self.locations) {
        if ([loc valueForKey:@"Name"] == [tableView cellForRowAtIndexPath:indexPath].textLabel.text) {
            if([self.fromField isFirstResponder]) {
                self.fromField.text = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
                self.startLat = [[loc valueForKey:@"lat"] floatValue];
                self.startLon = [[loc valueForKey:@"lon"] floatValue];
            } else if ([self.toField isFirstResponder]) {
                self.toField.text = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
                self.endLat = [[loc valueForKey:@"lat"] floatValue];
                self.endLon = [[loc valueForKey:@"lon"] floatValue];
            }
        }
    }
}

@end
