#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "HomeAvatarLogo" asset catalog image resource.
static NSString * const ACImageNameHomeAvatarLogo AC_SWIFT_PRIVATE = @"HomeAvatarLogo";

#undef AC_SWIFT_PRIVATE
