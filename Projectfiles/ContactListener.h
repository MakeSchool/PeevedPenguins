/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

//#import "Box2D.h"
//
//class ContactListener : public b2ContactListener
//{
//private:
//	void BeginContact(b2Contact* contact);
//	void EndContact(b2Contact* contact);
//};

#import "Box2D.h"


//struct MyContact {
//    b2Fixture *fixtureA;
//    b2Fixture *fixtureB;
//    bool operator==(const MyContact& other) const
//    {
//        return (fixtureA == other.fixtureA) && (fixtureB == other.fixtureB);
//    }
//    };
//    
    class ContactListener : public b2ContactListener {
        
//    public:
////        std::vector<MyContact>_contacts;
//        std::set<b2Body*>contacts;
//        
//        ContactListener();
//        ~ContactListener();
        
        void BeginContact(b2Contact* contact);
        void EndContact(b2Contact* contact);
        void PreSolve(b2Contact* contact, const b2Manifold* oldManifold);
        void PostSolve(b2Contact* contact, const b2ContactImpulse* impulse);
        
    };