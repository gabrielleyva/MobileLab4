//
//  ModBBridge.m
//  MobileLab4
//
//  Created by Mandar Phadate on 10/11/17.
//  Copyright © 2017 Leyva_Phadate. All rights reserved.
//

#import "ModBBridge.hh"

using namespace cv;

@interface ModBBridge()
@property (nonatomic) cv::Mat image;

@end


@implementation ModBBridge
@dynamic image;
@dynamic processType;

-(float)processImage{
    
    cv::Mat frame_gray,image_copy;
    cv::Mat image = self.image;
    
    char text[50];
    Scalar avgPixelIntensity;
    
    cvtColor(image, image_copy, CV_BGRA2RGB); // get rid of alpha for processing
    avgPixelIntensity = cv::mean( image_copy );
    sprintf(text,"Avg. B: %.3f, G: %.3f, R: %.3f", avgPixelIntensity.val[0],avgPixelIntensity.val[1],avgPixelIntensity.val[2]);
    cv::putText(image, text, cv::Point(58, 100), FONT_HERSHEY_PLAIN, 0.75, Scalar::all(255), 1, 2);
    
    
    
    self.image = image;
    return avgPixelIntensity.val[2];
}




@end
