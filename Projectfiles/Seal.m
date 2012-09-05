//
//  Seal.m
//  Peeved Penguins
//
//  Created by BrianC on 8/22/12.
//
//

#import "Seal.h"

@implementation Seal
@synthesize health;

-(id) initWithSealImage
{
	// This calls CCSprite's init. Basically this init method does everything CCSprite's init method does and then more
	if ((self = [super initWithFile:@"seal.png"]))
	{
        health = 2;
        //properties work internally just like normal instance variables
	}
	return self;
}


@end
