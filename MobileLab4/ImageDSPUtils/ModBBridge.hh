//
//  ModBBridge.h
//  MobileLab4
//
//  Created by Mandar Phadate on 10/11/17.
//  Copyright © 2017 Leyva_Phadate. All rights reserved.
//

#import "OpenCVBridge.hh"

@interface ModBBridge : OpenCVBridge
-(void)processImage;
@property (nonatomic) NSInteger processType;

@end
