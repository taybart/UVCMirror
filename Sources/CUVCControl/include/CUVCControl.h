//
//  CUVCControl.h
//
//  Minimal Swift-facing wrapper around UVCController/UVCControl/UVCValue,
//  exposing just the focus controls needed by the UVCMirror app.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UVCFocusDevice : NSObject

/// Locates the first UVC-compliant camera on the USB bus, or nil if none is found.
+ (nullable instancetype)firstAvailableDevice;

@property (nonatomic, readonly, copy) NSString *deviceName;

@property (nonatomic, readonly) BOOL supportsAutoFocus;
@property (nonatomic, readonly) BOOL supportsFocusAbsolute;

- (BOOL)autoFocusEnabled;
- (BOOL)setAutoFocusEnabled:(BOOL)enabled;

- (NSInteger)focusAbsoluteValue;
- (BOOL)setFocusAbsoluteValue:(NSInteger)value;
- (NSInteger)focusAbsoluteMinimum;
- (NSInteger)focusAbsoluteMaximum;
- (NSInteger)focusAbsoluteStepSize;

@end

NS_ASSUME_NONNULL_END
