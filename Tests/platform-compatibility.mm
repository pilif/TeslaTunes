#import <Foundation/Foundation.h>
#import "SavedFolderDefaults.h"
#include <trefcounter.h>
#include <thread>
#include <vector>
#include <cstdio>
#include <cstdlib>

static void require(bool condition, const char *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}

// Exercise migration without touching the user's actual preferences.
@interface MemoryDefaults : NSUserDefaults
@property NSMutableDictionary *values;
@end
@implementation MemoryDefaults
- (instancetype)init {
    if ((self = [super init])) _values = [NSMutableDictionary dictionary];
    return self;
}
- (id)objectForKey:(NSString *)key { return self.values[key]; }
- (void)setObject:(id)value forKey:(NSString *)key { self.values[key] = value; }
@end

static NSData *legacyArchive(id value) {
    // Generate precisely the non-keyed format written by the old storyboard.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSArchiver archivedDataWithRootObject:value];
#pragma clang diagnostic pop
}

int main(void) {
    @autoreleasepool {
        NSURL *source = [NSURL fileURLWithPath:@"/tmp/Música source" isDirectory:YES];
        NSURL *destination = [NSURL fileURLWithPath:@"/Volumes/Test Drive" isDirectory:YES];
        MemoryDefaults *defaults = [MemoryDefaults new];
        NSData *oldSource = legacyArchive(source);
        [defaults setObject:oldSource forKey:@"sourcePathURL"];
        [defaults setObject:legacyArchive(destination) forKey:@"destinationPathURL"];
        MigrateSavedFolderDefaults(defaults);
        NSValueTransformer *secure = [NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName];
        require([[secure transformedValue:[defaults objectForKey:@"sourcePathURLSecure"]] isEqual:source], "source URL migration");
        require([[secure transformedValue:[defaults objectForKey:@"destinationPathURLSecure"]] isEqual:destination], "destination URL migration");
        require([[defaults objectForKey:@"sourcePathURL"] isEqual:oldSource], "original archive preserved");
        [defaults setObject:[secure reverseTransformedValue:destination] forKey:@"sourcePathURLSecure"];
        MigrateSavedFolderDefaults(defaults);
        require([[secure transformedValue:[defaults objectForKey:@"sourcePathURLSecure"]] isEqual:destination], "migration must not overwrite a newer selection");
        require([secure transformedValue:nil] == nil, "unset folder");

        MemoryDefaults *invalid = [MemoryDefaults new];
        [invalid setObject:[@"bad archive" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"sourcePathURL"];
        [invalid setObject:legacyArchive(@"not a URL") forKey:@"destinationPathURL"];
        MigrateSavedFolderDefaults(invalid);
        require([invalid objectForKey:@"sourcePathURLSecure"] == nil, "corrupt legacy data ignored");
        require([invalid objectForKey:@"destinationPathURLSecure"] == nil, "non-URL legacy data ignored");
        require([invalid objectForKey:@"sourcePathURL"] != nil, "invalid original retained");
        puts("PASS: saved-folder migration, secure binding round-trip, existing selections, invalid archives");
    }

    // The map/list counter is shared by concurrent conversion jobs. Keep one
    // reference alive while workers repeatedly acquire and release theirs.
    TagLib::RefCounterOld counter;
    std::vector<std::thread> workers;
    for (unsigned t = 0; t < 8; ++t) {
        workers.emplace_back([&counter] {
            for (unsigned i = 0; i < 100000; ++i) {
                counter.ref();
                require(!counter.deref(), "counter reached zero with a live reference");
            }
        });
    }
    for (auto &worker : workers) worker.join();
    require(counter.count() == 1, "reference count after concurrent use");
    require(counter.deref(), "last release");
    puts("PASS: TagLib atomic reference counting under concurrent use");
}
