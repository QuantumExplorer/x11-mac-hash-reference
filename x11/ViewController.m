//
//  ViewController.m
//  x11
//
//  Created by Sam Westrich on 6/21/16.
//  Copyright © 2016 Dash. All rights reserved.
//

#import "ViewController.h"
#import "NSData+Blake.h"
#import "NSData+Bmw.h"
#import "NSData+CubeHash.h"
#import "NSData+Echo.h"
#import "NSData+Groestl.h"
#import "NSData+Jh.h"
#import "NSData+Keccak.h"
#import "NSData+Luffa.h"
#import "NSData+Shavite.h"
#import "NSData+Simd.h"
#import "NSData+Skein.h"
#import "NSData+Dash.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

-(bool)is8BitInput {
    return self.inputInt8;
}

-(IBAction)blake:(id)sender {
    NSString * fox = self.input.stringValue;
    NSData * foxData = [fox dataUsingEncoding:NSASCIIStringEncoding];
    NSLog(@"%@", foxData);
    NSData * blaked = [foxData blake512];
    NSString * blakedString = [blaked hexadecimalString];
        [self.output setString:blakedString];
}

-(IBAction)bmw:(id)sender {
    NSString * fox = self.input.stringValue;
    NSData * foxData = [fox dataUsingEncoding:NSASCIIStringEncoding];
    NSData * bmwed = [foxData bmw512];
    NSString * bmwedString = [bmwed hexadecimalString];
    [self.output setString:bmwedString];
}

-(IBAction)cubehash:(id)sender {
    NSString * cubehash = self.input.stringValue;
    NSData * cubehashData = [cubehash dataUsingEncoding:NSASCIIStringEncoding];
    NSData * cubeHashed = [cubehashData cubehash512];
    NSString * cubeHashedString = [cubeHashed hexadecimalString];
    [self.output setString:cubeHashedString];
    
}

-(IBAction)echo:(id)sender {
    NSString * echo = self.input.stringValue;
    NSData * echoData = [echo dataUsingEncoding:NSASCIIStringEncoding];
    NSData * echoed = [echoData echo512];
    NSString * echoedString = [echoed hexadecimalString];
    [self.output setString:echoedString];
    
}

-(IBAction)groestl:(id)sender {
    NSString * groestl = self.input.stringValue;
    NSData * groestlData = [groestl dataUsingEncoding:NSASCIIStringEncoding];
    NSData * groestled = [groestlData groestl512];
    NSString * groestledString = [groestled hexadecimalString];
    [self.output setString:groestledString];
    
}

-(IBAction)jh:(id)sender {
    NSString * jh = self.input.stringValue;
    NSData * jhData = [jh dataUsingEncoding:NSASCIIStringEncoding];
    NSData * jhed = [jhData jh512];
    NSString * jhedString = [jhed hexadecimalString];
    [self.output setString:jhedString];
    
}

-(IBAction)keccak:(id)sender {
    NSString * string = self.input.stringValue;
    NSData * stringData = [string dataUsingEncoding:NSASCIIStringEncoding];
    NSData * hashed = [stringData keccak512];
    NSString * hashedString = [hashed hexadecimalString];
    [self.output setString:hashedString];
    
}

-(IBAction)luffa:(id)sender {
    NSString * luffa = self.input.stringValue;
    NSData * luffaData = [luffa dataUsingEncoding:NSASCIIStringEncoding];
    NSData * luffaed = [luffaData luffa512];
    NSString * luffaString = [luffaed hexadecimalString];
    [self.output setString:luffaString];
    
}

-(IBAction)shavite:(id)sender {
    NSString * shavite = self.input.stringValue;
    NSData * shaviteData = [shavite dataUsingEncoding:NSASCIIStringEncoding];
    NSData * shavited = [shaviteData shavite512];
    NSString * shavitString = [shavited hexadecimalString];
    [self.output setString:shavitString];
    
}

-(IBAction)simd:(id)sender {
    NSString * simd = self.input.stringValue;
    NSData * simdData = [simd dataUsingEncoding:NSASCIIStringEncoding];
    NSData * simded = [simdData simd512];
    NSString * simdString = [simded hexadecimalString];
    [self.output setString:simdString];
    
}

-(IBAction)skein:(id)sender {
    NSString * fox = self.input.stringValue;
    NSData * foxData = [fox dataUsingEncoding:NSASCIIStringEncoding];
    NSData * skeined = [foxData skein512];
    NSString * skeinedString = [skeined hexadecimalString];
    [self.output setString:skeinedString];
}

-(IBAction)x11:(id)sender {
    NSString * fox = self.input.stringValue;
    NSData * foxData = [fox dataUsingEncoding:NSASCIIStringEncoding];
    NSData * skeined = [foxData x11];
    NSString * skeinedString = [skeined hexadecimalString];
    [self.output setString:skeinedString];
}

@end
