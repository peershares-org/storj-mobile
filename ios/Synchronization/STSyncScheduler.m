//
//  STSyncScheduler.m
//  StorjMobile
//
//  Created by Bogdan Artemenko on 6/18/18.
//  Copyright © 2018 Storj. All rights reserved.
//

#import "STSyncScheduler.h"
#import "SyncSettings.h"
#import "STSettingsRepository.h"
#import "STSyncService.h"
#import <UIKit/UIDevice.h>
#import "Reachability.h"
#import "Logger.h"
#import "STPrepareSyncService.h"

@implementation STSyncScheduler
{
@private
  dispatch_queue_t workerQueue;
}
static STSettingsRepository *settingsRepository;

static STSyncScheduler *instance;

static STSyncService *syncService;

static NSTimer *rescheduleSyncTimer;
static NSTimer *startSyncTimer;

-(instancetype) init
{
  if(self = [super init])
  {
    workerQueue = dispatch_queue_create("io.storj.mobile.sync.schedule.queue",
                                        DISPATCH_QUEUE_SERIAL);
  }
  
  return self;
}

+(instancetype) sharedInstance
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[STSyncScheduler alloc] init];
  });
  
  return instance;
}

-(STSyncService *) syncService
{
  if(!syncService)
  {
    syncService = [STSyncService sharedInstance];
  }
  
  return syncService;
}

-(STSettingsRepository *) settingsRepository
{
  if(!settingsRepository)
  {
    settingsRepository = [[STSettingsRepository alloc] init];
  }
  
  return settingsRepository;
}

-(void) scheduleSync
{
  dispatch_async(workerQueue, [self getScheduleSyncTask]);
}

-(dispatch_block_t) getScheduleSyncTask
{
  dispatch_block_t scheduleSyncTask = ^
  {
    NSString *userEmail = [[NSUserDefaults standardUserDefaults] objectForKey:@"email"];
    SettingsDbo *syncSettings = [[self settingsRepository] getById:userEmail];
    NSLog(@"Sync settings: %@", [[syncSettings toModel] toDictionary]);
    if(!syncSettings)
    {
      [self rescheduleSyncTask];
      return;
    }
    if(![self isMemberOfBitmask:syncSettings.syncSettings
                          value: SyncON])
    {
      [Logger log: @"Synchronization turned off."];
      //[self rescheduleSyncTask];
      return;
    }
    
    BOOL isWiFiRequired = [self isMemberOfBitmask: syncSettings.syncSettings
                                            value: SyncOnWifi];
    if(isWiFiRequired && ![self isOnWiFi])
    {
      [Logger log: @"WiFi connection required for synchronization."];
      [self rescheduleSyncTask];
      return;
    }
    
    BOOL isDeviceOnChargingRequired = [self isMemberOfBitmask: syncSettings.syncSettings
                                                        value: SyncOnCharge];
    if(isDeviceOnChargingRequired && ![self isCharging])
    {
      [Logger log: @"Device must be on charge for synchronization."];
      [self rescheduleSyncTask];
      return;
    }
    
#pragma mark TODO add checker for Photos and Documents.
    
    STPrepareSyncService *prepareSyncService = [[STPrepareSyncService alloc] init];
    NSArray * syncQueue = [prepareSyncService prepareSyncQueue];
    
    if(!syncQueue)
    {
      [Logger log: @"Empty synchronization queue."];
      [self rescheduleSyncTask];
      return;
    }
    
    if(rescheduleSyncTimer && [rescheduleSyncTimer isValid])
    {
      [rescheduleSyncTimer invalidate];
    }
    
    [[STSyncService sharedInstance] startSync];
  };
  return scheduleSyncTask;
}

-(BOOL) isMemberOfBitmask: (int) mask
                    value: (int) value
{
  return  (mask & value) == value;
}

-(void) rescheduleSyncTask
{
  [Logger log:@"Rescheduling synchronization"];
  
    if(rescheduleSyncTimer)
    {
      if([rescheduleSyncTimer isValid])
      {
        [Logger log:@"Rescheduling already done. Waiting to fire"];
      } else
      {
        [self setRescheduleTimer];
      }
    } else
    {
      [self setRescheduleTimer];
    }
}

-(void) startSyncDelayed
{
  if(startSyncTimer)
  {
    if([startSyncTimer isValid])
    {
      [Logger log:@"Sync already scheduled. Waiting to start"];
    } else
    {
      [self setStartSyncTimer];
    }
  } else
  {
    [self setStartSyncTimer];
  }
}

-(void) setRescheduleTimer
{
  dispatch_async(dispatch_get_main_queue(), ^{
    rescheduleSyncTimer = [NSTimer scheduledTimerWithTimeInterval: (60 * 15)
                                             target: self
                                           selector: @selector(scheduleSync)
                                           userInfo: nil
                                            repeats: NO];
    [Logger log:@"Synchronization rescheduled"];
  });
}

-(void) setStartSyncTimer
{
  dispatch_async(dispatch_get_main_queue(), ^{
    startSyncTimer = [NSTimer scheduledTimerWithTimeInterval: (60 * 0.2)
                                                           target: self
                                                         selector: @selector(scheduleSync)
                                                         userInfo: nil
                                                          repeats: NO];
    [Logger log:@"Synchronization start scheduled"];
  });
}

-(void) cancelStartSyncTimer
{
  if(startSyncTimer)
  {
    if([startSyncTimer isValid])
    {
      [startSyncTimer invalidate];
    }
  }
  startSyncTimer = nil;
}

-(void) cancelRescheduleSyncTimer
{
  if(rescheduleSyncTimer)
  {
    if([rescheduleSyncTimer isValid])
    {
      [rescheduleSyncTimer invalidate];
    }
  }
  rescheduleSyncTimer = nil;
}

-(void) cancelSchedule
{
  [[STSyncService sharedInstance] stopSync];
  
  [self cancelStartSyncTimer];
  [self cancelRescheduleSyncTimer];
}

-(BOOL) isOnWiFi
{
  Reachability *internetReachability = [Reachability reachabilityForInternetConnection];
  
  NetworkStatus networkStatus = [internetReachability currentReachabilityStatus];
  
  return ReachableViaWiFi == networkStatus;
}

-(BOOL) isCharging
{
  [[UIDevice currentDevice] setBatteryMonitoringEnabled: YES];
  UIDeviceBatteryState batteryState = [[UIDevice currentDevice] batteryState];
  
  return batteryState == UIDeviceBatteryStateFull || batteryState == UIDeviceBatteryStateCharging;
}

@end
