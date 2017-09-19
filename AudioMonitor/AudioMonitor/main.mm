//
//  main.m
//  AudioMonitor
//
//  Created by Douglas Ward on 8/20/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioMonitor.h"

// AudioMonitor -r 10000 -v 1
//   -r is sample rate
//   -v is volume, 0 is silent, 1 is no change, 2 is double volume (not implemented yet)


int main(int argc, const char * argv[])
{
    @autoreleasepool {
        //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution
                
        NSString * argMode = @"";
        NSString * argSampleRate = @"10000";
        NSString * argVolume = @"0";
        
        for (int i = 0; i < argc; i++)
        {
            char * argStringPtr = (char *)argv[i];
            
            NSString * argString = [NSString stringWithFormat:@"%s", argStringPtr];
            
            //NSLog(@"arg %d %@", i, argString);
            
            if ([argString isEqualToString:@"-r"] == YES)
            {
                argMode = argString;
            }
            else if ([argMode isEqualToString:@"-r"] == YES)
            {
                argSampleRate = argString;
                argMode = @"";
            }
            else if ([argString isEqualToString:@"-v"] == YES)
            {
                argMode = argString;
            }
            else if ([argMode isEqualToString:@"-v"] == YES)
            {
                argVolume = argString;
                argMode = @"";
            }
        }

        AudioMonitor * audioMonitor = [[AudioMonitor alloc] init];
        
        NSInteger sampleRate = argSampleRate.integerValue;
        if (sampleRate <= 0)
        {
            sampleRate = 10000;
        }
        
        float volume = argVolume.floatValue;
        
        [audioMonitor runAudioMonitorWithSampleRate:sampleRate volume:volume];
        
        while (1)
        {
            [NSThread sleepForTimeInterval:0.1f];        
        }
    }
    
    return 0;
}
