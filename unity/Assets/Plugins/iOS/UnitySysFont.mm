/*
 * Copyright (c) 2012 Mario Freitas (imkira@gmail.com)
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#import <CoreGraphics/CoreGraphics.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

extern EAGLContext* _context;

#elif TARGET_OS_MAC
#import <ApplicationServices/ApplicationServices.h>
#include <OpenGL/gl.h>
#else
#error Unknown platform
#endif

#define UNITY_SYSFONT_UPDATE_QUEUE_CAPACITY 32

int nextPowerOfTwo(int n);

int nextPowerOfTwo(int n)
{
  --n;
  n |= n >> 1;
  n |= n >> 2;
  n |= n >> 4;
  n |= n >> 8;
  n |= n >> 16;
  ++n;
  return (n <= 0) ? 1 : n;
}

@interface UnitySysFontColor : NSObject
{
    @public NSRange range;
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    @public UIColor * color;
#elif TARGET_OS_MAC
    @public NSColor * color;
#endif
    
}
@end

@implementation UnitySysFontColor
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
-(id) initWithRange:(NSRange) _r color :(UIColor*)_color
#elif TARGET_OS_MAC
-(id) initWithRange:(NSRange) _r color :(NSColor*)_color
#endif

{
    range = _r;
    color = _color;
    return self;
}

@end

@interface UnitySysFontTextureUpdate : NSObject
{
  NSMutableString *text;
  NSMutableArray* colors;
  NSString *fontName;
  int fontSize;
  BOOL isBold;
  BOOL isItalic;
  int alignment;
  int maxWidthPixels;
  int maxHeightPixels;
  int textureID;

  BOOL ready;
  NSDictionary* dict;

  NSMutableAttributedString *attributedString;

  @public int textWidth;
  @public int textHeight;
  @public int textureWidth;
  @public int textureHeight;
}

- (NSNumber *)textureID;
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
- (UIFont *)font;
#elif TARGET_OS_MAC
- (NSFont *)font;
#endif
- (void)prepare;
- (void)render;
- (void)bindTextureWithFormat:(GLenum)format bitmapData:(void *)data;

@property (nonatomic, assign, getter=isReady) BOOL ready;
@end

@implementation UnitySysFontTextureUpdate

@synthesize ready;

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
+ (UIColor *)colorFromHexString:(NSString *)hexString
#elif TARGET_OS_MAC
+ (NSColor *)colorFromHexString:(NSString *)hexString
#endif
{    
    NSRange redRange={0,2};NSRange greenRange={2,2};NSRange blueRange={4,2};
    NSString *redString = [hexString substringWithRange:redRange];
    NSString *greenString = [hexString substringWithRange:greenRange];
    NSString *blueString = [hexString substringWithRange:blueRange];
    unsigned int red,green,blue;
    [[NSScanner scannerWithString:redString] scanHexInt:&red];
    [[NSScanner scannerWithString:greenString] scanHexInt:&green];
    [[NSScanner scannerWithString:blueString] scanHexInt:&blue];
    if(red > 255 || green > 255 || blue > 255 )
    {
        return nil;
    }
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    return [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:1.0];
#elif TARGET_OS_MAC
    return [NSColor colorWithDeviceRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:1.0];
#endif
    
}

- (id)initWithText:(const char *)_text fontName:(const char *)_fontName
fontSize:(int)_fontSize isBold:(BOOL)_isBold isItalic:(BOOL)_isItalic
alignment:(int)_alignment maxWidthPixels:(int)_maxWidthPixels
maxHeightPixels:(int)_maxHeightPixels textureID:(int)_textureID
{
  self = [super init];

  if (self != nil)
  {
    //text = [[NSMutableString stringWithUTF8String:((_text == NULL) ? "" : _text)] retain];
    fontName = [[NSString stringWithUTF8String:((_fontName == NULL) ? "" :
        _fontName)] retain];
    fontSize = _fontSize;
    isBold = _isBold;
    isItalic = _isItalic;
    alignment = _alignment;
    maxWidthPixels = _maxWidthPixels;
    maxHeightPixels = _maxHeightPixels;
    textureID = _textureID;
    ready = NO;
    [self proccessText:[NSString stringWithUTF8String:((_text == NULL) ? "" : _text)]];
    //[self proccessText:[NSString stringWithUTF8String:"test[ff0000]red[00ff00]green[0000ff]blue"]];
    [self prepare];
  }

  return self;
}

- (void)dealloc
{
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#elif TARGET_OS_MAC
  [attributedString release];
#endif
  
  [fontName release];
    if (text != nil)
    {
        [text release];
    }
    if(colors != nil)
    {
        [colors release];
    }
  [super dealloc];
}

- (NSNumber *)textureID
{
  return [NSNumber numberWithInt:textureID];
}

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
- (UIFont *)font
{
  UIFont *font = nil;
  if (fontSize <= 0)
  {
    fontSize = (int)[UIFont systemFontSize];
  }

  if ([fontName length] > (NSUInteger)0)
  {
    font = [UIFont fontWithName:fontName size:fontSize];
  }
  
  if (font == nil)
  {
    if (isBold == YES)
    {
      font = [UIFont boldSystemFontOfSize:fontSize];
    }
    else if (isItalic == YES)
    {
      font = [UIFont italicSystemFontOfSize:fontSize];
    }
    else
    {
      font = [UIFont systemFontOfSize:fontSize];
    }
  }
  return font;
}
#elif TARGET_OS_MAC
- (NSFont *)font
{
  NSFont *font = nil;

  if (fontSize <= 0)
  {
    fontSize = (int)[NSFont systemFontSize];
  }

  if ([fontName length] > (NSUInteger)0)
  {
    font = [NSFont fontWithName:fontName size:fontSize];
  }

  if (font == nil)
  {
    if (isBold == YES)
    {
      font = [NSFont boldSystemFontOfSize:fontSize];
    }
    else
    {
      font = [NSFont systemFontOfSize:fontSize];
    }
  }

  return font;
}
#endif

- (void) proccessText : (NSString*) _text
{
    text = [[NSMutableString alloc] initWithCapacity:1000];
    colors = [[NSMutableArray alloc] initWithCapacity:1];
    NSInteger pre = 0;
    NSInteger cur = 0;
    
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    UIColor* curColor = [UIColor whiteColor];
    UIColor* color = nil;
#elif TARGET_OS_MAC
    NSColor* curColor = [NSColor whiteColor];
    NSColor* color = nil;
#endif
    for (NSInteger i = 0; i < _text.length;)
    {
        UniChar ch = [_text characterAtIndex:i];
        if (ch == '[' && _text.length > i + 7 && [_text characterAtIndex:i+7] == ']')
        {
            NSString* c = [_text substringWithRange:NSMakeRange(i+1, 6)];
            //NSLog(@"Color %@",c);
            if(c.length == 6)
            {
                color = [UnitySysFontTextureUpdate colorFromHexString:c];
                if (color != nil)
                {
                    
                    UnitySysFontColor* sysColor = [[UnitySysFontColor alloc] initWithRange:NSMakeRange(pre, cur-pre) color:curColor];
                    [colors addObject:sysColor];
                    pre = cur;
                    curColor = color;
                    i += 8;
                    continue;
                }
            }
        }
        [text appendFormat:@"%C",ch];
        i++;
        cur++;
    }
    UnitySysFontColor* sysColor = [[UnitySysFontColor alloc] initWithRange:NSMakeRange(pre, cur-pre) color:curColor];
    [colors addObject:sysColor];
    //NSLog(@"%@",text);
}

- (void)prepare
{
  CGSize maxSize = CGSizeMake(maxWidthPixels, maxHeightPixels);
  CGSize boundsSize;

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    boundsSize = [text sizeWithFont:[self font] constrainedToSize:maxSize lineBreakMode:UILineBreakModeWordWrap];
    NSTextAlignment _alignment = NSTextAlignmentLeft;
    
    if (alignment == 1)
    {
        _alignment = NSTextAlignmentCenter;
    }
    else if (alignment == 2)
    {
        _alignment = NSTextAlignmentRight;
    }
    
    NSMutableParagraphStyle *parStyle = [[NSMutableParagraphStyle alloc] init];
    [parStyle setAlignment:_alignment];
    [parStyle setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [self font], NSFontAttributeName,
                                [UIColor whiteColor].CGColor, NSForegroundColorAttributeName,
                                [UIColor clearColor].CGColor, NSBackgroundColorAttributeName,
                                parStyle, NSParagraphStyleAttributeName, nil];
    
    attributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
    for (NSInteger i = 0; i < [colors count]; i++)
    {
        UnitySysFontColor* color = (UnitySysFontColor*)[colors objectAtIndex:i];
        [attributedString addAttribute:NSForegroundColorAttributeName value:color->color range:color->range];
    }
    CGRect paragraphRect = [attributedString boundingRectWithSize:maxSize
                                 options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                 context:nil];
    boundsSize = paragraphRect.size;
#elif TARGET_OS_MAC

  NSTextAlignment _alignment = NSLeftTextAlignment;

  if (alignment == 1)
  {
    _alignment = NSCenterTextAlignment;
  }
  else if (alignment == 2)
  {
    _alignment = NSRightTextAlignment;
  }

  NSMutableParagraphStyle *parStyle = [[NSMutableParagraphStyle alloc] init];
  [parStyle setAlignment:_alignment];
  [parStyle setLineBreakMode:NSLineBreakByWordWrapping];

  NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
    [self font], NSFontAttributeName,
    [NSColor whiteColor], NSForegroundColorAttributeName,
    [NSColor clearColor], NSBackgroundColorAttributeName,
    parStyle, NSParagraphStyleAttributeName, nil];

    attributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
    for (NSInteger i = 0; i < [colors count]; i++)
    {
        UnitySysFontColor* color = (UnitySysFontColor*)[colors objectAtIndex:i];
        [attributedString addAttribute:NSForegroundColorAttributeName value:color->color range:color->range];
    }

  boundsSize = NSSizeToCGSize([attributedString
      boundingRectWithSize:NSSizeFromCGSize(maxSize)
      options:NSStringDrawingUsesLineFragmentOrigin].size);
#endif

  textWidth = (int)ceilf(boundsSize.width);
  if (textWidth > maxWidthPixels)
  {
    textWidth = maxWidthPixels;
  }
  else if (textWidth <= 0)
  {
    textWidth = 1;
  }
  textHeight = (int)ceilf(boundsSize.height);
  if (textHeight > maxHeightPixels)
  {
    textHeight = maxHeightPixels;
  }
  else if (textHeight <= 0)
  {
    textHeight = 1;
  }

  textureWidth = nextPowerOfTwo(textWidth);
  textureHeight = nextPowerOfTwo(textHeight);
    
    printf("texture id : %d font size : %d text width : %d text height : %d texture width : %d texture height : %d",textureID ,fontSize,textWidth,textHeight,textureWidth,textureHeight);
}


#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
- (NSAttributedString*) attributedString
{
    NSTextAlignment _alignment = NSTextAlignmentLeft;
    
    if (alignment == 1)
    {
        _alignment = NSTextAlignmentCenter;
    }
    else if (alignment == 2)
    {
        _alignment = NSTextAlignmentRight;
    }
    
    NSMutableParagraphStyle *parStyle = [[NSMutableParagraphStyle alloc] init];
    [parStyle setAlignment:_alignment];
    [parStyle setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [self font], NSFontAttributeName,
                                [UIColor whiteColor].CGColor, NSForegroundColorAttributeName,
                                [UIColor clearColor].CGColor, NSBackgroundColorAttributeName,
                                parStyle, NSParagraphStyleAttributeName, nil];
    
    NSMutableAttributedString* tmpString = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
    NSLog(@"count %d",[colors count]);
    for (NSInteger i = 0; i < [colors count]; i++)
    {
        UnitySysFontColor* color = (UnitySysFontColor*)[colors objectAtIndex:i];
        [tmpString addAttribute:NSForegroundColorAttributeName value:color->color range:color->range];
    }
    
    return tmpString;
}

- (void)render
{
  GLubyte *bitmapData = (GLubyte *)malloc(textureHeight*textureWidth*4);//calloc(textureHeight*textureWidth,4);
    memset(bitmapData, 0, textureHeight*textureWidth*4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(bitmapData, textureWidth,
      textureHeight, 8, textureWidth*4, colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    
    CGColorSpaceRelease(colorSpace);
    
  if (context == NULL)
  {
    free(bitmapData);
    return;
  }

  UIGraphicsPushContext(context);
    //CGSize maxSize = CGSizeMake(maxWidthPixels, maxHeightPixels);
    //[attributedString boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin context:context];
    
    CGRect drawRect = CGRectMake(0.f, (float)(textureHeight - textHeight),
                                 textWidth, textHeight);
  UITextAlignment _alignment = UITextAlignmentLeft;

  if (alignment == 1)
  {
    _alignment = UITextAlignmentCenter;
  }
  else if (alignment == 2)
  {
    _alignment = UITextAlignmentRight;
  }
    
    //[[UIColor blackColor] setFill];
    //CGContextFillRect(context, CGRectMake(0.f, 0.f,textureWidth, textureHeight));
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0,  textureHeight - textHeight);
    CGContextConcatCTM(context,transform);
    CATextLayer* layer = [CATextLayer layer];
    layer.string = attributedString;
    layer.frame = drawRect;
    [layer drawInContext:context];
    //[attributedString drawInRect:drawRect];
    

  UIGraphicsPopContext();
  [self bindTextureWithFormat:GL_RGBA bitmapData:bitmapData];

    CGContextRelease(context);
  free(bitmapData);
}
#elif TARGET_OS_MAC
- (void)render
{
//  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
//    initWithBitmapDataPlanes:NULL pixelsWide:textureWidth
//    pixelsHigh:textureHeight bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
//    isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:NSAlphaFirstBitmapFormat
//    bytesPerRow:textureWidth*4 bitsPerPixel:32];
    
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:textureWidth
                                             pixelsHigh:textureHeight bitsPerSample:8 samplesPerPixel:4
                                               hasAlpha:YES isPlanar:NO colorSpaceName:@"NSDeviceRGBColorSpace"
                                            bytesPerRow:0 bitsPerPixel:0] autorelease];

  if (bitmap == nil)
  {
    return;
  }
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
  
  [NSGraphicsContext setCurrentContext:context];

    {
//        CIContext *ctx = [[NSGraphicsContext currentContext] CIContext];
//        [ctx ]
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:0.f yBy:textureHeight];
        [transform scaleXBy:1.f yBy:-1.f];
        [transform concat];
        
        NSRect textureRect = NSMakeRect(0.f, 0.f, textureWidth, textureHeight);
        NSRect drawRect = NSMakeRect(0.f, 0.f, textWidth, textHeight);
        
        [[NSColor clearColor] setFill];
        NSRectFill(textureRect);
        
        //[[NSColor whiteColor] set];
        [attributedString drawWithRect:drawRect
                               options:NSStringDrawingUsesLineFragmentOrigin];
        //transform = [NSAffineTransform transform];
        //[transform set];
    }
    
  [NSGraphicsContext restoreGraphicsState];
  

  [self bindTextureWithFormat:GL_RGBA bitmapData:[bitmap bitmapData]];

    //NSData *data = [bitmap representationUsingType: NSPNGFileType properties: nil];
    //[data writeToFile: @"/Users/mac/tmp/image.png" atomically: NO];
    
  //[bitmap release];
}
#endif

- (void)bindTextureWithFormat:(GLenum)format bitmapData:(void *)data
{
  glBindTexture(GL_TEXTURE_2D, textureID);
  //glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, textureWidth, textureHeight, 0,GL_RGBA, GL_UNSIGNED_BYTE, data);
//glTexSubImage2D(GL_TEXTURE_2D, 0, GL_RGBA, textureWidth, textureHeight, 0,format, GL_UNSIGNED_BYTE, data);
}
@end

@interface UnitySysFontTextureManager : NSObject
{
  NSMutableDictionary *updateQueue;
}

+ (UnitySysFontTextureManager *)sharedInstance;
- (id)initWithCapacity:(NSUInteger)numItems;
- (UnitySysFontTextureUpdate *)updateHavingTextureID:(int)textureID;
- (void)queueUpdate:(UnitySysFontTextureUpdate *)update;
- (void)dequeueUpdate:(NSNumber *)textureID;
@end

@implementation UnitySysFontTextureManager 
static UnitySysFontTextureManager *sharedInstance;

+ (void)initialize
{
  static BOOL initialized = NO;

  if (!initialized)
  {
    initialized = YES;
    sharedInstance = [[UnitySysFontTextureManager alloc]
      initWithCapacity:UNITY_SYSFONT_UPDATE_QUEUE_CAPACITY];
  }
}

+ (UnitySysFontTextureManager *)sharedInstance
{
  return sharedInstance;
}

- (id)initWithCapacity:(NSUInteger)numItems
{
  self = [super init];

  if (self != nil)
  {
    updateQueue = [[NSMutableDictionary alloc] initWithCapacity:numItems];
  }

  return self;
}

- (void)dealloc
{
  [updateQueue release];
  [super dealloc];
}

- (UnitySysFontTextureUpdate *)updateHavingTextureID:(int)textureID
{
  return [updateQueue objectForKey:[NSNumber numberWithInt:textureID]];
}

- (void)queueUpdate:(UnitySysFontTextureUpdate *)update
{
  NSNumber *textureID = [update textureID];
  [self dequeueUpdate:textureID];
  [updateQueue setObject:update forKey:textureID];
}

- (void)dequeueUpdate:(NSNumber *)textureID
{
  UnitySysFontTextureUpdate *existingUpdate;
  existingUpdate = [updateQueue objectForKey:textureID];
  if (existingUpdate != nil)
  {
    [updateQueue removeObjectForKey:textureID];
    [existingUpdate release];
  }
}

- (void)processQueue
{
  if ([updateQueue count] > (NSUInteger)0)
  {
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    EAGLContext *oldContext = [EAGLContext currentContext];
    // change to Unity's default OpenGL context
    if (oldContext != _context)
    {
      [EAGLContext setCurrentContext:_context];
    }
#endif
    for (NSNumber *textureID in [updateQueue allKeys])
    {
      UnitySysFontTextureUpdate *update = [updateQueue objectForKey:textureID];
      if ([update isReady])
      {
        [update render];
        [updateQueue removeObjectForKey:textureID];
        [update release];
#if TARGET_OS_MAC
          break;
#endif
      }
    }
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    // revert to non-default OpenGL context?
    if (oldContext != _context)
    {
      [EAGLContext setCurrentContext:oldContext];
    }
#endif
  }
}
@end

extern "C"
{
  void _SysFontQueueTexture(const char *text, const char *fontName,
      int fontSize, BOOL isBold, BOOL isItalic, int alignment,
      int maxWidthPixels, int maxHeightPixels, int textureID);

  int _SysFontGetTextureWidth(int textureID);

  int _SysFontGetTextureHeight(int textureID);

  int _SysFontGetTextWidth(int textureID);

  int _SysFontGetTextHeight(int textureID);

  void _SysFontUpdateQueuedTexture(int textureID);

  void _SysFontRender();

  void _SysFontDequeueTexture(int textureID);

  void UnityRenderEvent(int eventID);
}

void _SysFontQueueTexture(const char *text, const char *fontName,
    int fontSize, BOOL isBold, BOOL isItalic, int alignment,
    int maxWidthPixels, int maxHeightPixels, int textureID)
{
  UnitySysFontTextureManager *instance;
  UnitySysFontTextureUpdate *update;

  update = [[UnitySysFontTextureUpdate alloc] initWithText:text
    fontName:fontName fontSize:fontSize isBold:isBold isItalic:isItalic
    alignment:alignment maxWidthPixels:maxWidthPixels
    maxHeightPixels:maxHeightPixels textureID:textureID];

  instance = [UnitySysFontTextureManager sharedInstance];
  @synchronized(instance)
  {
    [instance queueUpdate:update];
  }
}

int _SysFontGetTextureWidth(int textureID)
{
  UnitySysFontTextureManager *instance;
  UnitySysFontTextureUpdate *update;
  instance = [UnitySysFontTextureManager sharedInstance];
  @synchronized(instance)
  {
    update = [instance updateHavingTextureID:textureID];
    if (update == nil)
    {
      return -1;
    }
    return update->textureWidth;
  }
}

int _SysFontGetTextureHeight(int textureID)
{
  UnitySysFontTextureManager *instance;
  UnitySysFontTextureUpdate *update;
  instance = [UnitySysFontTextureManager sharedInstance];
  @synchronized(instance)
  {
    update = [instance updateHavingTextureID:textureID];
    if (update == nil)
    {
      return -1;
    }
    return update->textureHeight;
  }
}

int _SysFontGetTextWidth(int textureID)
{
  UnitySysFontTextureManager *instance;
  UnitySysFontTextureUpdate *update;
  instance = [UnitySysFontTextureManager sharedInstance];
  @synchronized(instance)
  {
    update = [instance updateHavingTextureID:textureID];
    if (update == nil)
    {
      return -1;
    }
    return update->textWidth;
  }
}

int _SysFontGetTextHeight(int textureID)
{
  UnitySysFontTextureManager *instance;
  UnitySysFontTextureUpdate *update;
  instance = [UnitySysFontTextureManager sharedInstance];
  @synchronized(instance)
  {
    update = [instance updateHavingTextureID:textureID];
    if (update == nil)
    {
      return -1;
    }
    return update->textHeight;
  }
}

void _SysFontUpdateQueuedTexture(int textureID)
{
  UnitySysFontTextureManager *instance;
  UnitySysFontTextureUpdate *update;
  instance = [UnitySysFontTextureManager sharedInstance];
  @synchronized(instance)
  {
    update = [instance updateHavingTextureID:textureID];
    if (update != nil)
    {
      [update setReady:YES];
    }
  }
}

void _SysFontRender()
{
  UnitySysFontTextureManager *instance;
  instance = [UnitySysFontTextureManager sharedInstance];
  @synchronized(instance)
  {
    [instance processQueue];
  }
}

void _SysFontDequeueTexture(int textureID)
{
  UnitySysFontTextureManager *instance;
  instance = [UnitySysFontTextureManager sharedInstance];
  @synchronized(instance)
  {
    [instance dequeueUpdate:[NSNumber numberWithInt:textureID]];
  }
}

void UnityRenderEvent(int eventID)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  _SysFontRender();
  [pool drain];
}
