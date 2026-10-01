#import "SavedFolderDefaults.h"

void MigrateSavedFolderDefaults(NSUserDefaults *defaults) {
    for (NSString *legacyKey in @[@"sourcePathURL", @"destinationPathURL"]) {
        NSString *secureKey = [legacyKey stringByAppendingString:@"Secure"];
        if ([defaults objectForKey:secureKey] != nil) continue;
        NSData *legacyData = [defaults objectForKey:legacyKey];
        if (![legacyData isKindOfClass:[NSData class]]) continue;

        @try {
            // NSUnarchiveFromData wrote non-keyed NSArchiver data. The modern
            // secure unarchiver cannot read that format. Keep this deprecated
            // reader only for migration of our two existing local preferences;
            // all subsequent binding reads/writes use secure keyed archives.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            id value = [NSUnarchiver unarchiveObjectWithData:legacyData];
#pragma clang diagnostic pop
            if (![value isKindOfClass:[NSURL class]] || ![value isFileURL]) continue;
            NSError *error = nil;
            NSData *secureData = [NSKeyedArchiver archivedDataWithRootObject:value
                                                     requiringSecureCoding:YES error:&error];
            if (secureData) {
                [defaults setObject:secureData forKey:secureKey];
            } else {
                NSLog(@"Could not migrate saved folder %@: %@", legacyKey, error);
            }
        } @catch (NSException *exception) {
            // Preserve the original preference, but leave the new binding empty
            // so a damaged old archive cannot prevent the app from launching.
            NSLog(@"Could not migrate saved folder %@: %@", legacyKey, exception.name);
        }
    }
}
