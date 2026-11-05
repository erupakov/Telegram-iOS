#import <LegacyComponents/TGCameraInterfaceAssets.h>
#import <CoreText/CoreText.h>

#import "LegacyComponentsInternal.h"

static NSString *TGCameraEncodeText(NSString *string, int key)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < (int)[string length]; i++)
    {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

@implementation TGCameraInterfaceAssets

+ (UIColor *)normalColor
{
    return [UIColor whiteColor];
}

+ (UIColor *)accentColor
{
    return UIColorRGB(0xf8d74a);
}

+ (UIColor *)redColor
{
    return UIColorRGB(0xfe3b30);
}

+ (UIColor *)panelBackgroundColor
{
    return [UIColor blackColor];
}

+ (UIColor *)buttonColor
{
    return UIColorRGBA(0x393737, 0.6);
}

+ (UIColor *)transparentPanelBackgroundColor
{
    return [UIColor colorWithWhite:0.0f alpha:0.5];
}

+ (UIColor *)transparentOverlayBackgroundColor
{
    return [UIColor colorWithWhite:0.0f alpha:0.7];
}

// DIVO: вшитый шрифт SF Camera удалён из бандла (ITMS-91198), fontWithName: теперь возвращает nil.
// nil в литерале атрибутов (TGCameraModeControl) ронял приложение при открытии камеры — берём системный.
+ (UIFont *)regularFontOfSize:(CGFloat)size
{
    UIFont *font = [UIFont fontWithName:TGCameraEncodeText(@"TGDbnfsb.Sfhvmbs", -1) size:size];
    return font ?: [UIFont systemFontOfSize:size weight:UIFontWeightRegular];
}

+ (UIFont *)boldFontOfSize:(CGFloat)size
{
    UIFont *font = [UIFont fontWithName:TGCameraEncodeText(@"TGDbnfsb.Tfnjcpme", -1) size:size];
    return font ?: [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
}

@end
