//
//  IAAppDelegate.h
//  Raspberry Pi img uploader
//
//  Created by Ondrej Rafaj on 26/12/2012.
//  Copyright (c) 2012 Fuerte Innovations. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAAppDelegate : NSObject <NSApplicationDelegate, NSOpenSavePanelDelegate, NSComboBoxDataSource, NSComboBoxDelegate, NSTextFieldDelegate, NSTextViewDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (nonatomic, strong) IBOutlet NSTextField *pathField;
@property (nonatomic, strong) IBOutlet NSComboBox *deviceList;
@property (nonatomic, strong) IBOutlet NSLevelIndicator *progressIndicator;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *spinningIndicator;
@property (nonatomic, strong) IBOutlet NSButton *browseButton;
@property (nonatomic, strong) IBOutlet NSButton *startButton;

@property (nonatomic, strong) IBOutlet NSTextView *logContainer;


- (IBAction)didPressBrowseButton:(NSButton *)sender;
- (IBAction)didPressStartButton:(NSButton *)sender;

- (void)addNewDeviceToTheList:(NSDictionary *)deviceInfo;
- (void)removeDeviceFromTheList:(NSDictionary *)deviceInfo;


@end
