#import "TRRootViewController.h"
#import "TRRuntimeTool.h"
#import "TRUtils.h"

@interface TRRootViewController ()
@property(strong, nonatomic) NSArray *processes;
@property(strong, nonatomic) NSArray *filtered;
@property(strong, nonatomic) NSString *searchText;
@property(strong, nonatomic) UISearchController *searchController;
@end

@implementation TRRootViewController

- (void)loadView {
    [super loadView];

    _processes = [AppRuntimeTool listProcess];
    _filtered = _processes;

    self.title = @"TrollR2ool";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    [self setupTableFooterView];

    // 刷新
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self
                       action:@selector(refreshProcesses:)
             forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;

    // 初始化搜索
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.searchBar.placeholder = @"Search...";
    self.tableView.tableHeaderView = _searchController.searchBar;
}

- (void)setupTableFooterView {
    UIView *footerView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 35)];

    UILabel *projectLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(10, 10, footerView.frame.size.width, 20)];
    projectLabel.numberOfLines = 0;
    projectLabel.font = [UIFont boldSystemFontOfSize:10];
    projectLabel.textColor = [UIColor purpleColor];
    projectLabel.text = @"TrollR2ool v1.0 Copyright © 2024\n"
                        @"巴斯.zznQ.";
    [projectLabel sizeToFit];

    [footerView addSubview:projectLabel];
    self.tableView.tableFooterView = footerView;
}

- (void)refreshProcesses:(UIRefreshControl *)refreshControl {
    _processes = [AppRuntimeTool listProcess];

    if (_searchController.isActive) {
        NSPredicate *predicate =
            [NSPredicate predicateWithFormat:@"bundleID CONTAINS[cd] %@", _searchText];
        _filtered = [_processes filteredArrayUsingPredicate:predicate];
    } else {
        _filtered = _processes;
    }

    [self.tableView reloadData];
    [refreshControl endRefreshing];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    if (searchText.length > 0) {
        _searchText = searchText;
        NSPredicate *predicate =
            [NSPredicate predicateWithFormat:@"bundleID CONTAINS[cd] %@", searchText];
        _filtered = [_processes filteredArrayUsingPredicate:predicate];
    } else {
        _filtered = _processes;
    }

    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _searchController.isActive ? _filtered.count : _processes.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"AppCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellIdentifier];

    NSDictionary *app =
        _searchController.isActive ? _filtered[indexPath.row] : _processes[indexPath.row];
    cell.textLabel.text = app[@"name"];
    cell.detailTextLabel.text =
        [NSString stringWithFormat:@"pid:%@ • %@", app[@"pid"], app[@"bundleID"]];
    cell.imageView.image = applicationIconImageForBundleIdentifier(app[@"bundleID"]);

    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *app =
        _searchController.isActive ? _filtered[indexPath.row] : _processes[indexPath.row];
    DetailViewController *detail = [[DetailViewController alloc] init];
    detail.title = app[@"name"];
    detail.pid = [app[@"pid"] intValue];
    detail.navigationItem.prompt = [NSString stringWithFormat:@"pid: %d", detail.pid];

    self.navigationItem.backBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"TrollR2ool"
                                         style:UIBarButtonItemStylePlain
                                        target:nil
                                        action:nil];

    [self.navigationController pushViewController:detail animated:YES];
}

@end

@interface DetailViewController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) NSArray *sections;
@property(nonatomic, strong) NSDictionary *items;
@end

static NSString *const secUtilities = @"Utilities";
static NSString *const secCustomization = @"Customization";
static NSString *const itemLookupPtraceSvc = @"Lookup Ptrace svc";

@implementation DetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    _sections = @[ secUtilities, secCustomization ];
    _items = @{
        secUtilities : @[ itemLookupPtraceSvc ],
        secCustomization : @[],
    };

    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                          style:UITableViewStyleGrouped];
    tableView.delegate = self;
    tableView.dataSource = self;
    [self.view addSubview:tableView];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *items = _items[_sections[section]];
    return items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"cell"];
    }

    NSArray *items = _items[_sections[indexPath.section]];
    cell.textLabel.text = items[indexPath.row];
    cell.textLabel.textColor = [UIColor systemBlueColor];

    return cell;
}

#pragma mark - UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSString *selected = _items[_sections[indexPath.section]][indexPath.row];
    
    // hanlde item click
    if ([selected isEqualToString:(itemLookupPtraceSvc)]) {
        NSString *msg = [AppRuntimeTool lookupPtraceSvc:_pid];
        UIAlertController *alert;
        alert = [UIAlertController alertControllerWithTitle:itemLookupPtraceSvc
                                                    message:msg
                                             preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"ojbk👌"
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil];
        [alert addAction:cancel];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end