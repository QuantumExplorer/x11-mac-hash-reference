//
//  ViewController.h
//  x11
//
//  Created by Sam Westrich on 6/21/16.
//  Copyright © 2016 Dash. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

-(IBAction)blake:(id)sender;
-(IBAction)bmw:(id)sender;
-(IBAction)cubehash:(id)sender;
-(IBAction)echo:(id)sender;
-(IBAction)groestl:(id)sender;
-(IBAction)jh:(id)sender;
-(IBAction)keccak:(id)sender;
-(IBAction)luffa:(id)sender;
-(IBAction)shavite:(id)sender;
-(IBAction)simd:(id)sender;
-(IBAction)skein:(id)sender;

@property(nonatomic,strong) IBOutlet NSTextField * input;
@property(nonatomic,strong) IBOutlet NSTextView * output;
@property(nonatomic,strong) IBOutlet NSButton * inputInt8;

@end

