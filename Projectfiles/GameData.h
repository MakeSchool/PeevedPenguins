//
//  GameData.h
//  Peeved Penguins
//
//  Created by BrianC on 8/21/12.
//
//

#import <Foundation/Foundation.h>

@interface GameData : NSObject{
}

@property (nonatomic) NSMutableSet* contacts;


+(GameData*) sharedData;

@end
