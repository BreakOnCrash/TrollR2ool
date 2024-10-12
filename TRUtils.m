#import "TRUtils.h"

NSUInteger iconFormat(void) {
    return (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) ? 8 : 10;
}

UIImage *applicationIconImageForBundleIdentifier(NSString *bundleID) {
    UIImage *iconImage =
        [UIImage _applicationIconImageForBundleIdentifier:bundleID
                                                   format:iconFormat()
                                                    scale:[UIScreen mainScreen].scale];

    // 检查是否成功获取图标
    if (iconImage) {
        // 获取原始图片尺寸
        CGSize originalSize = iconImage.size;
        // 计算缩小后的尺寸，等比例缩小为原尺寸的一半
        CGSize targetSize = CGSizeMake(originalSize.width / 2.0, originalSize.height / 2.0);
        // 开始图形上下文，使用目标尺寸
        UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
        // 在目标尺寸的矩形区域中绘制缩小的图标
        [iconImage drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
        // 从图形上下文中获取缩小后的图标
        UIImage *resizedIcon = UIGraphicsGetImageFromCurrentImageContext();
        // 结束图形上下文
        UIGraphicsEndImageContext();
        return resizedIcon;
    }

    return nil;
}
