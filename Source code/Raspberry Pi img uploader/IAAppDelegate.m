//
//  IAAppDelegate.m
//  Raspberry Pi img uploader
//
//  Created by Ondrej Rafaj on 26/12/2012.
//  Copyright (c) 2012 Fuerte Innovations. All rights reserved.
//

#import "IAAppDelegate.h"
#import <DiskArbitration/DiskArbitration.h>
#import <Security/Security.h>
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
@property (nonatomic, strong) NSMutableArray *allDrivesBSDNamesAvailable;

@property (nonatomic, strong) NSDictionary *selectedDrive;

@property (nonatomic, strong) NSTimer *valueReadingInvokationTimer;

@property (nonatomic) BOOL isOneDriveSelected;

@property (nonatomic) NSDate *startProcessTime;


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

#pragma mark Execution

- (NSString *)executeFile:(NSString *)file withParameters:(NSArray *)arr {
    NSDictionary *error = [NSDictionary new];
    NSString *path = [[[NSBundle mainBundle] pathForResource:file ofType:@"sh"] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
    NSString *params = @"";
    for (NSString *p in arr) {
        params = [params stringByAppendingFormat:@" %@", [p stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "]];
    }
    NSString *script =  [NSString stringWithFormat:@"do shell script \"sh %@%@\" with administrator privileges", path, params];
    //NSLog(@"Script: %@", script);
    NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
    NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&error];
    if (result) {
        return [result stringValue];
    }
    else {
        [self logEvent:@"Error" withDetail:[error objectForKey:@"NSAppleScriptErrorMessage"]];
    }
    return nil;
    
//    NSString *string;
//    STPrivilegedTask *task = [[STPrivilegedTask alloc] initWithLaunchPath:@"/bin/sh"];
//    NSMutableArray *newArr = [NSMutableArray arrayWithArray:arr];
//    [newArr insertObject:[[NSBundle mainBundle] pathForResource:file ofType:@"sh"] atIndex:0];
//    [task setArguments:newArr];
//    
//    [task launch];
//    NSFileHandle *outputFile = [task outputFileHandle];
//    
//    NSData *data = [outputFile readDataToEndOfFile];
//    string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
//    return string;
}

- (void)executeMainProcess {
    @autoreleasepool {
        NSString *bsdName = [_selectedDrive objectForKey:@"DAMediaBSDName"];
        NSMutableArray *unmounts = [NSMutableArray array];
        for (NSString *s in _allDrivesBSDNamesAvailable) {
            if ([s containsString:bsdName]) [unmounts addObject:s];
        }
        NSString *unmountString = [unmounts componentsJoinedByString:@":"];
        NSArray *arr = [NSArray arrayWithObjects:bsdName, _pathField.stringValue, unmountString, nil];
        NSString *data = [self executeFile:@"main" withParameters:arr];
        [self performSelectorOnMainThread:@selector(logEvent:) withObject:data waitUntilDone:NO];
        [self performSelectorOnMainThread:@selector(processFinished) withObject:nil waitUntilDone:NO];
        [_valueReadingInvokationTimer invalidate];
        _valueReadingInvokationTimer = nil;
    }
}

- (void)startExecutingMainProcessOnBackground {
    @autoreleasepool {
        [self performSelectorInBackground:@selector(executeMainProcess) withObject:nil];
    }
}

- (NSInteger)getProcessId {
    // sudo ps
    /*
     Ondrejs-Maxi-Mini:RasPiWrite-master maxi$ sudo ps
     PID TTY           TIME CMD
     380 ttys000    0:00.04 login -pfl maxi /bin/bash -c exec -la bash /bin/bash
     8009 ttys000    0:00.01 sudo dd if=/Users/maxi/Projects/RaspBerry Pi/RasPiWrite-master/Gingerbread+EthernetManager.img of=/dev/disk1 bs=1m count=100
     8010 ttys000    0:00.45 dd if=/Users/maxi/Projects/RaspBerry Pi/RasPiWrite-master/Gingerbread+EthernetManager.img of=/dev/disk1 bs=1m count=100
     1350 ttys002    0:00.05 login -pfl maxi /bin/bash -c exec -la bash /bin/bash
     8012 ttys002    0:00.01 sudo ps
     8013 ttys002    0:00.02 ps
    //*/
    
    return 0;
}

- (NSDictionary *)progressInfo {
    // sudo kill -INFO 8070
    // 47185920 bytes transferred in 34.425458 secs (1370669 bytes/sec)
    return nil;
}

- (NSString *)elapsedTimeLabelText {
    NSTimeInterval elapsedTime = [_startProcessTime timeIntervalSinceNow];
    div_t h = div(elapsedTime, 3600);
    int hours = (h.quot * -1);
    div_t m = div(h.rem, 60);
    int minutes = (m.quot * -1);
    int seconds = (m.rem * -1);
    NSString *timeLabelString = [NSString stringWithFormat:@"%d hours %d min %d sec", hours, minutes, seconds];
    return timeLabelString;
}

#pragma mark Runtime methods

- (void)processFinished {
    NSString *finishedLine = [NSString stringWithFormat:@"Finished: %@", [self elapsedTimeLabelText]];
    [_elapsedTimeLabel setStringValue:finishedLine];
    
    [_spinningIndicator stopAnimation:nil];
    [_browseButton setEnabled:YES];
    [_pathField setEnabled:YES];
    [_deviceList setEnabled:YES];
    
    _startProcessTime = nil;
    
    [self validateForStartButton];
}

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
    else {
        if (!_allDrivesBSDNamesAvailable) _allDrivesBSDNamesAvailable = [NSMutableArray array];
        if ([deviceInfo objectForKey:@"DAMediaBSDName"]) [_allDrivesBSDNamesAvailable addObject:[NSString stringWithFormat:@"%@", [deviceInfo objectForKey:@"DAMediaBSDName"]]];
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
    if (ok && !_startProcessTime) {
        [_startButton setEnabled:YES];
        [self logEvent:@"Uploader is ready!"];
    }
}

//- (void)updateTimer {
//    _elapsedTime++;
//    [_elapsedTimeLabel setStringValue:[NSString stringWithFormat:@"%.0f", _elapsedTime]];
//}

- (void)updateElapsedTimeDisplay:(NSTimer *)timer {
    NSString *timeLabelString = [self elapsedTimeLabelText];
    [_elapsedTimeLabel setStringValue:timeLabelString];
}

#pragma mark Application delegate methods

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [_elapsedTimeLabel setStringValue:@"00:00:00"];
    [NSThread detachNewThreadSelector:@selector(startCheckingForDevicesOnBackground) toTarget:self withObject:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
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
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Warning!\n\nIf you are not sure what you doing, just think twice before you click OK. This app will erase all the content on the target device and will install the new image that you have selected on it! This software is distributed as is. You are on your own responsibility when using it"];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

#pragma mark Alert view Delegate methods

- (void)alertDidEnd:(NSAlert *)a returnCode:(NSInteger)rc contextInfo:(void *)ci {
    switch(rc) {
        case NSAlertFirstButtonReturn:
            [self logEvent:@"Start uploading!"];
            //[_progressIndicator setHidden:NO];
            [_spinningIndicator startAnimation:nil];
            [_startButton setEnabled:NO];
            [_browseButton setEnabled:NO];
            [_pathField setEnabled:NO];
            [_deviceList setEnabled:NO];
            
            _startProcessTime = [NSDate date];
            _valueReadingInvokationTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateElapsedTimeDisplay:) userInfo:nil repeats:YES];
            [NSThread detachNewThreadSelector:@selector(startExecutingMainProcessOnBackground) toTarget:self withObject:nil];
            break;
        case NSAlertSecondButtonReturn:
            break;
    }
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
