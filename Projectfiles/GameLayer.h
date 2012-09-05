/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "cocos2d.h"
#import "Box2D.h"
#import "ContactListener.h"
#import "GLES-Render.h"
enum
{
	kTagBatchNode,
};

@interface GameLayer : CCLayer
{
    GLESDebugDraw* debugDraw;
	b2World* world;
    int currentBullet;
    NSMutableArray *bullets;
    ContactListener *contactListener;
    
    b2Fixture *armFixture; //will store the shape and density information of the catapult arm
    b2Body *armBody;  //will store the position and type of the catapult arm
    b2RevoluteJoint *armJoint;
    
    b2MouseJoint *mouseJoint;
    b2Body *screenBorderBody; //we want to keep a global reference to the screen border
    
    b2Body *bulletBody;
    b2WeldJoint *bulletJoint;
    
    BOOL releasingArm;
    
    NSMutableSet *targets;
    NSMutableSet *enemies;
    
    CCAction *taunt;
    NSMutableArray *tauntingFrames;


}
+(id) scene;
- (void)createBullets: (int) count;

@end
