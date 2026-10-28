//
//  UVCFocusDevice.m
//
//  Implements the public CUVCControl API in terms of the vendored
//  UVCController/UVCControl/UVCValue classes (manual reference counting,
//  matching the style of the original uvc-util sources).
//

#import "CUVCControl.h"
#import "UVCController.h"

@interface UVCFocusDevice ()
@property (nonatomic, retain) UVCController *controller;
@end

@implementation UVCFocusDevice

+ (nullable instancetype)firstAvailableDevice {
    NSArray *controllers = [UVCController uvcControllers];
    if (controllers.count == 0) {
        return nil;
    }
    UVCFocusDevice *device = [[[self alloc] init] autorelease];
    device.controller = [controllers firstObject];
    return device;
}

- (void)dealloc {
    [_controller release];
    [super dealloc];
}

- (NSString *)deviceName {
    return [self.controller deviceName];
}

- (UVCControl *)autoFocusControl {
    return [self.controller controlWithName:UVCTerminalControlAutoFocus];
}

- (UVCControl *)focusAbsControl {
    return [self.controller controlWithName:UVCTerminalControlFocusAbsolute];
}

- (BOOL)supportsAutoFocus {
    return [self autoFocusControl] != nil;
}

- (BOOL)supportsFocusAbsolute {
    return [self focusAbsControl] != nil;
}

- (BOOL)autoFocusEnabled {
    UVCControl *control = [self autoFocusControl];
    if (!control || ![control readIntoCurrentValue]) {
        return NO;
    }
    return [[[control currentValue] stringValue] isEqualToString:@"true"];
}

- (BOOL)setAutoFocusEnabled:(BOOL)enabled {
    UVCControl *control = [self autoFocusControl];
    if (!control) {
        return NO;
    }
    const char *str = enabled ? "true" : "false";
    if (![control setCurrentValueFromCString:str flags:0]) {
        return NO;
    }
    return [control writeFromCurrentValue];
}

- (NSInteger)focusAbsoluteValue {
    UVCControl *control = [self focusAbsControl];
    if (!control || ![control readIntoCurrentValue]) {
        return 0;
    }
    return [[[control currentValue] stringValue] integerValue];
}

- (BOOL)setFocusAbsoluteValue:(NSInteger)value {
    UVCControl *control = [self focusAbsControl];
    if (!control) {
        return NO;
    }
    NSString *str = [NSString stringWithFormat:@"%ld", (long)value];
    if (![control setCurrentValueFromCString:[str UTF8String] flags:0]) {
        return NO;
    }
    return [control writeFromCurrentValue];
}

- (NSInteger)focusAbsoluteMinimum {
    UVCValue *v = [[self focusAbsControl] minimum];
    return v ? [[v stringValue] integerValue] : 0;
}

- (NSInteger)focusAbsoluteMaximum {
    UVCValue *v = [[self focusAbsControl] maximum];
    return v ? [[v stringValue] integerValue] : 250;
}

- (NSInteger)focusAbsoluteStepSize {
    UVCValue *v = [[self focusAbsControl] stepSize];
    return v ? [[v stringValue] integerValue] : 1;
}

@end
