//
//  main.m
//  TeslaTunes
//
//  Created by Rob Arnold on 1/24/15.
//  Copyright (c) 2015 Loci Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SavedFolderDefaults.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        MigrateSavedFolderDefaults([NSUserDefaults standardUserDefaults]);
    }
    return NSApplicationMain(argc, argv);
}
