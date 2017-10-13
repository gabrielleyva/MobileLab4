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

-(void)processImage{
    
    cv::Mat frame_gray,image_copy;
    cv::Mat image = self.image;
    switch (self.processType) {
        case 1:
        {
            cvtColor(image, frame_gray, CV_BGR2GRAY );
            bitwise_not(frame_gray, image);
            break;
        }
        case 2:
        {
            char text[50];
            Scalar avgPixelIntensity;
            
            cvtColor(image, image_copy, CV_BGRA2RGB); // get rid of alpha for processing
            avgPixelIntensity = cv::mean( image_copy );
            sprintf(text,"Avg. B: %.3f, G: %.3f, R: %.3f", avgPixelIntensity.val[0],avgPixelIntensity.val[1],avgPixelIntensity.val[2]);
            cv::putText(image, text, cv::Point(10, 100), FONT_HERSHEY_PLAIN, 0.75, Scalar::all(255), 1, 2);
            break;
            
        }
        default:
        {
            char text[50];
            Scalar avgPixelIntensity;
            
            cvtColor(image, image_copy, CV_BGRA2RGB); // get rid of alpha for processing
            avgPixelIntensity = cv::mean( image_copy );
            sprintf(text,"Avg. B: %.3f, G: %.3f, R: %.3f", avgPixelIntensity.val[0],avgPixelIntensity.val[1],avgPixelIntensity.val[2]);
            cv::putText(image, text, cv::Point(10, 100), FONT_HERSHEY_PLAIN, 0.75, Scalar::all(255), 1, 2);
            break;
        }
        
    }
    self.image = image;
    
}




@end
