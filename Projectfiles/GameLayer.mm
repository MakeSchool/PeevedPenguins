/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "GameLayer.h"
#import "SimpleAudioEngine.h"
#import "Seal.h"
#import "Box2DDebugLayer.h"

const float PTM_RATIO = 32.0f;
#define FLOOR_HEIGHT    50.0f

CCSprite *projectile;
CCSprite *block;
CGRect firstrect;
CGRect secondrect;
NSMutableArray *blocks = [[NSMutableArray alloc] init];
CCSprite* background;


@interface GameLayer (PrivateMethods)
-(void) enableBox2dDebugDrawing;
-(void) addSomeJoinedBodies:(CGPoint)pos;
-(void) addNewSpriteAt:(CGPoint)p;
-(b2Vec2) toMeters:(CGPoint)point;
-(CGPoint) toPixels:(b2Vec2)vec;
@end

@implementation GameLayer


-(id) init
{
	if ((self = [super init]))
	{
		CCLOG(@"%@ init", NSStringFromClass([self class]));
        
        bullets = [[NSMutableArray alloc] init];
        
        // Construct a world object, which will hold and simulate the rigid bodies.
		b2Vec2 gravity = b2Vec2(0.0f, -10.0f);
		world = new b2World(gravity);
		world->SetAllowSleeping(YES);
		//world->SetContinuousPhysics(YES);
        
        //create an object that will check for collisions
		contactListener = new ContactListener();
		world->SetContactListener(contactListener);
        
		glClearColor(0.1f, 0.0f, 0.2f, 1.0f);
        
        CGSize screenSize = [CCDirector sharedDirector].winSize;
        
        [self enableBox2dDebugDrawing]; //Debug physics diagrams

        
        //Raise to floor height
        b2Vec2 lowerLeftCorner =b2Vec2(0,FLOOR_HEIGHT/PTM_RATIO);
        
        //Raise to floor height, extend to end of game area
        b2Vec2 lowerRightCorner = b2Vec2(screenSize.width*2.0f/PTM_RATIO,FLOOR_HEIGHT/PTM_RATIO);
        
        //No change
        b2Vec2 upperLeftCorner = b2Vec2(0,screenSize.height/PTM_RATIO);
        
        //Extend to end of game area.
        b2Vec2 upperRightCorner =b2Vec2(screenSize.width*2.0f/PTM_RATIO,screenSize.height/PTM_RATIO);
		
		// Define the static container body, which will provide the collisions at screen borders.
		b2BodyDef screenBorderDef;
		screenBorderDef.position.Set(0, 0);
        screenBorderBody = world->CreateBody(&screenBorderDef);
		b2EdgeShape screenBorderShape;
        
        screenBorderShape.Set(lowerLeftCorner, lowerRightCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(lowerRightCorner, upperRightCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(upperRightCorner, upperLeftCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(upperLeftCorner, lowerLeftCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        
        //Load the plist which tells Kobold2D how to properly parse your spritesheet. If on a retina device Kobold2D will automatically use bearframes-hd.plist
        
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile: @"bearframes.plist"];
        
        //Load in the spritesheet, if retina Kobold2D will automatically use bearframes-hd.png
        
        CCSpriteBatchNode *spriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"bearframes.png"];
        
        [self addChild:spriteSheet];
        
        //Define the frames based on the plist - note that for this to work, the original files must be in the format bear1, bear2, bear3 etc...
        
        //When it comes time to get art for your own original game, makegameswith.us will give you spritesheets that follow this convention, <spritename>1 <spritename>2 <spritename>3 etc...
        
        tauntingFrames = [NSMutableArray array];
        
        for(int i = 1; i <= 7; ++i)
        {
            [tauntingFrames addObject:
             [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName: [NSString stringWithFormat:@"bear%d.png", i]]];
        }
        
        
        //Add all the sprites to the game, including blocks and the catapult. It's tedious...
        //See the storing game data tutorial to learn how to abstract all of this out to a plist file
        
        background = [CCSprite spriteWithFile:@"background.png"];
        background.anchorPoint = CGPointZero;
        [self addChild:background z:-1];
        
        CCSprite* sprite = [CCSprite spriteWithFile:@"catapult.png"];
        sprite.anchorPoint = CGPointZero;
        sprite.position = CGPointMake(135.0f, FLOOR_HEIGHT);
        [self addChild:sprite z:0];
        
        //Initialize the bear with the first frame you loaded from your spritesheet, bear1
        
        sprite = [CCSprite spriteWithSpriteFrameName:@"bear1.png"];
        
        sprite.anchorPoint = CGPointZero;
        sprite.position = CGPointMake(50.0f, FLOOR_HEIGHT);
        
        //Create an animation from the set of frames you created earlier
        
        CCAnimation *taunting = [CCAnimation animationWithFrames: tauntingFrames delay:0.5f];
        
        //Create an action with the animation that can then be assigned to a sprite
        
        taunt = [CCRepeatForever actionWithAction: [CCAnimate actionWithAnimation:taunting restoreOriginalFrame:NO]];
        
        //tell the bear to run the taunting action
        [sprite runAction:taunt];
        
        [self addChild:sprite z:0];
            
        sprite = [CCSprite spriteWithFile:@"ground.png"];
        sprite.anchorPoint = CGPointZero;
        [self addChild:sprite z:10];
        
        targets = [[NSMutableSet alloc] init];
        enemies = [[NSMutableSet alloc] init];
        
        [self createTargets];
		
        
        CCSprite *arm = [CCSprite spriteWithFile:@"catapultarm.png"];
        [self addChild:arm z:-1];
        
        // Setting the properties of our definition
        b2BodyDef armBodyDef;
        armBodyDef.type = b2_dynamicBody;
        armBodyDef.linearDamping = 1;
        armBodyDef.angularDamping = 1;
        armBodyDef.position.Set(240.0f/PTM_RATIO,(FLOOR_HEIGHT+141.0f)/PTM_RATIO);
        armBodyDef.userData = (__bridge void*)arm; //this tells Box2D which sprite to update.
        
        //create a body with the definition we just created
        armBody = world->CreateBody(&armBodyDef); //the -> is C++ syntax
        
        //Create a fixture for the arm
        b2PolygonShape armBox;
        b2FixtureDef armBoxDef;
        armBoxDef.shape = &armBox;
        armBoxDef.density = 0.3F;
        armBox.SetAsBox(15.0f/PTM_RATIO, 140.0f/PTM_RATIO); //this is based on the dimensions of the arm which you can get from your image editing software of choice
        armFixture = armBody->CreateFixture(&armBoxDef);

        
        // Create a joint to fix the catapult to the floor.
        b2RevoluteJointDef armJointDef;
        armJointDef.Initialize(screenBorderBody, armBody, b2Vec2(230.0f/PTM_RATIO, (FLOOR_HEIGHT+50.0f)/PTM_RATIO));
        
        
        /*When creating the joint you have to specify 2 bodies and the hinge point. You might be thinking: “shouldn’t the catapult’s arm attach to the base?”. Well, in the real world, yes. But in Box2d not necessarily. You could do this but then you’d have to create another body for the base and add more complexity to the simulation.*/
        
        armJointDef.enableMotor = true; // the motor will fight against our motion, sort of like a spring
        armJointDef.enableLimit = true;
        armJointDef.motorSpeed  = -5; // this sets the motor to move the arm clockwise, so when you pull it back it springs forward
        armJointDef.lowerAngle  = CC_DEGREES_TO_RADIANS(9);
        armJointDef.upperAngle  = CC_DEGREES_TO_RADIANS(75);//these limit the range of motion of the catapult
        armJointDef.maxMotorTorque = 300; //this limits the speed at which the catapult can move
        armJoint = (b2RevoluteJoint*)world->CreateJoint(&armJointDef);
        
		
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"explo2.wav"];
        
        //schedules a call to the update method every frame
		[self scheduleUpdate];
        [self performSelector:@selector(resetGame) withObject:nil afterDelay:0.5f];
	}
    
	return self;
}

- (void)createTargets
{
    targets = [[NSMutableSet alloc] init];
    enemies = [[NSMutableSet alloc] init];
    
    [self createTarget:@"tallblock.png" atPosition:CGPointMake(708.0f, FLOOR_HEIGHT + 15.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"longblock.png" atPosition:CGPointMake(707.0f, FLOOR_HEIGHT + 60.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"tallblock.png" atPosition:CGPointMake(773.0f, FLOOR_HEIGHT + 15.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    
    [self createTarget:@"seal.png" atPosition:CGPointMake(725.0f, FLOOR_HEIGHT + 60.0f) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
    [self createTarget:@"seal.png" atPosition:CGPointMake(750.0f, FLOOR_HEIGHT + 60.0f) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
    
    [self createTarget:@"tallblock.png" atPosition:CGPointMake(854.0f, FLOOR_HEIGHT + 28.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"tallblock.png" atPosition:CGPointMake(854.0f, FLOOR_HEIGHT + 28.0f + 46.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"tallblock.png" atPosition:CGPointMake(854.0f, FLOOR_HEIGHT + 26.0f + 46.0f + 46.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
}


+(id) scene
{
    CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	GameLayer *layer = [GameLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

- (void)createTarget:(NSString*)imageName
          atPosition:(CGPoint)position
            rotation:(CGFloat)rotation
            isCircle:(BOOL)isCircle
            isStatic:(BOOL)isStatic
             isEnemy:(BOOL)isEnemy
{
    //seals are enemies, and since we create a custom Seal class,
    //we have to handle it differently
    CCSprite* sprite;
    if (isEnemy)
    {
        sprite = [[Seal alloc] initWithSealImage];
        [self addChild:sprite z:1];
    }
    else
    {
        sprite = [CCSprite spriteWithFile:imageName];
        [self addChild:sprite z:1];
    }
    
    b2BodyDef bodyDef;
    bodyDef.type = isStatic?b2_staticBody:b2_dynamicBody; //nested if statement
    bodyDef.position.Set((position.x+sprite.contentSize.width/2.0f)/PTM_RATIO,(position.y+sprite.contentSize.height/2.0f)/PTM_RATIO);
    bodyDef.angle = CC_DEGREES_TO_RADIANS(rotation);
    bodyDef.userData = (__bridge void*) sprite;
    b2Body *body = world->CreateBody(&bodyDef);
    
    b2FixtureDef boxDef;
    
    if (isCircle)
    {
        b2CircleShape circle;
        circle.m_radius = sprite.contentSize.width/2.0f/PTM_RATIO;
        boxDef.shape = &circle;
    }
    else
    {
        
        b2PolygonShape box;
        box.SetAsBox(sprite.contentSize.width/2.0f/PTM_RATIO,
                     sprite.contentSize.height/2.0f/PTM_RATIO);
        //contentSize is used to determine the dimensions of the sprite
        boxDef.shape = &box;
        
    }
    if (isEnemy)
        
    {
        boxDef.userData = (void*)1;
        [enemies addObject:[NSValue valueWithPointer:body]];
    }
    
    boxDef.density = 0.5f;
    body->CreateFixture(&boxDef);
    [targets addObject:[NSValue valueWithPointer:body]];
}

- (void)resetBullet
{
    if ([enemies count] == 0)
    {
        // game over
        // We'll do something here later
    }
    else if ([self attachBullet])
    {
        [self runAction:[CCMoveTo actionWithDuration:2.0f position:CGPointZero]];
    }
    else
    {
        // We can reset the whole scene here
        // Also, let's do this later
    }
}


//Create the bullets, add them to the list of bullets so they can be referred to later
- (void)createBullets: (int) count
{
    currentBullet = 0;
    CGFloat pos = 52.0f;
    
    if (count > 0)
    {
        // delta is the spacing between penguins
        // 52 is the position o the screen where we want the penguins to start appearing
        // 165 is the position on the screen where we want the penguins to stop appearing
        // 25 is the size of the penguin
        CGFloat delta = (count > 1)?((165.0f - 52.0f - 25.0f) / (count - 1)):0.0f;
        
        bullets = [[NSMutableArray alloc] initWithCapacity:count];
        for (int i=0; i<count; i++, pos+=delta)
        {
            // Create the bullet
            
            CCSprite *sprite = [CCSprite spriteWithFile:@"flyingpenguin.png"];
            [self addChild:sprite z:1];
            
            b2BodyDef bulletBodyDef;
            bulletBodyDef.type = b2_dynamicBody;
            bulletBodyDef.bullet = true; //this tells Box2D to check for collisions more often
            bulletBodyDef.position.Set(pos/PTM_RATIO,(FLOOR_HEIGHT+15.0f)/PTM_RATIO);
            bulletBodyDef.userData = (__bridge void*)sprite;
            b2Body *bullet = world->CreateBody(&bulletBodyDef);
            bullet->SetActive(false);
            
            b2CircleShape circle;
            circle.m_radius = 12.0/PTM_RATIO; //you can figure the dimensions out by looking at flyingpenguin.png in image editing software
            
            b2FixtureDef ballShapeDef;
            ballShapeDef.shape = &circle;
            ballShapeDef.density = 0.8f;
            ballShapeDef.restitution = 0.2f;
            ballShapeDef.friction = 0.99f;
            //try changing these and see what happens!
            bullet->CreateFixture(&ballShapeDef);
            
            [bullets addObject:[NSValue valueWithPointer:bullet]];
        }
    }
}

- (BOOL)attachBullet
{
    if (currentBullet < [bullets count])
    {
        bulletBody = (b2Body*)[[bullets objectAtIndex:currentBullet++] pointerValue];
        bulletBody->SetTransform(b2Vec2(240.0f/PTM_RATIO, (200.0f+FLOOR_HEIGHT)/PTM_RATIO), 0.0f);
        
        bulletBody->SetActive(true);
        
        b2WeldJointDef weldJointDef;
        weldJointDef.Initialize(bulletBody, armBody, b2Vec2(240.0f/PTM_RATIO,(200.0f+FLOOR_HEIGHT)/PTM_RATIO));
        
        weldJointDef.collideConnected = false;
        
        bulletJoint = (b2WeldJoint*)world->CreateJoint(&weldJointDef);
        return YES;
    }
    
    return NO;
}

//Check through all the bullets and blocks and see if they intersect
-(void) detectCollisions
{
    for(int i = 0; i < [bullets count]; i++)
    {
        for(int j = 0; j < [blocks count]; j++)
        {
            if([bullets count]>0)
            {
                NSInteger first = i;
                NSInteger second = j;
                block = [blocks objectAtIndex:second];
                projectile = [bullets objectAtIndex:first];
                
                firstrect = [projectile textureRect];
                secondrect = [block textureRect];
                //check if their x coordinates match
                if(projectile.position.x == block.position.x)
                {
                    //check if their y coordinates are within the height of the block
                    if(projectile.position.y < (block.position.y + 23.0f) && projectile.position.y > block.position.y - 23.0f)
                    {
                        [[SimpleAudioEngine sharedEngine] playEffect:@"explo2.wav"];
                        [self removeChild:block cleanup:YES];
                        [self removeChild:projectile cleanup:YES];
                        [blocks removeObjectAtIndex:second];
                        [bullets removeObjectAtIndex:first];
                        
                    }
                }
            }
            
        }
        
    }
}



-(void) dealloc
{
	delete world;
    
#ifndef KK_ARC_ENABLED
	[super dealloc];
#endif
}



-(void) update:(ccTime)delta
{
    
    //get all the bodies in the world
    for (b2Body* body = world->GetBodyList(); body != nil; body = body->GetNext())
    {
        //get the sprite associated with the body
        CCSprite* sprite = (__bridge CCSprite*)body->GetUserData();
        if (sprite != NULL)
        {
            // update the sprite's position to where their physics bodies are
            sprite.position = [self toPixels:body->GetPosition()];
            float angle = body->GetAngle();
            sprite.rotation = CC_RADIANS_TO_DEGREES(angle) * -1;
        }
    }
    
    //Check for inputs and create a bullet if there is a tap
    KKInput* input = [KKInput sharedInput];
    if(input.anyTouchBeganThisFrame) //this is when someone's finger first hits the screen
    {
        CGPoint location = input.anyTouchLocation;
        b2Vec2 locationWorld = b2Vec2(location.x/PTM_RATIO, location.y/PTM_RATIO);
        
        if (locationWorld.x < armBody->GetWorldCenter().x + 40.0/PTM_RATIO) //if we're touching the catapult area
        {
            b2MouseJointDef md;
            md.bodyA = screenBorderBody;
            md.bodyB = armBody;
            md.target = locationWorld;
            md.maxForce = 2000;
            //we create a mouse joint that can pull the catapult
            mouseJoint = (b2MouseJoint *)world->CreateJoint(&md);
        }
        
    }
    else if(input.anyTouchEndedThisFrame) // if they let go
    {
        if (mouseJoint != nil)
        {
            //destroying the mouse joint lets the catapult motor rotate it back to its original prosition
            world->DestroyJoint(mouseJoint);
            [self performSelector:@selector(resetBullet) withObject:nil afterDelay:5.0f];
            mouseJoint = nil;
        }
        [self createBullets:1];
    }
    else if(input.touchesAvailable) //if they are dragging the catapult
    {
        if (mouseJoint == nil) return;
        CGPoint location = input.anyTouchLocation;
        location = [[CCDirector sharedDirector] convertToGL:location];
        b2Vec2 locationWorld = b2Vec2(location.x/PTM_RATIO, location.y/PTM_RATIO);
        
        mouseJoint->SetTarget(locationWorld);
    }
    if (armJoint->GetJointAngle() >= CC_DEGREES_TO_RADIANS(20))
    {
        releasingArm = YES;
    }
    
    // Arm is being released.
    if (releasingArm && bulletJoint)
    {
        // Check if the arm reached the end so we can return the limits
        if (armJoint->GetJointAngle() <= CC_DEGREES_TO_RADIANS(10))
        {
            releasingArm = NO;
            
            // Destroy joint so the bullet will be free
            world->DestroyJoint(bulletJoint);
            bulletJoint = nil;
            
        }
    }
    
    float timeStep = 0.03f;
    int32 velocityIterations = 8;
    int32 positionIterations = 1;
    world->Step(timeStep, velocityIterations, positionIterations);
    
    ///******added
    // Check for impacts
//    std::set<b2Body*>::iterator pos;
//    for(pos = contactListener->contacts.begin();
//        pos != contactListener->contacts.end(); ++pos)
//    {
//        b2Body *body = *pos;
//        
//        CCNode *contactNode = (__bridge CCNode*)body->GetUserData();
//        [self removeChild:contactNode cleanup:YES];
//        world->DestroyBody(body);
//        
//        [targets removeObject:[NSValue valueWithPointer:body]];
//        [enemies removeObject:[NSValue valueWithPointer:body]];
//    }
    
    // remove everything from the set
//    contactListener->contacts.clear();
    
    for (b2Body* body = world->GetBodyList(); body != nil; body = body->GetNext())
    {
        //get the sprite associated with the body
        CCSprite* sprite = (__bridge CCSprite*)body->GetUserData();
        if (sprite != NULL && sprite.tag==2)
        {
            if ([sprite isKindOfClass:[Seal class]])
            {
                if( ((Seal*)sprite).health==1 )
                {
                    [self removeChild:sprite cleanup:NO];
                    world->DestroyBody(body);
                }
                else
                {
                    ((Seal*)sprite).health--;
                }
            }
            else
            {
                [self removeChild:sprite cleanup:NO];
                world->DestroyBody(body);
            }
        }
    }
    
    ///*****added
    
    //Bullet is moving.
    if (bulletBody && bulletJoint == nil)
    {
        b2Vec2 position = bulletBody->GetPosition();
        CGPoint myPosition = self.position;
    
        // Move the camera.
        if (position.x > 240.0 / PTM_RATIO)
        {
            myPosition.x = -MIN(480.0, position.x * PTM_RATIO - 240.0);
            self.position = myPosition;
        }
    }

    
}

- (void)resetGame
{
    [self createBullets:4];
    [self attachBullet];
    [self createTargets];
}


// convenience method to convert a b2Vec2 to a CGPoint
-(CGPoint) toPixels:(b2Vec2)vec
{
	return ccpMult(CGPointMake(vec.x, vec.y), PTM_RATIO);
}

-(void) enableBox2dDebugDrawing
{
	// Using John Wordsworth's Box2DDebugLayer class now
	// The advantage is that it draws the debug information over the normal cocos2d graphics,
	// so you'll still see the textures of each object.
	const BOOL useBox2DDebugLayer = YES;
    
	
	float debugDrawScaleFactor = 1.0f;
#if KK_PLATFORM_IOS
	debugDrawScaleFactor = [[CCDirector sharedDirector] contentScaleFactor];
#endif
	debugDrawScaleFactor *= PTM_RATIO;
    
	UInt32 debugDrawFlags = 0;
	debugDrawFlags += b2Draw::e_shapeBit;
	debugDrawFlags += b2Draw::e_jointBit;
	//debugDrawFlags += b2Draw::e_aabbBit;
	//debugDrawFlags += b2Draw::e_pairBit;
	//debugDrawFlags += b2Draw::e_centerOfMassBit;
    
	if (useBox2DDebugLayer)
	{
		Box2DDebugLayer* debugLayer = [Box2DDebugLayer debugLayerWithWorld:world
																  ptmRatio:PTM_RATIO
																	 flags:debugDrawFlags];
		[self addChild:debugLayer z:100];
	}
	else
	{
		debugDraw = new GLESDebugDraw(debugDrawScaleFactor);
		if (debugDraw)
		{
			debugDraw->SetFlags(debugDrawFlags);
			world->SetDebugDraw(debugDraw);
		}
	}
}


@end
