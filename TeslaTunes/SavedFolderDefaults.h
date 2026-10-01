#pragma once
#import <Foundation/Foundation.h>

// Upgrade the original non-keyed folder URL archives before loading bindings.
FOUNDATION_EXPORT void MigrateSavedFolderDefaults(NSUserDefaults *defaults);
