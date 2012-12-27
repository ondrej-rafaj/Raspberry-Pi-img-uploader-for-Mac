//
//  NSString+StringTools.h
//  Raspberry Pi img uploader
//
//  Created by Ondrej Rafaj on 26/12/2012.
//  Copyright (c) 2012 Fuerte Innovations. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (StringTools)

- (BOOL)containsString:(NSString *)string;
- (BOOL)containsString:(NSString *)string options:(NSStringCompareOptions) options;


@end
