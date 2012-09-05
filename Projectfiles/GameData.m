//
//  GameData.m
//  Peeved Penguins
//
//  Created by BrianC on 8/21/12.
//
//

#import "GameData.h"

@implementation GameData

@synthesize contacts;

static GameData *sharedData = nil;
+(GameData*) sharedData{
    if(sharedData == nil)
    {
        sharedData = [[super allocWithZone:NULL] init];
        sharedData.contacts = [[NSMutableSet alloc] init];
    }
    return sharedData;
}

@end
