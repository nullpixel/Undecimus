//
//  SettingsTableViewController.m
//  Undecimus
//
//  Created by Pwn20wnd on 9/14/18.
//  Copyright © 2018 Pwn20wnd. All rights reserved.
//

#include <sys/utsname.h>
#include <sys/sysctl.h>
#import "SettingsTableViewController.h"
#include "common.h"
#include "ViewController.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController

double uptime(){
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    if( sysctl(mib, 2, &boottime, &len, NULL, 0) < 0 )
    {
        return -1.0;
    }
    time_t bsec = boottime.tv_sec, csec = time(NULL);
    
    return difftime(csec, bsec);
}

// https://github.com/Matchstic/ReProvision/blob/7b595c699335940f68702bb204c5aa55b8b1896f/Shared/Application%20Database/RPVApplication.m#L102

- (NSDictionary *)_provisioningProfileAtPath:(NSString *)path {
    NSError *err;
    NSString *stringContent = [NSString stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&err];
    stringContent = [stringContent componentsSeparatedByString:@"<plist version=\"1.0\">"][1];
    stringContent = [NSString stringWithFormat:@"%@%@", @"<plist version=\"1.0\">", stringContent];
    stringContent = [stringContent componentsSeparatedByString:@"</plist>"][0];
    stringContent = [NSString stringWithFormat:@"%@%@", stringContent, @"</plist>"];
    
    NSData *stringData = [stringContent dataUsingEncoding:NSASCIIStringEncoding];
    
    NSError *error;
    NSPropertyListFormat format;
    
    id plist = [NSPropertyListSerialization propertyListWithData:stringData options:NSPropertyListImmutable format:&format error:&error];
    
    return plist;
}

#define STATUS_FILE          @"/var/lib/dpkg/status"
#define CYDIA_LIST @"/etc/apt/sources.list.d/cydia.list"

// https://github.com/lechium/nitoTV/blob/53cca06514e79279fa89639ad05b562f7d730079/Classes/packageManagement.m#L1138

+ (NSArray *)dependencyArrayFromString:(NSString *)depends
{
    NSMutableArray *cleanArray = [[NSMutableArray alloc] init];
    NSArray *dependsArray = [depends componentsSeparatedByString:@","];
    for (id depend in dependsArray)
    {
        NSArray *spaceDelimitedArray = [depend componentsSeparatedByString:@" "];
        NSString *isolatedDependency = [[spaceDelimitedArray objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([isolatedDependency length] == 0)
            isolatedDependency = [[spaceDelimitedArray objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        [cleanArray addObject:isolatedDependency];
    }
    
    return cleanArray;
}

// https://github.com/lechium/nitoTV/blob/53cca06514e79279fa89639ad05b562f7d730079/Classes/packageManagement.m#L1163

+ (NSArray *)parsedPackageArray
{
    NSString *packageString = [NSString stringWithContentsOfFile:STATUS_FILE encoding:NSUTF8StringEncoding error:nil];
    NSArray *lineArray = [packageString componentsSeparatedByString:@"\n\n"];
    //NSLog(@"lineArray: %@", lineArray);
    NSMutableArray *mutableList = [[NSMutableArray alloc] init];
    //NSMutableDictionary *mutableDict = [[NSMutableDictionary alloc] init];
    for (id currentItem in lineArray)
    {
        NSArray *packageArray = [currentItem componentsSeparatedByString:@"\n"];
        //    NSLog(@"packageArray: %@", packageArray);
        NSMutableDictionary *currentPackage = [[NSMutableDictionary alloc] init];
        for (id currentLine in packageArray)
        {
            NSArray *itemArray = [currentLine componentsSeparatedByString:@": "];
            if ([itemArray count] >= 2)
            {
                NSString *key = [itemArray objectAtIndex:0];
                NSString *object = [itemArray objectAtIndex:1];
                
                if ([key isEqualToString:@"Depends"]) //process the array
                {
                    NSArray *dependsObject = [SettingsTableViewController dependencyArrayFromString:object];
                    
                    [currentPackage setObject:dependsObject forKey:key];
                    
                } else { //every other key, even if it has an array is treated as a string
                    
                    [currentPackage setObject:object forKey:key];
                }
                
                
            }
        }
        
        //NSLog(@"currentPackage: %@\n\n", currentPackage);
        if ([[currentPackage allKeys] count] > 4)
        {
            //[mutableDict setObject:currentPackage forKey:[currentPackage objectForKey:@"Package"]];
            [mutableList addObject:currentPackage];
        }
        
        currentPackage = nil;
        
    }
    
    NSSortDescriptor *nameDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES
                                                                    selector:@selector(localizedCaseInsensitiveCompare:)];
    NSSortDescriptor *packageDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Package" ascending:YES
                                                                       selector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *descriptors = [NSArray arrayWithObjects:nameDescriptor, packageDescriptor, nil];
    NSArray *sortedArray = [mutableList sortedArrayUsingDescriptors:descriptors];
    
    mutableList = nil;
    
    return sortedArray;
}

// https://github.com/lechium/nitoTV/blob/53cca06514e79279fa89639ad05b562f7d730079/Classes/packageManagement.m#L854

+ (NSString *)domainFromRepoObject:(NSString *)repoObject
{
    //LogSelf;
    if ([repoObject length] == 0)return nil;
    NSArray *sourceObjectArray = [repoObject componentsSeparatedByString:@" "];
    NSString *url = [sourceObjectArray objectAtIndex:1];
    if ([url length] > 7)
    {
        NSString *urlClean = [url substringFromIndex:7];
        NSArray *secondArray = [urlClean componentsSeparatedByString:@"/"];
        return [secondArray objectAtIndex:0];
    }
    return nil;
}

// https://github.com/lechium/nitoTV/blob/53cca06514e79279fa89639ad05b562f7d730079/Classes/packageManagement.m#L869

+ (NSArray *)sourcesFromFile:(NSString *)theSourceFile
{
    NSMutableArray *finalArray = [[NSMutableArray alloc] init];
    NSString *sourceString = [[NSString stringWithContentsOfFile:theSourceFile encoding:NSASCIIStringEncoding error:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *sourceFullArray =  [sourceString componentsSeparatedByString:@"\n"];
    NSEnumerator *sourceEnum = [sourceFullArray objectEnumerator];
    id currentSource = nil;
    while (currentSource = [sourceEnum nextObject])
    {
        NSString *theObject = [SettingsTableViewController domainFromRepoObject:currentSource];
        if (theObject != nil)
        {
            if (![finalArray containsObject:theObject])
                [finalArray addObject:theObject];
        }
    }
    
    return finalArray;
}

+ (NSDictionary *)getDiagnostics {
    struct utsname u = { 0 };
    NSMutableDictionary *md = nil;
    uname(&u);
    md = [[NSMutableDictionary alloc] init];
    md[@"Sysname"] = [NSString stringWithUTF8String:u.sysname];
    md[@"Nodename"] = [NSString stringWithUTF8String:u.nodename];
    md[@"Release"] = [NSString stringWithUTF8String:u.release];
    md[@"Version"] = [NSString stringWithUTF8String:u.version];
    md[@"Machine"] = [NSString stringWithUTF8String:u.machine];
    md[@"ProductVersion"] = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"][@"ProductVersion"];
    md[@"ProductBuildVersion"] = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"][@"ProductBuildVersion"];
    md[@"Sources"] = [SettingsTableViewController sourcesFromFile:CYDIA_LIST];
    md[@"Packages"] = [SettingsTableViewController parsedPackageArray];
    md[@"Preferences"] = [[NSMutableDictionary alloc] init];
    md[@"Preferences"][@"TweakInjection"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_TWEAK_INJECTION];
    md[@"Preferences"][@"LoadDaemons"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_LOAD_DAEMONS];
    md[@"Preferences"][@"DumpAPTicket"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_DUMP_APTICKET];
    md[@"Preferences"][@"RefreshIconCache"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_REFRESH_ICON_CACHE];
    md[@"Preferences"][@"BootNonce"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_BOOT_NONCE];
    md[@"Preferences"][@"Exploit"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_EXPLOIT];
    md[@"Preferences"][@"DisableAutoUpdates"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_DISABLE_AUTO_UPDATES];
    md[@"Preferences"][@"DisableAppRevokes"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_DISABLE_APP_REVOKES];
    md[@"Preferences"][@"OverwriteBootNonce"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_OVERWRITE_BOOT_NONCE];
    md[@"Preferences"][@"ExportKernelTaskPort"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_EXPORT_KERNEL_TASK_PORT];
    md[@"AppVersion"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    md[@"LogFile"] = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:LOG_FILE] encoding:NSUTF8StringEncoding error:nil];
    return md;
}

+ (NSArray *) supportedBuilds {
    NSMutableArray *ma = [[NSMutableArray alloc] init];
    [ma addObject:@"15A"]; // 11.0
    [ma addObject:@"15B"]; // 11.1
    [ma addObject:@"15C"]; // 11.2
    [ma addObject:@"15D"]; // 11.2.5
    [ma addObject:@"15E"]; // 11.3
    [ma addObject:@"15F5037c"]; // 11.4 beta
    [ma addObject:@"15F5049c"]; // 11.4 beta 2
    [ma addObject:@"15F5061d"]; // 11.4 beta 3
    [ma addObject:@"15F5061e"]; // 11.4 beta 3
    return ma;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.tableView.frame];
    backgroundView.backgroundColor = [UIColor whiteColor];
    backgroundView.alpha = 0.84;
    backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Clouds"]];
    backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    backgroundImageView.frame = backgroundView.frame;
    [backgroundView addSubview:backgroundImageView];
    
    self.tableView.backgroundView = backgroundView;
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    
    self.bootNonceTextField.delegate = self;
    
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(userTappedAnyware:)];
    self.tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.tap];
}

// FIXME: - This is digusting, but there's worse things in the current code soo
// Pretty ugly but you can only really notice it when slowly scrolling down ~ nullpixel
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y > 0) {
        [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    } else {
        [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    }
}

- (void)userTappedAnyware:(UITapGestureRecognizer *) sender
{
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)reloadData {
    [self.TweakInjectionSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_TWEAK_INJECTION]];
    [self.LoadDaemonsSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_LOAD_DAEMONS]];
    [self.DumpAPTicketSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_DUMP_APTICKET]];
    [self.bootNonceTextField setPlaceholder:[[NSUserDefaults standardUserDefaults] objectForKey:@K_BOOT_NONCE]];
    [self.bootNonceTextField setText:nil];
    [self.RefreshIconCacheSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_REFRESH_ICON_CACHE]];
    [self.KernelExploitSegmentedControl setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@K_EXPLOIT]];
    [self.DisableAutoUpdatesSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_DISABLE_AUTO_UPDATES]];
    [self.DisableAppRevokesSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_DISABLE_APP_REVOKES]];
    [self.KernelExploitSegmentedControl setEnabled:[[self _provisioningProfileAtPath:[[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"]][@"Entitlements"][@"com.apple.developer.networking.multipath"] boolValue] forSegmentAtIndex:1];
    [self.KernelExploitSegmentedControl setEnabled:([[[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"][@"ProductBuildVersion"] rangeOfString:@"15A"].location != NSNotFound || [[[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"][@"ProductBuildVersion"] rangeOfString:@"15B"].location != NSNotFound) forSegmentAtIndex:2];
    [self.OpenCydiaButton setEnabled:[[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]]];
    [self.ExpiryLabel setPlaceholder:[NSString stringWithFormat:@"%d Days", (int)[[self _provisioningProfileAtPath:[[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"]][@"ExpirationDate"] timeIntervalSinceDate:[NSDate date]] / 86400]];
    [self.OverwriteBootNonceSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_OVERWRITE_BOOT_NONCE]];
    [self.ExportKernelTaskPortSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_EXPORT_KERNEL_TASK_PORT]];
    [self.RestoreRootFSSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_RESTORE_ROOTFS]];
    [self.UptimeLabel setPlaceholder:[NSString stringWithFormat:@"%d Days", (int)uptime() / 86400]];
    [self.tableView reloadData];
}

- (IBAction)TweakInjectionSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.TweakInjectionSwitch isOn] forKey:@K_TWEAK_INJECTION];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}
- (IBAction)LoadDaemonsSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.LoadDaemonsSwitch isOn] forKey:@K_LOAD_DAEMONS];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}
- (IBAction)DumpAPTicketSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.DumpAPTicketSwitch isOn] forKey:@K_DUMP_APTICKET];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (IBAction)BootNonceTextFieldTriggered:(id)sender {
    uint64_t val = 0;
    if ([[NSScanner scannerWithString:[self.bootNonceTextField text]] scanHexLongLong:&val] && val != HUGE_VAL && val != -HUGE_VAL) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@ADDR, val] forKey:@K_BOOT_NONCE];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Invalid Entry" message:@"The boot nonce entered could not be parsed" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *OK = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:OK];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    [self reloadData];
}

- (IBAction)RefreshIconCacheSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.RefreshIconCacheSwitch isOn] forKey:@K_REFRESH_ICON_CACHE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}
- (IBAction)KernelExploitSegmentedControl:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:self.KernelExploitSegmentedControl.selectedSegmentIndex forKey:@K_EXPLOIT];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (IBAction)DisableAppRevokesSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.DisableAppRevokesSwitch isOn] forKey:@K_DISABLE_APP_REVOKES];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

extern void iosurface_die(void);
extern int vfs_die(void);
extern int mptcp_die(void);

- (IBAction)tappedOnRestart:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), ^{
        NOTICE("The device will be restarted.", 1);
        while (1) {
            vfs_die();
            iosurface_die();
            mptcp_die();
        }
    });
}

- (IBAction)DisableAutoUpdatesSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.DisableAutoUpdatesSwitch isOn] forKey:@K_DISABLE_AUTO_UPDATES];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (IBAction)tappedOnShareDiagnosticsData:(id)sender {
    NSURL *URL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/Documents/diagnostics.plist", NSHomeDirectory()]];
    [[SettingsTableViewController getDiagnostics] writeToURL:URL error:nil];
    RESET_LOGS();
    START_LOGGING();
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[URL] applicationActivities:nil];
    if ([activityViewController respondsToSelector:@selector(popoverPresentationController)]) {
        [[activityViewController popoverPresentationController] setSourceView:self.ShareDiagnosticsDataButton];
    }
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (IBAction)tappedOnOpenCydia:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://"] options:@{} completionHandler:nil];
}
- (IBAction)OverwriteBootNonceSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.OverwriteBootNonceSwitch isOn] forKey:@K_OVERWRITE_BOOT_NONCE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (IBAction)tappedOnGetTechnicalSupport:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.gg/jb"] options:@{} completionHandler:nil];
}

- (IBAction)tappedOnCheckForUpdate:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), ^{
        NSString *Update = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"https://github.com/pwn20wndstuff/Undecimus/raw/master/Update.txt"] encoding:NSUTF8StringEncoding error:nil];
        if (Update == nil) {
            NOTICE("Failed to check for update.", 1);
        } else if ([Update isEqualToString:[NSString stringWithFormat:@"%@\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]]) {
            NOTICE("Already up to date.", 1);
        } else {
            NOTICE("An update is available.", 1);
        }
    });
}
- (IBAction)exportKernelTaskPortSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.ExportKernelTaskPortSwitch isOn] forKey:@K_EXPORT_KERNEL_TASK_PORT];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}
- (IBAction)RestoreRootFSSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.RestoreRootFSSwitch isOn] forKey:@K_RESTORE_ROOTFS];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UITableViewHeaderFooterView *)footerView forSection:(NSInteger)section {
    footerView.textLabel.textAlignment = NSTextAlignmentCenter;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
