//
//  SDRController.m
//  LocalRadio
//
//  Created by Douglas Ward on 5/29/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import "SDRController.h"
#import "NSFileManager+DirectoryLocations.h"
#import "AppDelegate.h"
#import "SoxController.h"
#import "UDPStatusListenerController.h"
#import "LocalRadioAppSettings.h"
#import "EZStreamController.h"

@implementation SDRController

//==================================================================================
//	dealloc
//==================================================================================

- (void)dealloc
{
    //[self.udpSocket close];
    //self.udpSocket = NULL;

    /*
    if (self.currentInfoSocket != NULL)
    {
        [self.currentInfoSocket disconnect];
        self.currentInfoSocket = NULL;
    }
    */
}

//==================================================================================
//	init
//==================================================================================

- (instancetype)init
{
    self = [super init];
    if (self) {
        /*
        self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        NSError *error = nil;
        
        if (![self.udpSocket bindToPort:0 error:&error])
        {
            NSLog(@"Error binding: %@", error);
            return nil;
        }
        
        NSError * socketReceiveError = NULL;
        [self.udpSocket beginReceiving:&socketReceiveError];
        */

        self.rtlsdrTaskMode = @"stopped";
    }
    return self;
}

//==================================================================================
//	terminateTasks
//==================================================================================

- (void)terminateTasks
{
    [self stopRtlsdrTasks];
    
    [self.appDelegate.soxController terminateTasks];
}

//==================================================================================
//	stopRtlsdrTasks
//==================================================================================

- (void)stopRtlsdrTasks
{
    if ((self.rtlfmTask == NULL) &&
            (self.audioMonitorTask == NULL) &&
            (self.soxTask == NULL) &&
            (self.udpSenderTask == NULL))
    {
        return;
    }
    
    //@synchronized (self) {

        NSLog(@"stopRtlsdrTask enter");

        if ([(NSThread*)[NSThread currentThread] isMainThread] == YES)
        {
            NSLog(@"stopRtlsdrTask called on main thread");
        }
        
        [self.appDelegate resetRtlsdrStatusText];

        /*
        if (self.currentInfoSocket != NULL)
        {
            [self.currentInfoSocket disconnect];
            self.currentInfoSocket = NULL;
        }
        */

        if (self.rtlfmTask != NULL)
        {
            if (self.rtlfmTask.isRunning == YES)
            {
                NSLog(@"stopRtlfmTask sending rtlfmTask terminate signal");
                [self.rtlfmTask terminate];
            }
        }

        if (self.audioMonitorTask != NULL)
        {
            if (self.audioMonitorTask.isRunning == YES)
            {
                NSLog(@"stopRtlsdrTask sending audioMonitorTask terminate signal");
                [self.audioMonitorTask terminate];
            }
        }
        
        if (self.soxTask != NULL)
        {
            if (self.soxTask.isRunning == YES)
            {
                NSLog(@"stopRtlsdrTask sending soxTask terminate signal");
                [self.soxTask terminate];
            }
        }
        
        if (self.udpSenderTask != NULL)
        {
            if (self.udpSenderTask.isRunning == YES)
            {
                NSLog(@"stopRtlsdrTask sending soxTask terminate signal");
                [self.udpSenderTask terminate];
            }
        }
        
        [self.appDelegate.soxController terminateTasks];
        
        if (self.appDelegate.applicationIsTerminating == NO)
        {
            if ([(NSThread*)[NSThread currentThread] isMainThread] == NO)
            {
                while (self.rtlfmTask != NULL)
                {
                    //NSLog(@"SDRController stopRtlsdrTask waiting for self.rtlsdrTask != NULL");
                    [NSThread sleepForTimeInterval:0.1f];
                }
            }
        }
        
        self.rtlsdrTaskMode = @"stopped";

        NSLog(@"stopRtlsdrTask exit");
    //}
}

//==================================================================================
//	startRtlsdrTasksForFrequency:
//==================================================================================

- (void)startRtlsdrTasksForFrequency:(NSDictionary *)frequencyDictionary
{
    //NSLog(@"startRtlsdrTaskForFrequency:category");
    
    CGFloat delay = 0.0;
    
    //[self stopRtlsdrTask];

    if (self.rtlfmTask != NULL)
    {
        [self stopRtlsdrTasks];
        
        //delay = 1.0;    // one second
        delay = 0.2;
    }

    self.rtlsdrTaskMode = @"frequency";
    
    int64_t dispatchDelay = (int64_t)(delay * NSEC_PER_SEC);
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, dispatchDelay);

    //dispatch_after(dispatchTime, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{

        NSArray * frequenciesArray = [NSArray arrayWithObject:frequencyDictionary];
        
        [self dispatchedStartRtlsdrTasksForFrequencies:frequenciesArray category:NULL];
    });
    
}

//==================================================================================
//	startRtlsdrTasksForFrequencies:category:
//==================================================================================

- (void)startRtlsdrTasksForFrequencies:(NSArray *)frequenciesArray category:(NSMutableDictionary *)categoryDictionary
{
    //NSLog(@"startRtlsdrTaskForFrequencies:category");

    CGFloat delay = 0.0;
    
    if (self.rtlfmTask != NULL)
    {
        [self stopRtlsdrTasks];
        
        //delay = 1.0;    // one second
        delay = 0.2;    // one second
    }

    self.rtlsdrTaskMode = @"scan";
    self.rtlsdrCategoryDictionary = categoryDictionary;

    int64_t dispatchDelay = (int64_t)(delay * NSEC_PER_SEC);
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, dispatchDelay);
    
    //dispatch_after(dispatchTime, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{
        [self dispatchedStartRtlsdrTasksForFrequencies:frequenciesArray category:categoryDictionary];
    });
}

//==================================================================================
//	dispatchedStartRtlsdrTasksForFrequencies:category:
//==================================================================================

- (void)dispatchedStartRtlsdrTasksForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary
{
    // frequenciesArray contains one or more frequency record dictionaries
    // category contains a category record dictionary

    //NSLog(@"dispatchedStartRtlsdrTaskForFrequencies:category");

    //NSRunLoop * currentRunLoop = [NSRunLoop currentRunLoop];
    
    if (self.rtlfmTask != NULL)
    {
        NSLog(@"Error self.rtlfmTask != NULL");
    }
    if (self.rtlfmTaskStandardErrorPipe != NULL)
    {
        NSLog(@"Error self.rtlfmTaskStandardErrorPipe != NULL");
    }

    /*
    if (self.currentInfoSocket != NULL)
    {
        [self.currentInfoSocket disconnect];
        self.currentInfoSocket = NULL;
    }
    */
    
    NSString * rtl_fmPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"rtl_fm_localradio"];
    rtl_fmPath = [rtl_fmPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedRtlfmPath = [NSMutableString stringWithFormat:@"\"%@\"", rtl_fmPath];
    NSMutableArray * rtlfmArgsArray = [NSMutableArray array];

    NSString * audioMonitorPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"AudioMonitor"];
    audioMonitorPath = [audioMonitorPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedAudioMonitorPath = [NSString stringWithFormat:@"\"%@\"", audioMonitorPath];
    NSMutableArray * audioMonitorArgsArray = [NSMutableArray array];

    NSString * soxPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"sox"];
    soxPath = [soxPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedSoxPath = [NSMutableString stringWithFormat:@"\"%@\"", soxPath];
    NSMutableArray * soxArgsArray = [NSMutableArray array];
    
    NSString * udpSenderPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"UDPSender"];
    udpSenderPath = [udpSenderPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedUDPSenderPath = [NSString stringWithFormat:@"\"%@\"", udpSenderPath];
    NSMutableArray * udpSenderArgsArray = [NSMutableArray array];
    
    // variables common to both Favorites and Categories
    NSString * nameString = @"";
    NSNumber * categoryScanningEnabledNumber = [NSNumber numberWithInteger:0];
    NSMutableString * frequencyString = [NSMutableString stringWithFormat:@"-f 89100000"];  // can be single frequency, multiple frequencies or range
    NSNumber * samplingModeNumber = [NSNumber numberWithInteger:0];
    NSNumber * tunerGainNumber = [NSNumber numberWithFloat:49.5f];
    NSNumber * tunerAGCNumber = [NSNumber numberWithInteger:0];
    NSNumber * tunerSampleRateNumber = [NSNumber numberWithInteger:10000];
    NSNumber * oversamplingNumber = [NSNumber numberWithInteger:4];
    NSString * modulationString = @"fm";
    NSNumber * squelchLevelNumber = [NSNumber numberWithInteger:0];
    NSNumber * squelchDelayNumber = [NSNumber numberWithInteger:0];
    NSString * optionsString = @"";
    NSNumber * firSizeNumber = [NSNumber numberWithInteger:9];
    NSString * atanMathString = @"std";
    NSString * audioOutputFilterString = @"";
    NSString * audioOutputString = @"";
    NSString * streamSourceString = @"";

    //NSString * statusPortString = self.appDelegate.statusPortTextField.stringValue;
    NSNumber * statusPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"StatusPort"];
    
    NSString * statusFunctionString = @"No active tuning";
    
    BOOL enableDirectSamplingQBranchMode = NO;
    BOOL enableTunerAGC = NO;
    
    if (categoryDictionary == NULL)
    {
        if (frequenciesArray.count == 1)
        {
            // tune to a single Favorites frequency
            NSDictionary * firstFrequencyDictionary = frequenciesArray.firstObject;
            
            nameString = [firstFrequencyDictionary objectForKey:@"station_name"];
            categoryScanningEnabledNumber = [NSNumber numberWithInteger:0];
            samplingModeNumber = [firstFrequencyDictionary objectForKey:@"sampling_mode"];
            tunerGainNumber = [firstFrequencyDictionary objectForKey:@"tuner_gain"];
            tunerAGCNumber = [firstFrequencyDictionary objectForKey:@"tuner_agc"];
            tunerSampleRateNumber = [firstFrequencyDictionary objectForKey:@"sample_rate"];
            oversamplingNumber = [firstFrequencyDictionary objectForKey:@"oversampling"];
            modulationString = [firstFrequencyDictionary objectForKey:@"modulation"];
            squelchLevelNumber = [firstFrequencyDictionary objectForKey:@"squelch_level"];
            optionsString = [firstFrequencyDictionary objectForKey:@"options"];
            firSizeNumber = [firstFrequencyDictionary objectForKey:@"fir_size"];
            atanMathString = [firstFrequencyDictionary objectForKey:@"atan_math"];
            audioOutputFilterString = [firstFrequencyDictionary objectForKey:@"audio_output_filter"];
            audioOutputString = [firstFrequencyDictionary objectForKey:@"audio_output"];
            streamSourceString = [firstFrequencyDictionary objectForKey:@"stream_source"];

            NSNumber * frequencyModeNumber = [firstFrequencyDictionary objectForKey:@"frequency_mode"]; // 0 = single frequency, 1 = frequency range
            NSInteger frequencyMode = [frequencyModeNumber integerValue];
            
            NSString * aFrequencyString = [firstFrequencyDictionary objectForKey:@"frequency"];
            NSString * aFrequencyScanEndString = [firstFrequencyDictionary objectForKey:@"frequency_scan_end"];
            NSString * aFrequencyScanIntervalString = [firstFrequencyDictionary objectForKey:@"frequency_scan_interval"];

            frequencyString = [NSMutableString stringWithFormat:@"-f %@", aFrequencyString];

            if (frequencyMode == 1)
            {
                // use scan range start, end and interval
                frequencyString = [NSMutableString stringWithFormat:@"-f %@:%@:%@", aFrequencyString, aFrequencyScanEndString, aFrequencyScanIntervalString];
            }
            
            NSInteger samplingMode = [samplingModeNumber integerValue];
            if (samplingMode == 2)
            {
                enableDirectSamplingQBranchMode = YES;
            }
            
            NSInteger tunerAGC = [tunerAGCNumber integerValue];
            if (tunerAGC == 1)
            {
                enableTunerAGC = YES;
            }
            
            statusFunctionString = [NSString stringWithFormat:@"Tuned to %@", nameString];

            self.appDelegate.udpStatusListenerController.nowPlayingDictionary = [firstFrequencyDictionary mutableCopy];
            [self.appDelegate.udpStatusListenerController.statusCacheDictionary removeAllObjects];
        }
        else
        {
            NSLog(@"LocalRadio error - wrong frequenciesArray.count");
            statusFunctionString = @"Error: wrong frequenciesArray.count";
        }
    }
    else
    {
        // scan one or more frequencies for the category
        nameString = [categoryDictionary objectForKey:@"category_name"];
        categoryScanningEnabledNumber = [categoryDictionary objectForKey:@"category_scanning_enabled"];
        samplingModeNumber = [categoryDictionary objectForKey:@"scan_sampling_mode"];
        tunerGainNumber = [categoryDictionary objectForKey:@"scan_tuner_gain"];
        tunerAGCNumber = [categoryDictionary objectForKey:@"scan_tuner_agc"];
        tunerSampleRateNumber = [categoryDictionary objectForKey:@"scan_sample_rate"];
        oversamplingNumber = [categoryDictionary objectForKey:@"scan_oversampling"];
        modulationString = [categoryDictionary objectForKey:@"scan_modulation"];
        squelchLevelNumber = [categoryDictionary objectForKey:@"scan_squelch_level"];
        squelchDelayNumber = [categoryDictionary objectForKey:@"scan_squelch_delay"];
        optionsString = [categoryDictionary objectForKey:@"scan_options"];
        firSizeNumber = [categoryDictionary objectForKey:@"scan_fir_size"];
        atanMathString = [categoryDictionary objectForKey:@"scan_atan_math"];
        audioOutputFilterString = [categoryDictionary objectForKey:@"scan_audio_output_filter"];
        audioOutputString = [categoryDictionary objectForKey:@"scan_audio_output"];
        streamSourceString = [categoryDictionary objectForKey:@"scan_stream_source"];

        [frequencyString setString:@""];
        
        for (NSDictionary * frequencyDictionary in frequenciesArray)
        {
            NSNumber * frequencyModeNumber = [frequencyDictionary objectForKey:@"frequency_mode"]; // 0 = single frequency, 1 = frequency range
            NSInteger frequencyMode = [frequencyModeNumber integerValue];

            NSString * aFrequencyString = [frequencyDictionary objectForKey:@"frequency"];
            NSString * aFrequencyScanEndString = [frequencyDictionary objectForKey:@"frequency_scan_end"];
            NSString * aFrequencyScanIntervalString = [frequencyDictionary objectForKey:@"frequency_scan_interval"];

            NSString * aFrequencyComboString = [NSMutableString stringWithFormat:@"-f %@", aFrequencyString];
            

            if (frequencyMode == 1) // use scan range start, end and interval
            {
                aFrequencyComboString = [NSMutableString stringWithFormat:@"-f %@:%@:%@", aFrequencyString, aFrequencyScanEndString, aFrequencyScanIntervalString];
            }

            if (frequencyString.length > 0)
            {
                [frequencyString appendString:@" "];
            }
            
            //[frequencyString appendFormat:@"-f %@ ", aFrequencyComboString];
            [frequencyString appendString:aFrequencyComboString];

            if ([frequenciesArray indexOfObject:frequencyDictionary] == 0)
            {
                self.appDelegate.udpStatusListenerController.nowPlayingDictionary = [frequencyDictionary mutableCopy];
                [self.appDelegate.udpStatusListenerController.statusCacheDictionary removeAllObjects];
            }
        }

        NSInteger samplingMode = [samplingModeNumber integerValue];
        if (samplingMode == 2)
        {
            enableDirectSamplingQBranchMode = YES;
        }

        NSInteger tunerAGC = [tunerAGCNumber integerValue];
        if (tunerAGC == 1)
        {
            enableTunerAGC = YES;
        }

        statusFunctionString = [NSString stringWithFormat:@"Scanning category: %@", nameString];
    }
    
    NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    audioOutputString = [audioOutputString stringByTrimmingCharactersInSet:whitespaceCharacterSet];
    streamSourceString = [streamSourceString stringByTrimmingCharactersInSet:whitespaceCharacterSet];
    
    [rtlfmArgsArray addObject:@"-M"];
    [rtlfmArgsArray addObject:modulationString];
    [rtlfmArgsArray addObject:@"-l"];
    [rtlfmArgsArray addObject:squelchLevelNumber];
    [rtlfmArgsArray addObject:@"-t"];
    [rtlfmArgsArray addObject:squelchDelayNumber];
    [rtlfmArgsArray addObject:@"-F"];
    [rtlfmArgsArray addObject:firSizeNumber];
    [rtlfmArgsArray addObject:@"-g"];
    [rtlfmArgsArray addObject:tunerGainNumber];
    [rtlfmArgsArray addObject:@"-s"];
    [rtlfmArgsArray addObject:tunerSampleRateNumber];
    
    if ([oversamplingNumber integerValue] > 0)
    {
        [rtlfmArgsArray addObject:@"-o"];
        [rtlfmArgsArray addObject:oversamplingNumber];
    }
    
    [rtlfmArgsArray addObject:@"-A"];
    [rtlfmArgsArray addObject:atanMathString];
    [rtlfmArgsArray addObject:@"-p"];
    [rtlfmArgsArray addObject:@"0"];
    [rtlfmArgsArray addObject:@"-c"];
    //[rtlfmArgsArray addObject:currentInfoServerPortString];
    [rtlfmArgsArray addObject:statusPortNumber.stringValue];

    [rtlfmArgsArray addObject:@"-E"];
    [rtlfmArgsArray addObject:@"pad"];
    
    if (enableDirectSamplingQBranchMode == YES)
    {
        [rtlfmArgsArray addObject:@"-E"];
        [rtlfmArgsArray addObject:@"direct"];
    }
    
    if (enableTunerAGC == YES)
    {
        [rtlfmArgsArray addObject:@"-E"];
        [rtlfmArgsArray addObject:@"agc"];
    }
    
    NSArray * optionsArray = [optionsString componentsSeparatedByString:@" "];
    for (NSString * aOptionString in optionsArray)
    {
        NSString * trimmedOptionString = [aOptionString stringByTrimmingCharactersInSet:whitespaceCharacterSet];
        if (trimmedOptionString.length > 0)
        {
            [rtlfmArgsArray addObject:@"-E"];
            [rtlfmArgsArray addObject:trimmedOptionString];
        }
    }
    
    NSArray * parsedFrequenciesArray = [frequencyString componentsSeparatedByString:@" "];
    for (NSString * parsedItem in parsedFrequenciesArray)
    {
        [rtlfmArgsArray addObject:parsedItem];
    }
    
    NSMutableArray * fixRtlfmArgsArray = [NSMutableArray array];
    for (id rtlfmArgsObject in rtlfmArgsArray)
    {
        id rtlfmArgsString = rtlfmArgsObject;
        if ([rtlfmArgsString isKindOfClass:[NSNumber class]] == YES)
        {
            rtlfmArgsString = [rtlfmArgsString stringValue];
        }
        [fixRtlfmArgsArray addObject:rtlfmArgsString];
    }
    rtlfmArgsArray = fixRtlfmArgsArray;
    



    
    [audioMonitorArgsArray addObject:@"-r"];
    [audioMonitorArgsArray addObject:tunerSampleRateNumber];

    NSString * livePlaythroughVolume = @"0.0";
    if (self.appDelegate.useWebViewAudioPlayerCheckbox.state == NO)
    {
        livePlaythroughVolume = @"1.0";
    }
    [audioMonitorArgsArray addObject:@"-v"];
    [audioMonitorArgsArray addObject:livePlaythroughVolume];

    NSMutableArray * fixAudioMonitorArgsArray = [NSMutableArray array];
    for (id audioMonitorArgsObject in audioMonitorArgsArray)
    {
        id audioMonitorArgsString = audioMonitorArgsObject;
        if ([audioMonitorArgsString isKindOfClass:[NSNumber class]] == YES)
        {
            audioMonitorArgsString = [audioMonitorArgsString stringValue];
        }
        [fixAudioMonitorArgsArray addObject:audioMonitorArgsString];
    }
    audioMonitorArgsArray = fixAudioMonitorArgsArray;
    
    
    
    BOOL useSecondaryStreamSource = NO;
    
    if ([audioOutputString isEqualToString:@"icecast"])
    {
        // configure rtl_fm_localradio for output to UDPSender (then to EZStream/Icecast)
        
        [soxArgsArray addObject:@"-r"];
        //[soxArgsArray addObject:tunerSampleRateNumber];
        [soxArgsArray addObject:@"48000"];      // assume input from AudioMonitor already resampled to 48000 Hz
        
        [soxArgsArray addObject:@"-e"];
        [soxArgsArray addObject:@"signed-integer"];
        
        [soxArgsArray addObject:@"-b"];
        [soxArgsArray addObject:@"16"];
        
        [soxArgsArray addObject:@"-c"];
        [soxArgsArray addObject:@"1"];
        
        [soxArgsArray addObject:@"-t"];
        [soxArgsArray addObject:@"raw"];
        
        [soxArgsArray addObject:@"-"];         // stdin
        
        [soxArgsArray addObject:@"-t"];
        [soxArgsArray addObject:@"raw"];
        
        [soxArgsArray addObject:@"-"];         // stdout
        
        [soxArgsArray addObject:@"rate"];
        [soxArgsArray addObject:@"48000"];
        
        NSArray * audioOutputFilterStringArray = [audioOutputFilterString componentsSeparatedByString:@" "];
        for (NSString * audioOutputFilterStringItem in audioOutputFilterStringArray)
        {
            [soxArgsArray addObject:audioOutputFilterStringItem];
        }

        NSMutableArray * fixSoxArgsArray = [NSMutableArray array];
        for (id soxArgsObject in soxArgsArray)
        {
            id soxArgsString = soxArgsObject;
            if ([soxArgsString isKindOfClass:[NSNumber class]] == YES)
            {
                soxArgsString = [soxArgsString stringValue];
            }
            [fixSoxArgsArray addObject:soxArgsString];
        }
        soxArgsArray = fixSoxArgsArray;

        // configure UDPSender task

        [udpSenderArgsArray addObject:@"-p"];
        NSNumber * audioPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"AudioPort"];
        [udpSenderArgsArray addObject:audioPortNumber.stringValue];
    }
    else
    {
        // configure rtl_fm_localradio for output to a Core Audio device
        // audioOutputString should be a Core Audio output devicename
        // and start a secondary sox task to relay from a different Core Audio device to UDPSender
        // This can be useful with some third-party audio routing utilities, like SoundFlower
        
        [soxArgsArray addObject:@"-V2"];    // debug verbosity, -V2 shows failures and warnings
        [soxArgsArray addObject:@"-q"];    // quiet mode - don't show terminal-style audio meter
        
        // input args

        [soxArgsArray addObject:@"-r"];
        //[soxArgsArray addObject:tunerSampleRateNumber];
        [soxArgsArray addObject:@"48000"];      // assume input from AudioMonitor already resampled to 48000 Hz
        
        [soxArgsArray addObject:@"-e"];
        [soxArgsArray addObject:@"signed-integer"];
        
        [soxArgsArray addObject:@"-b"];
        [soxArgsArray addObject:@"16"];
        
        [soxArgsArray addObject:@"-c"];
        [soxArgsArray addObject:@"1"];
        
        [soxArgsArray addObject:@"-t"];
        [soxArgsArray addObject:@"raw"];
        
        [soxArgsArray addObject:@"-"];         // stdin

        // output args
        
        [soxArgsArray addObject:@"-e"];
        //[soxArgsArray addObject:@"signed-integer"];
        [soxArgsArray addObject:@"float"];
        
        [soxArgsArray addObject:@"-b"];
        //[soxArgsArray addObject:@"16"];
        [soxArgsArray addObject:@"32"];
        
        [soxArgsArray addObject:@"-c"];
        //[soxArgsArray addObject:@"1"];
        [soxArgsArray addObject:@"2"];
        
        // send output to a Core Audio device
        [soxArgsArray addObject:@"-t"];

        [soxArgsArray addObject:@"coreaudio"];       // first stage audio output
        [soxArgsArray addObject:audioOutputString];  // quotes are omitted intentionally
        
        [soxArgsArray addObject:@"rate"];
        [soxArgsArray addObject:@"48000"];

        // output sox options like vol, etc.
        NSArray * audioOutputFilterStringArray = [audioOutputFilterString componentsSeparatedByString:@" "];
        for (NSString * audioOutputFilterStringItem in audioOutputFilterStringArray)
        {
            [soxArgsArray addObject:audioOutputFilterStringItem];
        }

        NSMutableArray * fixSoxArgsArray = [NSMutableArray array];
        for (id soxArgsObject in soxArgsArray)
        {
            id soxArgsString = soxArgsObject;
            if ([soxArgsString isKindOfClass:[NSNumber class]] == YES)
            {
                soxArgsString = [soxArgsString stringValue];
            }
            [fixSoxArgsArray addObject:soxArgsString];
        }
        soxArgsArray = fixSoxArgsArray;
        
        useSecondaryStreamSource = YES;     // create a separate task to get audio to EZStream
    }

    self.rtlfmTaskArgsString = [rtlfmArgsArray componentsJoinedByString:@" "];
    self.audioMonitorTaskArgsString = [audioMonitorArgsArray componentsJoinedByString:@" "];
    self.soxTaskArgsString = [soxArgsArray componentsJoinedByString:@" "];
    self.udpSenderTaskArgsString = [udpSenderArgsArray componentsJoinedByString:@" "];
    
    self.rtlfmTask = [[NSTask alloc] init];
    self.rtlfmTask.launchPath = rtl_fmPath;
    self.rtlfmTask.arguments = rtlfmArgsArray;

    // sox will output to UDPSender or a Core Audio device
    self.soxTask = [[NSTask alloc] init];
    self.soxTask.launchPath = soxPath;
    self.soxTask.arguments = soxArgsArray;
    
    [self.rtlfmTask setStandardInput:[NSPipe pipe]];       // empty pipe for first stage stdin

    // TODO: BUG: For an undetermined reason, AudioMonitor fails to launch as an NSTask in a sandboxed app extracted from an Xcode Archive
    // if the application path contains a space (e.g., "~/Untitled Folder/LocalRadio.app".
    // Prefixing backslashes before spaces in the path did not help.  The error message in Console.log says "launch path not accessible".
    // As a workaround, alert the user if the condition exists and suggest removing the spaces from the folder name.
    self.audioMonitorTask = [[NSTask alloc] init];
    self.audioMonitorTask.launchPath = audioMonitorPath;
    self.audioMonitorTask.arguments = audioMonitorArgsArray;

    // configure NSPipe to connect rtl_fm_localradio stdout to audiomonitor stdin
    self.rtlsdrAudioMonitorPipe = [NSPipe pipe];
    [self.rtlfmTask setStandardOutput:self.rtlsdrAudioMonitorPipe];
    [self.audioMonitorTask setStandardInput:self.rtlsdrAudioMonitorPipe];
    



    // configure NSPipe to connect audiomonitor stdout to sox stdin
    self.audioMonitorSoxPipe = [NSPipe pipe];
    [self.audioMonitorTask setStandardOutput:self.audioMonitorSoxPipe];
    [self.soxTask setStandardInput:self.audioMonitorSoxPipe];
    
    if (useSecondaryStreamSource == NO)
    {
        self.udpSenderTask = [[NSTask alloc] init];
        self.udpSenderTask.launchPath = udpSenderPath;
        self.udpSenderTask.arguments = udpSenderArgsArray;
        
        // configure NSPipe to connect sox stdout to udpSender stdin
        self.soxUDPSenderPipe = [NSPipe pipe];
        [self.soxTask setStandardOutput:self.soxUDPSenderPipe];
        [self.udpSenderTask setStandardInput:self.soxUDPSenderPipe];
        
        [self.udpSenderTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]]; // set last stage stdout to /dev/null
    }
    else
    {
        //[self.soxTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]]; // set last stage stdout to /dev/null
        //[self.soxTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    }
    
    SDRController * weakSelf = self;
    
    [self.rtlfmTask setTerminationHandler:^(NSTask* task)
    {
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"SDRController enter rtl_fm terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"SDRController - startRadioTaskForFrequency - rtl_fm terminationStatus 0");
            NSLog(@"SDRController - startRadioTaskForFrequency - rtl_fm terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"SDRController - startRadioTaskForFrequency - rtl_fm terminationStatus %d", terminationStatus);
            NSLog(@"SDRController - startRadioTaskForFrequency - rtl_fm terminationReason %ld", terminationReason);
        }
        
        weakSelf.rtlfmTask = NULL;
        weakSelf.rtlfmTaskStandardErrorPipe = NULL;
        weakSelf.rtlfmTaskArgsString = NULL;
        weakSelf.rtlfmTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"SDRController exit rtl_fm terminationHandler, PID=%d", processIdentifier);
    }];

    [self.audioMonitorTask setTerminationHandler:^(NSTask* task)
    {
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"SDRController enter AudioMonitor terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"SDRController - startRadioTaskForFrequency - AudioMonitor terminationStatus 0");
            NSLog(@"SDRController - startRadioTaskForFrequency - AudioMonitor terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"SDRController - startRadioTaskForFrequency - AudioMonitor terminationStatus %d", terminationStatus);
            NSLog(@"SDRController - startRadioTaskForFrequency - AudioMonitor terminationReason %ld", terminationReason);
        }
        
        weakSelf.audioMonitorTask = NULL;
        weakSelf.audioMonitorTaskStandardErrorPipe = NULL;
        weakSelf.audioMonitorTaskArgsString = NULL;
        weakSelf.audioMonitorTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"SDRController exit AudioMonitor terminationHandler, PID=%d", processIdentifier);
    }];

    [self.soxTask setTerminationHandler:^(NSTask* task)
    {
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"SDRController enter sox terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"SDRController - startRadioTaskForFrequency - sox terminationStatus 0");
            NSLog(@"SDRController - startRadioTaskForFrequency - sox terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"SDRController - startRadioTaskForFrequency - sox terminationStatus %d", terminationStatus);
            NSLog(@"SDRController - startRadioTaskForFrequency - sox terminationReason %ld", terminationReason);
        }
        
        weakSelf.soxTask = NULL;
        weakSelf.soxTaskStandardErrorPipe = NULL;
        weakSelf.soxTaskArgsString = NULL;
        weakSelf.soxTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"SDRController exit sox terminationHandler, PID=%d", processIdentifier);
    }];

    [self.udpSenderTask setTerminationHandler:^(NSTask* task)
    {
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"SDRController enter udpSenderTask terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"SDRController - startRadioTaskForFrequency - udpSenderTask terminationStatus 0");
            NSLog(@"SDRController - startRadioTaskForFrequency - udpSenderTask terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"SDRController - startRadioTaskForFrequency - udpSenderTask terminationStatus %d", terminationStatus);
            NSLog(@"SDRController - startRadioTaskForFrequency - udpSenderTask terminationReason %ld", terminationReason);
        }
        
        weakSelf.udpSenderTask = NULL;
        weakSelf.udpSenderTaskStandardErrorPipe = NULL;
        weakSelf.udpSenderTaskArgsString = NULL;
        weakSelf.udpSenderTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"SDRController exit udpSenderTask terminationHandler, PID=%d", processIdentifier);
    }];
    
    //NSLog(@"SDRController - launch delayedStartRtlsdrTaskForFrequency");


    [self.audioMonitorTask launch];
    NSLog(@"SDRController - Launched NSTask audioMonitorTask, PID=%d, args= %@ %@", self.audioMonitorTask.processIdentifier, self.quotedAudioMonitorPath, self.audioMonitorTaskArgsString);
    
    self.audioMonitorTaskProcessID = self.audioMonitorTask.processIdentifier;

    if (useSecondaryStreamSource == YES)
    {
        [self.appDelegate.soxController startSecondaryStreamForFrequencies:frequenciesArray category:categoryDictionary];
    }
    else
    {
        [self.udpSenderTask launch];
        NSLog(@"SDRController - Launched NSTask udpSenderTask, PID=%d, args= %@ %@", self.udpSenderTask.processIdentifier, self.quotedUDPSenderPath, self.udpSenderTaskArgsString);
        
        self.udpSenderTaskProcessID = self.udpSenderTask.processIdentifier;
    }

    [self.rtlfmTask launch];
    NSLog(@"SDRController - Launched NSTask rtlsdrTask, PID=%d, args= %@ %@", self.rtlfmTask.processIdentifier, self.quotedRtlfmPath, self.rtlfmTaskArgsString);

    self.rtlfmTaskProcessID = self.rtlfmTask.processIdentifier;

    self.rtlsdrTaskFrequenciesArray = frequenciesArray;
    
    [self.soxTask launch];
    NSLog(@"SDRController - Launched NSTask soxTask, PID=%d, args= %@ %@", self.soxTask.processIdentifier, self.quotedSoxPath, self.soxTaskArgsString);

    self.soxTaskProcessID = self.soxTask.processIdentifier;

    dispatch_async(dispatch_get_main_queue(), ^{
    
        [weakSelf.appDelegate updateCurrentTasksText];
        
        /*

        NSString * tasksString = [NSString stringWithFormat:@"%@ %@\n\n%@ %@\n\n%@ %@\n\n",
                self.appDelegate.ezStreamController.quotedUDPListenerPath, self.appDelegate.ezStreamController.udpListenerArgsString,
                self.appDelegate.ezStreamController.quotedSoxPath, self.appDelegate.ezStreamController.soxArgsString,
                self.appDelegate.ezStreamController.quotedEZStreamPath, self.appDelegate.ezStreamController.ezStreamArgsString];
        
        tasksString = [tasksString stringByAppendingFormat:@"%@ %@\n\n%@ %@",
                self.quotedRtlfmPath, self.rtlfmTaskArgsString, self.quotedSoxPath, self.soxTaskArgsString];
        
        if (useSecondaryStreamSource == NO)
        {
            tasksString = [tasksString stringByAppendingFormat:@"\n\n%@ %@", self.quotedUDPSenderPath, self.udpSenderTaskArgsString];
        }
        else
        {
            NSString * secondaryUDPSenderArgs = [self.appDelegate.soxController udpSenderArgsString];
            tasksString = [tasksString stringByAppendingFormat:@"\n\n%@ %@", self.quotedUDPSenderPath, secondaryUDPSenderArgs];
        }

        [self.appDelegate.statusCurrentTasksTextView setString:tasksString];
        */

        self.appDelegate.statusRTLSDRTextField.stringValue = @"Running";

        self.appDelegate.statusFunctionTextField.stringValue = statusFunctionString;
        
        NSString * displayFrequencyString = [NSString stringWithFormat:@"%@", frequencyString];
        displayFrequencyString = [displayFrequencyString stringByReplacingOccurrencesOfString:@"-f " withString:@""];
        NSString * megahertzString = [self.appDelegate shortHertzString:displayFrequencyString];
        self.appDelegate.statusFrequencyTextField.stringValue = megahertzString;
        
        self.appDelegate.statusModulationTextField.stringValue = modulationString;
        self.appDelegate.statusSamplingRateTextField.stringValue = tunerSampleRateNumber.stringValue;
        self.appDelegate.statusSquelchLevelTextField.stringValue = squelchLevelNumber.stringValue;
        self.appDelegate.statusTunerGainTextField.stringValue = [NSString stringWithFormat:@"%@", tunerGainNumber];
        self.appDelegate.statusRtlsdrOptionsTextField.stringValue = optionsString;
        self.appDelegate.statusSignalLevelTextField.stringValue = @"0";
        self.appDelegate.statusAudioOutputTextField.stringValue = audioOutputString;
        self.appDelegate.statusAudioOutputFilterTextField.stringValue = audioOutputFilterString;
        self.appDelegate.statusStreamSourceTextField.stringValue = streamSourceString;
        
        if (enableTunerAGC == YES)
        {
            self.appDelegate.statusTunerAGCTextField.stringValue = @"On";
        }
        else
        {
            self.appDelegate.statusTunerAGCTextField.stringValue = @"Off";
        }
        
        if (enableDirectSamplingQBranchMode == NO)
        {
            self.appDelegate.statusSamplingModeTextField.stringValue = @"Standard";
        }
        else
        {
            self.appDelegate.statusSamplingModeTextField.stringValue = @"Direct Q-branch";
        }
    });
}

//==================================================================================
//	radioTaskReceivedStderrData:
//==================================================================================

- (void)radioTaskReceivedStderrData:(NSNotification *)notif {

    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        // if data is found, re-register for more data (and print)
        //[fh waitForDataInBackgroundAndNotify];
        NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"rtlsdr: %@" , str);
    }
    [fh waitForDataInBackgroundAndNotify];
}

//==================================================================================
//	retuneTaskForFrequency:
//==================================================================================
/*
- (void)retuneTaskForFrequency:(NSDictionary *)frequencyDictionary
{
    char retuneCommand[5];
    
    NSData * udpData = NULL;

    // begin retuning
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 0;
    int beginRetuningInteger = 0;
    memcpy(&retuneCommand[1], &beginRetuningInteger, sizeof(beginRetuningInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set modulation
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 1;
    char modulationMode = 0;
    NSString * modulationString = [frequencyDictionary objectForKey:@"modulation"];
    if ([modulationString isEqualToString:@"fm"] == YES)
    {
        modulationMode = 0;
    }
    else if ([modulationString isEqualToString:@"wbfm"] == YES)
    {
        modulationMode = 0;
    }
    else if ([modulationString isEqualToString:@"am"] == YES)
    {
        modulationMode = 1;
    }
    else if ([modulationString isEqualToString:@"usb"] == YES)
    {
        modulationMode = 2;
    }
    else if ([modulationString isEqualToString:@"lsb"] == YES)
    {
        modulationMode = 3;
    }
    retuneCommand[1] = modulationMode;
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set sample rate
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 2;
    NSNumber * sampleRateNumber = [frequencyDictionary objectForKey:@"sample_rate"];
    int sampleRateInteger = sampleRateNumber.intValue;
    memcpy(&retuneCommand[1], &sampleRateInteger, sizeof(sampleRateInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set tuner gain
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 4;
    NSNumber * tunerGainNumber = [frequencyDictionary objectForKey:@"tuner_gain"];
    int tunerGainInteger = tunerGainNumber.intValue;
    memcpy(&retuneCommand[1], &tunerGainInteger, sizeof(tunerGainInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set automatic gain control
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 5;
    NSNumber * agcNumber = [frequencyDictionary objectForKey:@"automatic_gain_control"];
    int agcInteger = agcNumber.intValue;
    memcpy(&retuneCommand[1], &agcInteger, sizeof(tunerGainInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set squelch level
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 6;
    NSNumber * squelchLevelNumber = [frequencyDictionary objectForKey:@"squelch_level"];
    int squelchLevelInteger = squelchLevelNumber.intValue;
    memcpy(&retuneCommand[1], &squelchLevelInteger, sizeof(squelchLevelInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set frequency
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 7;
    NSNumber * frequencyNumber = [frequencyDictionary objectForKey:@"frequency"];
    int frequencyInteger = frequencyNumber.intValue;
    memcpy(&retuneCommand[1], &frequencyInteger, sizeof(frequencyInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);

    // end retuning
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 8;
    int endRetuningInteger = 0;
    memcpy(&retuneCommand[1], &endRetuningInteger, sizeof(endRetuningInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
}
*/



@end
