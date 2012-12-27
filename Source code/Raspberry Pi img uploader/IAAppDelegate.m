//
//  IAAppDelegate.m
//  Raspberry Pi img uploader
//
//  Created by Ondrej Rafaj on 26/12/2012.
//  Copyright (c) 2012 Fuerte Innovations. All rights reserved.
//

#import "IAAppDelegate.h"
#import <DiskArbitration/DiskArbitration.h>
#import "NSString+StringTools.h"


#define kIAAppDelegateLastUsedPathKey                           @"IAAppDelegateLastUsedPathKey"


#pragma mark - Static device handling methods


IAAppDelegate *refToSelf;
sig_atomic_t sShouldExit = 0;

static void RegisterInterruptHandler(void);
static void HandleInterrupt(int);
static void OnDiskAppeared(DADiskRef disk, void *__attribute__((__unused__)));

static void RegisterInterruptHandler(void) {
    struct sigaction sigact;
    sigact.sa_handler = HandleInterrupt;
    (void)sigaction(SIGINT, &sigact, NULL );
}

static void HandleInterrupt(int __attribute__((__unused__)) signo) {
    sShouldExit = 1;
    RegisterInterruptHandler();
}

static void OnDiskAppeared(DADiskRef disk, void *__attribute__((__unused__)) ctx) {
    NSDictionary *d = (__bridge NSDictionary*)DADiskCopyDescription(disk);
    [refToSelf performSelectorOnMainThread:@selector(addNewDeviceToTheList:) withObject:d waitUntilDone:NO];
}

static void OnDiskDisappeared(DADiskRef disk, void *__attribute__((__unused__)) ctx) {
    NSDictionary *d = (__bridge NSDictionary*)DADiskCopyDescription(disk);
    [refToSelf performSelectorOnMainThread:@selector(removeDeviceFromTheList:) withObject:d waitUntilDone:NO];
}


#pragma mark - App delegate private methods

@interface IAAppDelegate ()

@property (nonatomic, strong) NSMutableArray *drivesAvailable;
@property (nonatomic, strong) NSMutableArray *drivesNamesAvailable;

@property (nonatomic, strong) NSDictionary *selectedDrive;

@property (nonatomic) BOOL isOneDriveSelected;


- (void)validateForStartButton;


@end


#pragma mark - App delegate integration

@implementation IAAppDelegate


#pragma mark Logging

- (void)logEvent:(NSString *)event {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterLongStyle];
    NSString *formattedDateString = [dateFormatter stringFromDate:[NSDate date]];
    [_logContainer setString:[NSString stringWithFormat:@"%@%@%@ - %@", _logContainer.string, (_logContainer.string.length > 0 ? @"\n" : @""), formattedDateString, event]];
    [_logContainer scrollToEndOfDocument:nil];
}

- (void)logEvent:(NSString *)event withDetail:(NSString *)detail {
    [self logEvent:[NSString stringWithFormat:@"%@: %@", event, detail]];
}

#pragma mark Runtime methods

- (void)disableDiskLoadingLoop {
    sShouldExit = 1;
}

- (void)checkForDevicesOnBackground {
    @autoreleasepool {
        refToSelf = self;
        
        CFStringRef const kDARunLoopMode = kCFRunLoopDefaultMode;
        
        RegisterInterruptHandler();
        
        DASessionRef session = DASessionCreate(kCFAllocatorDefault);
        DARegisterDiskAppearedCallback(session, NULL, OnDiskAppeared, (void *)NULL);
        DARegisterDiskDisappearedCallback(session, NULL, OnDiskDisappeared, (void *)NULL);
        DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), kDARunLoopMode);
        
        const Boolean kAndReturnAfterHandlingSource = TRUE;
        const CFTimeInterval kForOneSecond = 1.0;
        while (!sShouldExit) {
            (void)CFRunLoopRunInMode(kCFRunLoopDefaultMode, kForOneSecond, kAndReturnAfterHandlingSource);
        }
        
        DASessionUnscheduleFromRunLoop(session, CFRunLoopGetCurrent(), kDARunLoopMode);
        CFRelease(session);
    }
}

- (void)startCheckingForDevicesOnBackground {
    @autoreleasepool {
        [self performSelectorInBackground:@selector(checkForDevicesOnBackground) withObject:nil];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [NSThread detachNewThreadSelector:@selector(startCheckingForDevicesOnBackground) toTarget:self withObject:nil];
}

- (BOOL)isDriveInfoValid:(NSDictionary *)driveInfo {
    return ([[driveInfo objectForKey:@"DAMediaContent"] isEqualToString:@"FDisk_partition_scheme"]);
}

- (void)addNewDeviceToTheList:(NSDictionary *)deviceInfo {
    NSString *name = [NSString stringWithFormat:@"%@ (/dev/%@, %@)", [deviceInfo objectForKey:@"DAMediaName"], [deviceInfo objectForKey:@"DAMediaBSDName"], [deviceInfo objectForKey:@"DADeviceProtocol"]];
    BOOL ok = YES;
    // TODO: Check the following commented code is really obsolete!
    /*
     // Was used for prior determination if the disk is suitable, should be working fine without it!
     if ([(NSString *)[d objectForKey:@"DAMediaBSDName"] containsString:@"disk0"]) ok = NO;
     if (![d objectForKey:@"DAMediaBSDName"]) ok = NO;
     if ([[d objectForKey:@"DAVolumeKind"] isEqualToString:@"afpfs"]) ok = NO;
     if ([[d objectForKey:@"DADeviceProtocol"] isEqualToString:@"Virtual Interface"]) ok = NO;
     //*/
    if (![self isDriveInfoValid:deviceInfo]) ok = NO;
    
    if (ok) {
        if (!_drivesAvailable) _drivesAvailable = [NSMutableArray array];
        if (!_drivesNamesAvailable) _drivesNamesAvailable = [NSMutableArray array];
        if (!_deviceList.dataSource) {
            [_deviceList setDataSource:self];
            [_deviceList setDelegate:self];
            [_logContainer setDelegate:self];
            [_logContainer setAutomaticSpellingCorrectionEnabled:NO];
            [_logContainer setAutomaticDashSubstitutionEnabled:NO];
            [_logContainer setAutomaticQuoteSubstitutionEnabled:NO];
            [_logContainer setAutomaticTextReplacementEnabled:NO];
        }
        [_drivesAvailable addObject:deviceInfo];
        [_drivesNamesAvailable addObject:name];
        [_deviceList noteNumberOfItemsChanged];
        [_deviceList reloadData];
        if (!_isOneDriveSelected) {
            //[_deviceList selectItemWithObjectValue:name];
        }
        [self logEvent:@"New drive available" withDetail:name];
    }
    [self validateForStartButton];
}

- (void)removeDeviceFromTheList:(NSDictionary *)deviceInfo {
    if ([self isDriveInfoValid:deviceInfo]) {
        NSString *existingDrive = [NSString stringWithFormat:@"%@", [deviceInfo objectForKey:@"DAMediaBSDName"]];
        NSArray *arr = [NSArray arrayWithArray:_drivesAvailable];
        for (NSDictionary *drive in arr) {
            NSString *driveToBeRemoved = [NSString stringWithFormat:@"%@", [drive objectForKey:@"DAMediaBSDName"]];
            if ([existingDrive isEqualToString:driveToBeRemoved]) {
                NSString *selectedDrive = [NSString stringWithFormat:@"%@", [_selectedDrive objectForKey:@"DAMediaBSDName"]];
                if ([selectedDrive isEqualToString:driveToBeRemoved]) {
                    _selectedDrive = nil;
                }
                NSInteger indexToRemove = [_drivesAvailable indexOfObject:drive];
                [_drivesAvailable removeObjectAtIndex:indexToRemove];
                NSString *name = [_drivesNamesAvailable objectAtIndex:indexToRemove];
                [self logEvent:@"Removing drive" withDetail:name];
                [_drivesNamesAvailable removeObjectAtIndex:indexToRemove];
                [_deviceList noteNumberOfItemsChanged];
                [_deviceList reloadData];
                NSInteger selectedIndex = [_deviceList indexOfSelectedItem];
                if (selectedIndex == indexToRemove) {
                    if ([_drivesAvailable count] > 0) {
                        [_deviceList selectItemAtIndex:0];
                        _selectedDrive = [_drivesAvailable objectAtIndex:0];
                    }
                }
            }
        }
    }
    [self validateForStartButton];
}

- (void)validateForStartButton {
    BOOL ok = YES;
    if (!_selectedDrive) ok = NO;
    if ([_pathField.stringValue length] < 2) ok = NO;
    if (ok) {
        [_startButton setEnabled:YES];
        [self logEvent:@"Uploader is ready!"];
    }
}

#pragma mark Actions

- (IBAction)didPressBrowseButton:(NSButton *)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    [openPanel setDelegate:self];
    NSString *lastPath = [[NSUserDefaults standardUserDefaults] stringForKey:kIAAppDelegateLastUsedPathKey];
    if (!lastPath) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		lastPath = [paths objectAtIndex:0];
    }
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:lastPath isDirectory:YES]];
    [openPanel setOpaque:YES];
    if ([openPanel runModal] == NSOKButton) {
        NSURL *fileUrl = [[openPanel URLs] lastObject];
        NSString *selectedFileName = [fileUrl path];
        [[NSUserDefaults standardUserDefaults] setValue:[[fileUrl path] stringByDeletingLastPathComponent] forKey:kIAAppDelegateLastUsedPathKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [_pathField setStringValue:selectedFileName];
        [self validateForStartButton];
        [self logEvent:@"Path selected" withDetail:[[fileUrl path] lastPathComponent]];
    }
}

- (IBAction)didPressStartButton:(NSButton *)sender {
    [self logEvent:@"Start uploading!"];
    [_progressIndicator setHidden:NO];
    [_spinningIndicator startAnimation:nil];
    [_startButton setEnabled:NO];
    [_browseButton setEnabled:NO];
    [_pathField setEnabled:NO];
    [_deviceList setEnabled:NO];
}

#pragma mark Text field delegate methods

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor {
    [self didPressBrowseButton:_browseButton];
    return NO;
}

#pragma mark Text view delegate methods

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    return NO;
}

#pragma mark Combo box data source & delegate methods

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    return [_drivesNamesAvailable objectAtIndex:index];
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    return [_drivesNamesAvailable count];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSComboBox *cb = notification.object;
    NSInteger index = [_deviceList indexOfSelectedItem];
    _selectedDrive = [_drivesAvailable objectAtIndex:index];
    [self logEvent:@"Drive selected" withDetail:[_drivesNamesAvailable objectAtIndex:cb.indexOfSelectedItem]];
    [self validateForStartButton];
}

#pragma mark Panel delegate methods

- (void)panel:(id)sender directoryDidChange:(NSString *)path {
    [[NSUserDefaults standardUserDefaults] setValue:path forKey:kIAAppDelegateLastUsedPathKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename {
    NSString* ext = [filename pathExtension];
    if (ext == @"" || ext == @"/" || ext == nil || ext == NULL || [ext length] < 1) {
        return YES;
    }
    NSEnumerator *tagEnumerator = [[NSArray arrayWithObjects:@"img", nil] objectEnumerator];
    NSString *allowedExt;
    while ((allowedExt = [tagEnumerator nextObject])) {
        if ([ext caseInsensitiveCompare:allowedExt] == NSOrderedSame) {
            return YES;
        }
    }
    return NO;
}


@end
