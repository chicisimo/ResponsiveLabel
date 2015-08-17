//
//  ResponsiveLabel.m
//  ResponsiveLabel
//
//  Created by hsusmita on 13/03/15.
//  Copyright (c) 2015 hsusmita.com. All rights reserved.
//

#import "ResponsiveLabel.h"
#import "NSAttributedString+Processing.h"
#import "InlineTextAttachment.h"

static NSString *kRegexStringForHashTag = @"(?<!\\w)#([\\w\\_]+)?";
static NSString *kRegexStringForUserHandle = @"(?<!\\w)@([\\w\\_]+)?";
static NSString *kRegexFormatForSearchWord = @"(%@)";

@interface ResponsiveLabel ()

@property (nonatomic, retain) NSLayoutManager *layoutManager;
@property (nonatomic, retain) NSTextContainer *textContainer;
@property (nonatomic, retain) NSTextStorage *textStorage;

@property (nonatomic, strong) NSMutableDictionary *patternDescriptorDictionary;
@property (nonatomic, strong) NSAttributedString *attributedTruncationToken;
@property (nonatomic, strong) NSAttributedString *currentAttributedString;
@property (nonatomic, assign) NSRange selectedRange;

@end

@implementation ResponsiveLabel

#pragma mark - Initializers

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
      [self configureForGestures];
      self.patternDescriptorDictionary = [NSMutableDictionary new];
      self.selectedRange = NSMakeRange(NSNotFound, 0);
    }
    return self;
  }

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self configureForGestures];
    self.patternDescriptorDictionary = [NSMutableDictionary new];
    self.selectedRange = NSMakeRange(NSNotFound, 0);
  }
  return self;
}

- (void)awakeFromNib {
  [super awakeFromNib];
  [self initialTextConfiguration];
}


#pragma mark - Custom Getters

- (NSTextStorage *)textStorage {
  if (!_textStorage) {
    [_textStorage removeLayoutManager:_layoutManager];
    _textStorage = [[NSTextStorage alloc] init];
    [_textStorage addLayoutManager:self.layoutManager];
    [self.layoutManager setTextStorage:_textStorage];
  }
  return _textStorage;
}

- (NSTextContainer *)textContainer {
  if (!_textContainer) {
    _textContainer = [[NSTextContainer alloc] init];
    _textContainer.lineFragmentPadding = 0;
    _textContainer.maximumNumberOfLines = self.numberOfLines;
    _textContainer.lineBreakMode = self.lineBreakMode;
    _textContainer.widthTracksTextView = YES;
    _textContainer.size = self.frame.size;
    [_textContainer setLayoutManager:self.layoutManager];
  }
  return _textContainer;
}

- (NSLayoutManager *)layoutManager {
  if (!_layoutManager) {
    _layoutManager = [[NSLayoutManager alloc] init];
    [_layoutManager addTextContainer:self.textContainer];
  }
  
  return _layoutManager;
}

- (NSString *)truncationToken {
  return self.attributedTruncationToken.string;
}

#pragma mark - Custom Setters

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.textContainer.size = self.bounds.size;

}

//- (CGSize)intrinsicContentSize
//{
//  CGSize s = [super intrinsicContentSize];
//  
//  if (self.numberOfLines == 0) {
//    // found out that sometimes intrinsicContentSize is 1pt too short!
//    s.height += 1;
//  }
//  
//  return s;
//}

- (void)setFrame:(CGRect)frame {
  [super setFrame:frame];
  [self updateTextContainerSize:frame.size];
}

- (void)setBounds:(CGRect)bounds {
  [super setBounds:bounds];
  [self updateTextContainerSize:bounds.size];
}

- (void)setPreferredMaxLayoutWidth:(CGFloat)preferredMaxLayoutWidth {
  [super setPreferredMaxLayoutWidth:preferredMaxLayoutWidth];
  [self updateTextContainerSize:self.bounds.size];
}

- (void)setText:(NSString *)text {
  [super setText:text];
  NSAttributedString *attributedText =[[NSAttributedString alloc]initWithString:text
                                                                     attributes:[self attributesFromProperties]];
  [self updateTextStorage:attributedText];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
  [super setAttributedText:attributedText];
  [self updateTextStorage:attributedText];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines {
  [super setNumberOfLines:numberOfLines];
  if (numberOfLines != _textContainer.maximumNumberOfLines) {
    _textContainer.maximumNumberOfLines = numberOfLines;
    [self layoutIfNeeded];
    [self initialTextConfiguration];
  }
}

- (void)setCustomTruncationEnabled:(BOOL)customTruncationEnabled {
  _customTruncationEnabled = customTruncationEnabled;
  [self layoutIfNeeded];
//  [self shouldAppendTruncationToken] ? [self appendTokenIfNeeded] : [self removeTokenIfPresent];
}

- (void)setTruncationToken:(NSString *)truncationToken {
  self.attributedTruncationToken = [[NSAttributedString alloc]initWithString:truncationToken
                                                                  attributes:[self attributesFromProperties]];
  if ([self shouldAppendTruncationToken] && self.numberOfLines > 0) {
    [self appendTokenIfNeeded];
  }
}

#pragma mark - Drawing

- (void)drawTextInRect:(CGRect)rect {
  // Don't call super implementation. Might want to uncomment this out when
  // debugging layout and rendering problems.
//   [super drawTextInRect:rect];
  
  // Calculate the offset of the text in the view
  CGPoint textOffset;
  NSRange glyphRange = [_layoutManager glyphRangeForTextContainer:_textContainer];
  textOffset = [self textOffsetForGlyphRange:glyphRange];
  
//  // Drawing code
//  [_layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:textOffset];
//  [_layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:textOffset];
  NSLog(@"Text Drawn");
//  [self appendTokenIfNeeded];
  if ([self shouldAppendTruncationToken] && ![self truncationTokenAppended]) {
    if ([self.textStorage isNewLinePresent]) {
      //Append token string at the end of last visible line
      [self.textStorage replaceCharactersInRange:[self rangeForTokenInsertionForStringWithNewLine]
                            withAttributedString:self.attributedTruncationToken];
    }
    
    //Check for truncation range and append truncation token if required
    NSRange tokenRange =[self rangeForTokenInsertion];
    NSLog(@"token range = %@",NSStringFromRange(tokenRange));
    if (tokenRange.location != NSNotFound) {
      [self.textStorage replaceCharactersInRange:tokenRange withAttributedString:self.attributedTruncationToken];
//      [self redrawTextForRange:NSMakeRange(0, self.textStorage.length)];
    }
    
    //Apply attributes if truncation token appended
    NSRange truncationRange = [self rangeOfTruncationToken];
    if (truncationRange.location != NSNotFound) {
//      [self removeAttributeForTruncatedRange];
      
      //Apply attributes to the truncation token
      NSString *key = [NSString stringWithFormat:kRegexFormatForSearchWord,self.attributedTruncationToken.string];
      PatternDescriptor *descriptor = [self.patternDescriptorDictionary objectForKey:key];
      if (descriptor) {
        [self.textStorage addAttributes:descriptor.patternAttributes range:truncationRange];
      }
    }
  }
 glyphRange = [_layoutManager glyphRangeForTextContainer:_textContainer];
  textOffset = [self textOffsetForGlyphRange:glyphRange];
  
  // Drawing code
  [_layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:textOffset];
  [_layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:textOffset];

}

/**
 This method calculates text offset to draw the given glyph range such that text is center aligned veritically
 @param glyphRange : NSRange
 @return CGPoint : The text offset
 
 */
- (CGPoint)textOffsetForGlyphRange:(NSRange)glyphRange {
  CGPoint textOffset = CGPointZero;
  
  CGRect textBounds = [self.layoutManager boundingRectForGlyphRange:glyphRange
                                                    inTextContainer:self.textContainer];
  CGFloat paddingHeight = (self.bounds.size.height - textBounds.size.height) / 2.0f;
  if (paddingHeight > 0)
    textOffset.y = paddingHeight;
  
  return textOffset;
}

/**
 Convenience method to draw text for a given range
 @param range : NSRange
 */

- (void)redrawTextForRange:(NSRange)range {
  NSRange glyphRange = NSMakeRange(NSNotFound, 0);
  [self.layoutManager characterRangeForGlyphRange:range actualGlyphRange:&glyphRange];
  CGRect rect = [self.layoutManager boundingRectForGlyphRange:glyphRange
                                              inTextContainer:self.textContainer];
  NSRange totalGlyphRange = [self.layoutManager
                             glyphRangeForTextContainer:self.textContainer];
  CGPoint point = [self textOffsetForGlyphRange:totalGlyphRange];
  rect.origin.y += point.y;
  [self setNeedsDisplayInRect:rect];
}

#pragma mark - Override UILabel Methods

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines {
  CGRect requiredRect = [self rectFittingTextForContainerSize:bounds.size
                                              forNumberOfLine:numberOfLines];
  self.textContainer.size = requiredRect.size;
  NSLog(@"calculated container size = %f x %f",requiredRect.size.width,requiredRect.size.height);
  return requiredRect;
}

- (CGRect)rectFittingTextForContainerSize:(CGSize)size
                          forNumberOfLine:(NSInteger)numberOfLines {
  self.textContainer.size = size;
  self.textContainer.maximumNumberOfLines = numberOfLines;
  
  NSRange glyphRange = [self.layoutManager
                        glyphRangeForTextContainer:self.textContainer];
  CGRect textBounds = [self.layoutManager boundingRectForGlyphRange:glyphRange
                                                    inTextContainer:self.textContainer];
  NSInteger totalLines = textBounds.size.height / self.font.lineHeight;
  
  if (numberOfLines > 0 && (numberOfLines < totalLines)) {
    textBounds.size.height -= (totalLines - numberOfLines) * self.font.lineHeight;
  }else if (numberOfLines > 0 && (numberOfLines > totalLines)) {
    textBounds.size.height += (numberOfLines - totalLines) * self.font.lineHeight;
  }
  NSLog(@"initial size = %f x %f",size.width,size.height);
  NSLog(@"number of lines = %ld",numberOfLines);
  NSLog(@"text bounds = %f x %f",textBounds.size.width,textBounds.size.height);
  NSLog(@"total lines = %ld",totalLines);
  textBounds.size.width = ceilf(textBounds.size.width);
  textBounds.size.height = ceilf(textBounds.size.height);
  return textBounds;
}

#pragma mark - Override UIView methods

+ (BOOL)requiresConstraintBasedLayout {
  return YES;
}

#pragma mark - Truncation Handlers
/**
 This method appends truncation token if required
 Conditions : 1. self.customTruncationEnabled = YES
              2. self.attributedTruncationToken.length > 0
              3. Truncation token is not appended
 */

- (void)appendTokenIfNeeded {
  if ([self shouldAppendTruncationToken] && ![self truncationTokenAppended]) {
    if ([self.textStorage isNewLinePresent]) {
      //Append token string at the end of last visible line
      [self.textStorage replaceCharactersInRange:[self rangeForTokenInsertionForStringWithNewLine]
                            withAttributedString:self.attributedTruncationToken];
    }
    
    //Check for truncation range and append truncation token if required
     NSRange tokenRange =[self rangeForTokenInsertion];
    NSLog(@"token range = %@",NSStringFromRange(tokenRange));
    if (tokenRange.location != NSNotFound) {
      [self.textStorage replaceCharactersInRange:tokenRange withAttributedString:self.attributedTruncationToken];
      [self redrawTextForRange:NSMakeRange(0, self.textStorage.length)];
    }
    
    //Apply attributes if truncation token appended
    NSRange truncationRange = [self rangeOfTruncationToken];
    if (truncationRange.location != NSNotFound) {
      [self removeAttributeForTruncatedRange];
      
      //Apply attributes to the truncation token
      NSString *key = [NSString stringWithFormat:kRegexFormatForSearchWord,self.attributedTruncationToken.string];
      PatternDescriptor *descriptor = [self.patternDescriptorDictionary objectForKey:key];
      if (descriptor) {
        [self.textStorage addAttributes:descriptor.patternAttributes range:truncationRange];
        [self redrawTextForRange:truncationRange];
      }
    }
  }
}

- (void)removeTokenIfPresent {
  if ([self truncationTokenAppended]) {
    if (self.attributedTruncationToken.length == 0) return;

    NSRange truncationRange =
    [self.textStorage.string rangeOfString:self.attributedTruncationToken.string];
    NSMutableAttributedString *finalString =
    [[NSMutableAttributedString alloc]initWithAttributedString:self.textStorage];
    
    if (truncationRange.location != NSNotFound) {
      NSRange rangeOfTuncatedString = NSMakeRange(truncationRange.location,
                                                  self.attributedText.length-truncationRange.location);
      NSAttributedString *truncatedString =
      [self.attributedText attributedSubstringFromRange:rangeOfTuncatedString];
      [finalString replaceCharactersInRange:truncationRange withAttributedString:truncatedString];
    }
    [self updateTextStorage:finalString];
  }
}

- (NSRange)rangeForTokenInsertion {
  self.textContainer.size = self.bounds.size;
  if (self.textStorage.length == 0) {
    return NSMakeRange(NSNotFound, 0);
  }
  NSInteger glyphIndex = [self.layoutManager glyphIndexForCharacterAtIndex:self.textStorage.length - 1];
  NSRange range = [self.layoutManager truncatedGlyphRangeInLineFragmentForGlyphAtIndex:glyphIndex];
  NSLog(@"text container on truncation = %f x %f",self.textContainer.size.width,self.textContainer.size.height);
  if (range.location != NSNotFound && self.customTruncationEnabled) {
    range.length += self.attributedTruncationToken.length;
    range.location -= self.attributedTruncationToken.length;
  }
  return range;
}

- (NSRange)rangeForTokenInsertionForStringWithNewLine {
  NSInteger numberOfLines, index, numberOfGlyphs = [self.layoutManager numberOfGlyphs];
  NSRange lineRange = NSMakeRange(NSNotFound, 0);
  NSInteger approximateNumberOfLines = CGRectGetHeight([self.layoutManager usedRectForTextContainer:self.textContainer])/self.font.lineHeight;
  
  for (numberOfLines = 0, index = 0; index < numberOfGlyphs; numberOfLines++){
    [self.layoutManager lineFragmentRectForGlyphAtIndex:index
                                         effectiveRange:&lineRange];
    if (numberOfLines == approximateNumberOfLines - 1) break;
    index = NSMaxRange(lineRange);
  }
  NSRange rangeOfText = NSMakeRange(lineRange.location + lineRange.length - 1,
                                    self.textStorage.length - lineRange.location - lineRange.length + 1);
  return rangeOfText;
}

- (NSRange)rangeOfTruncationToken {
  NSRange truncationRange;
  if (self.attributedTruncationToken && self.customTruncationEnabled) {
    truncationRange = [self.textStorage.string rangeOfString:self.attributedTruncationToken.string];
  }else {
    truncationRange = [self rangeForTokenInsertion];
  }
  return truncationRange;
}

- (BOOL)shouldAppendTruncationToken {
  return (self.textStorage.length > 0 && self.customTruncationEnabled && self.attributedTruncationToken.length > 0 && self.numberOfLines > 0);
}

- (BOOL)truncationTokenAppended {
  return (self.textStorage.length > 0 && (self.attributedTruncationToken.length > 0) &&
        ([self.textStorage.string rangeOfString:self.attributedTruncationToken.string].location != NSNotFound));
}

- (void)updateTruncationToken:(NSAttributedString *)attributedTruncationToken withAction:(PatternTapResponder)action {
  NSError *error;
  if (self.attributedTruncationToken.length > 0) {
    NSString *patternKey = [NSString stringWithFormat:kRegexFormatForSearchWord,self.attributedTruncationToken.string];
    [self disablePatternDetection:[self.patternDescriptorDictionary objectForKey:patternKey]];
  }
  
  self.attributedTruncationToken = attributedTruncationToken;
  NSString *pattern = [NSString stringWithFormat:kRegexFormatForSearchWord,self.attributedTruncationToken.string];
  NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:&error];
  PatternDescriptor *descriptor = [[PatternDescriptor alloc]initWithRegex:regex
                                                           withSearchType:PatternSearchTypeLast
                                                    withPatternAttributes:@{RLTapResponderAttributeName:action}];
  [self enablePatternDetection:descriptor];
}

#pragma mark - Touch Handlers

- (void)configureForGestures {
  self.userInteractionEnabled = YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  CGPoint touchLocation = [[touches anyObject] locationInView:self];
  NSInteger index = [self characterIndexAtLocation:touchLocation];
  NSRange rangeOfTappedText;
  if (index < self.textStorage.length) {
   rangeOfTappedText = [self.layoutManager rangeOfNominallySpacedGlyphsContainingIndex:index];
  }
  
  if (rangeOfTappedText.location != NSNotFound &&
      ![self patternTouchInProgress] &&
      [self shouldHandleTouchAtIndex:index]) {
  
    [self handleTouchBeginForRange:rangeOfTappedText];
  }else {
    [super touchesBegan:touches withEvent:event];
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  [super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
  [super touchesCancelled:touches withEvent:event];
  [self handleTouchCancelled];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
  if ([self patternTouchInProgress] && [self shouldHandleTouchAtIndex:self.selectedRange.location]) {
    [self performSelector:@selector(handleTouchEnd)
               withObject:nil
               afterDelay:0.05];
  }else {
    [super touchesEnded:touches withEvent:event];
  }
}

- (void)handleTouchBeginForRange:(NSRange)range {
  if (![self patternTouchInProgress]) {
    //Set global variable
    self.selectedRange = range;
    self.currentAttributedString = [[NSMutableAttributedString alloc]initWithAttributedString:self.textStorage];
    [self addHighlightingForIndex:range.location];
  }
}

- (void)handleTouchEnd {
  if ([self patternTouchInProgress]) {
    [self performActionAtIndex:self.selectedRange.location];
    [self removeHighlightingForIndex:self.selectedRange.location];
    
    //Clear global Variable
    self.selectedRange = NSMakeRange(NSNotFound, 0);
    self.currentAttributedString = nil;
  }
}

- (void)handleTouchCancelled {
  if ([self patternTouchInProgress]) {
    [self removeHighlightingForIndex:self.selectedRange.location];

    //Clear global Variable
    self.selectedRange = NSMakeRange(NSNotFound, 0);
    self.currentAttributedString = nil;
  }
}

- (BOOL)patternTouchInProgress {
  return self.selectedRange.location != NSNotFound;
}

/** 
 This method checks whether the given index can handle touch
 Touch will be handled if any of these attributes are set: RLTapResponderAttributeName
                                             or RLHighlightedBackgroundColorAttributeName
                                             or RLHighlightedForegroundColorAttributeName
 @param index: NSInteger - Index to be checked
 @return It returns a BOOL incating if touch handling is enabled or not
 */
- (BOOL)shouldHandleTouchAtIndex:(NSInteger)index {
  if (index > self.textStorage.length) return NO;
  NSRange range;
  NSDictionary *dictionary = [self.textStorage attributesAtIndex:index effectiveRange:&range];
  BOOL touchAttributesSet = (dictionary && ([dictionary.allKeys containsObject:RLTapResponderAttributeName] ||
          [dictionary.allKeys containsObject:RLHighlightedBackgroundColorAttributeName] ||
          [dictionary.allKeys containsObject:RLHighlightedForegroundColorAttributeName]));
  
  return touchAttributesSet;
}

/**
 This method executes the block corresponding to RLTapResponderAttributeName.
 @param index : NSInteger - Index at which the action to be performed
 */
- (void)performActionAtIndex:(NSInteger)index {
  NSRange patternRange;
  if (index < self.textStorage.length) {
   PatternTapResponder tapResponder = [self.textStorage attribute:RLTapResponderAttributeName
                                                          atIndex:index
                                                   effectiveRange:&patternRange];
    if (tapResponder) {
      tapResponder([self.textStorage.string substringWithRange:patternRange]);
    }
  }
}

#pragma mark - Highlighting

- (void)addHighlightingForIndex:(NSInteger)index {
  if (index > self.textStorage.length) return;
  UIColor *backgroundcolor = nil;
  UIColor *foregroundcolor = nil;
  NSRange patternRange;
  
  if (index < self.textStorage.length) {
    backgroundcolor = [self.textStorage attribute:RLHighlightedBackgroundColorAttributeName
                                          atIndex:index
                                   effectiveRange:&patternRange];
    foregroundcolor = [self.textStorage attribute:RLHighlightedForegroundColorAttributeName
                                          atIndex:index
                                   effectiveRange:&patternRange];
    
    if (backgroundcolor) {
      [self.textStorage addAttribute:NSBackgroundColorAttributeName
                               value:backgroundcolor
                               range:patternRange];
    }
    if (foregroundcolor) {
      [self.textStorage addAttribute:NSForegroundColorAttributeName
                               value:foregroundcolor
                               range:patternRange];
    }
  }
  [self setNeedsDisplay];
}

- (void)removeHighlightingForIndex:(NSInteger)index {
  if (self.selectedRange.location != NSNotFound && self.textStorage.length > index) {
    UIColor *backgroundcolor = nil;
    UIColor *foregroundcolor = nil;
    NSRange patternRange;
    
    if (index < self.textStorage.length) {
      backgroundcolor = [self.currentAttributedString attribute:NSBackgroundColorAttributeName
                                                        atIndex:index
                                                 effectiveRange:&patternRange];
      foregroundcolor = [self.currentAttributedString attribute:NSForegroundColorAttributeName
                                                        atIndex:index
                                                 effectiveRange:&patternRange];
      
      if (backgroundcolor) {
        [self.textStorage addAttribute:NSBackgroundColorAttributeName
                                 value:backgroundcolor
                                 range:patternRange];
      }else {
        [self.textStorage removeAttribute:NSBackgroundColorAttributeName
                                    range:patternRange];
      }
      if (foregroundcolor) {
        [self.textStorage addAttribute:NSForegroundColorAttributeName
                                 value:foregroundcolor
                                 range:patternRange];
      }
    }
    [self setNeedsDisplay];
  }
}

#pragma mark - Pattern matching

- (void)addAttributesForPatternDescriptor:(PatternDescriptor *)patternDescriptor {
  //Generate ranges for attributed text of the label
  NSArray *patternRanges = [patternDescriptor patternRangesForString:self.attributedText.string];

  //Apply attributes to the ranges conditionally
   [patternRanges enumerateObjectsUsingBlock:^(NSValue *obj, NSUInteger idx, BOOL *stop) {
     if ([self shouldAddAttributesAtRange:obj.rangeValue]) {
       [self.textStorage addAttributes: patternDescriptor.patternAttributes range:obj.rangeValue];
       [self redrawTextForRange:obj.rangeValue];
     }
  }];
}

- (void)removeAttributesForPatternDescriptor:(PatternDescriptor *)patternDescriptor {
  //Generate ranges for current text of textStorage
  NSArray *patternRanges = [patternDescriptor patternRangesForString:self.textStorage.string];
  
  //Remove attributes from the ranges conditionally
  [patternRanges enumerateObjectsUsingBlock:^(NSValue *obj, NSUInteger idx, BOOL *stop) {
    if ([self shouldRemoveAttributesFromRange:obj.rangeValue]) {//Do nothing if range is truncated
      [patternDescriptor.patternAttributes enumerateKeysAndObjectsUsingBlock:^(NSString *attributeName, id attributeValue, BOOL *stop) {
        [self.textStorage removeAttribute:attributeName range:obj.rangeValue];
      }];
      [self redrawTextForRange:obj.rangeValue];
    }
  }];
}

- (BOOL)shouldAddAttributesAtRange:(NSRange)range {
  NSRange truncationRange = [self rangeOfTruncationToken];
  BOOL isTruncationRange = NSEqualRanges(range, truncationRange);
  BOOL doesIntersectTruncationRange = NSIntersectionRange(range, truncationRange).length == 0;
  BOOL isRangeOutOfBound = (range.location + range.length) > self.textStorage.length;
  return ((!isRangeOutOfBound && doesIntersectTruncationRange) || isTruncationRange);
}

- (BOOL)shouldRemoveAttributesFromRange:(NSRange)range {
  NSRange truncationRange = [self rangeOfTruncationToken];
  BOOL isTruncationRange = NSEqualRanges(range, truncationRange);
  BOOL doesIntersectTruncationRange = NSIntersectionRange(range, truncationRange).length == 0;
  return (isTruncationRange || doesIntersectTruncationRange);
}

/**
 This method removes attributes from the truncated range. 
 TruncatedRange is defined as the pattern range which overlaps the range of 
 truncation token. When the truncation token is set, the attributes of the 
 truncated range should be removed.
 */
- (void)removeAttributeForTruncatedRange {
  NSRange truncationRange = [self rangeOfTruncationToken];

  [self.patternDescriptorDictionary enumerateKeysAndObjectsUsingBlock:^(id key, PatternDescriptor *descriptor, BOOL *stop) {
    
    //Generate ranges for attributed text of the label
    NSArray *ranges = [descriptor patternRangesForString:self.attributedText.string];

    [ranges enumerateObjectsUsingBlock:^(NSValue *obj, NSUInteger idx, BOOL *stop) {
      NSRange interSectionRange = NSIntersectionRange(obj.rangeValue, truncationRange);
      BOOL isRangeTruncated = (interSectionRange.length > 0) && (obj.rangeValue.location < truncationRange.location);
      //Remove attributes if the range is truncated
      if (isRangeTruncated) {
        NSRange visibleRange = NSMakeRange(obj.rangeValue.location,obj.rangeValue.length - interSectionRange.length);
        [descriptor.patternAttributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
          [self.textStorage removeAttribute:key range:visibleRange];
          [self redrawTextForRange:visibleRange];
        }];
      }
    }];
  }];
}

/**
This method returns the key for the given PatternDescriptor stored in patternDescriptorDictionary.
In patternDescriptorDictionary, each entry has the format (NSString, PatternDescriptor).
@param: PatternDescriptor
@return: NSString
*/

- (NSString *)patternNameKeyForPatternDescriptor:(PatternDescriptor *)patternDescriptor {
  NSString *key;
  if ([patternDescriptor.patternExpression isKindOfClass:[NSDataDetector class]]) {
    //As NSDataDetector class, patternExpression.pattern = nil,
    //we need to set key according to checkingTypes
    NSTextCheckingTypes types = ((NSDataDetector *)patternDescriptor.patternExpression).checkingTypes;
    key = [NSString stringWithFormat:@"%llu",types];
  }else {
    key = patternDescriptor.patternExpression.pattern;
  }
  return key;
}

#pragma mark - Helper Methods

/**
This method does initial text configuration which includes updating text storage
and appending truncation token
*/

- (void)initialTextConfiguration {
  NSAttributedString *currentText;
  if (self.attributedText.length > 0) {
    currentText = [self.attributedText wordWrappedAttributedString];
  }else if (self.text.length > 0){
    currentText = [[NSAttributedString alloc]initWithString:self.text
                                                 attributes:[self attributesFromProperties]];
  }
  if (currentText.length > 0) {
    [self updateTextStorage:currentText];
    [self appendTokenIfNeeded];
  }
}

/** This method extects the attributes from the properties of the label
 @return Dictionary of attributes
 */

- (NSDictionary *)attributesFromProperties {
  // Setup shadow attributes
  NSShadow *shadow = shadow = [[NSShadow alloc] init];
  if (self.shadowColor) {
    shadow.shadowColor = self.shadowColor;
    shadow.shadowOffset = self.shadowOffset;
  }
  else {
    shadow.shadowOffset = CGSizeMake(0, -1);
    shadow.shadowColor = nil;
  }
  
  // Setup colour attributes
  UIColor *colour = self.textColor;
  if (!self.isEnabled)
    colour = [UIColor lightGrayColor];
  else if (self.isHighlighted)
    colour = self.highlightedTextColor;
  
  // Setup paragraph attributes
  NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
  paragraph.alignment = self.textAlignment;
  
  // Create the dictionary
  NSDictionary *attributes = @{NSFontAttributeName : self.font,
                               NSForegroundColorAttributeName : colour,
                               NSShadowAttributeName : shadow,
                               NSParagraphStyleAttributeName : paragraph,
                               };
  return attributes;
}
/** Updates text container size
 @param size: CGSize
 */

- (void)updateTextContainerSize:(CGSize)size {
  CGSize containerSize = size;
  containerSize.width = MIN(size.width, self.preferredMaxLayoutWidth);
  containerSize.height = 0;
  self.textContainer.size = containerSize;
}

/**
 This method sets the attributedString of text storage and applies required 
 attributes specified in patternDescriptorDictionary
 @param attributedText: NSAttributedString
 */

- (void)updateTextStorage:(NSAttributedString *)attributedText {
  if (attributedText.length > 0) {
    [self.textStorage setAttributedString:attributedText];
    [self redrawTextForRange:NSMakeRange(0, attributedText.length)];
  }

  [self.patternDescriptorDictionary enumerateKeysAndObjectsUsingBlock:^(id key, PatternDescriptor *descriptor, BOOL *stop) {
     [self addAttributesForPatternDescriptor:descriptor];
  }];
}

/**
 Returns index of character located a given point
 @param location: CGPoint
 @return character index
 */

- (NSUInteger)characterIndexAtLocation:(CGPoint)location {
  NSUInteger chracterIndex = NSNotFound;
  if (self.textStorage.string.length > 0) {
    NSUInteger glyphIndex = [self glyphIndexForLocation:location];
    // If the touch is in white space after the last glyph on the line we don't
    // count it as a hit on the text
    NSRange lineRange;
    CGRect lineRect = [self.layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex
                                                               effectiveRange:&lineRange];
    lineRect.size.height = 60;  //Adjustment to increase tap area
    if (CGRectContainsPoint(lineRect, location)) {
      chracterIndex = [self.layoutManager characterIndexForGlyphAtIndex:glyphIndex];
    }
  }
  return chracterIndex;
}

/**
 Returns glyph index for a given point
 @param location: CGPoint
 @return glyph index for given point
 */

- (NSUInteger)glyphIndexForLocation:(CGPoint)location {
  // Get offset of the text in the view
  CGPoint textOffset;
  NSRange glyphRange = [self.layoutManager
                        glyphRangeForTextContainer:self.textContainer];
  textOffset = [self textOffsetForGlyphRange:glyphRange];
  
  // Get the touch location and use text offset to convert to text cotainer coords
  location.x -= textOffset.x;
  location.y -= textOffset.y;
  
  return  [self.layoutManager glyphIndexForPoint:location
                                 inTextContainer:self.textContainer];
}

#pragma mark - Public Methods

- (void)setText:(NSString *)text withTruncation:(BOOL)truncation {
  [self setText:text];
  [self setCustomTruncationEnabled:truncation];
}

- (void)setAttributedText:(NSAttributedString *)attributedText withTruncation:(BOOL)truncation {
  [self setAttributedText:attributedText];
  [self setCustomTruncationEnabled:truncation];
}

- (void)setAttributedTruncationToken:(NSAttributedString *)attributedTruncationToken withAction:(PatternTapResponder)action {
  [self removeTokenIfPresent];
  [self updateTruncationToken:attributedTruncationToken withAction:action];
  if (self.customTruncationEnabled) {
    [self appendTokenIfNeeded];
  }
}

- (void)setTruncationIndicatorImage:(UIImage *)image withSize:(CGSize)size andAction:(PatternTapResponder)action {
  InlineTextAttachment *textAttachment = [[InlineTextAttachment alloc]init];
  textAttachment.image = image;
  textAttachment.fontDescender = self.font.descender;
  textAttachment.bounds = CGRectMake(0, -self.font.descender - self.font.lineHeight/2,size.width,size.height);
  NSAttributedString *imageAttributedString = [NSAttributedString attributedStringWithAttachment:textAttachment];

  NSAttributedString *paddingString = [[NSAttributedString alloc]initWithString:@" "];
  NSMutableAttributedString *finalString = [[NSMutableAttributedString alloc]initWithAttributedString:paddingString];
  [finalString appendAttributedString:imageAttributedString];
  [finalString appendAttributedString:paddingString];
  [self setAttributedTruncationToken:finalString withAction:action];
}

- (void)enableHashTagDetectionWithAttributes:(NSDictionary*)dictionary {
  NSError *error;
  NSRegularExpression	*regex = [[NSRegularExpression alloc]initWithPattern:kRegexStringForHashTag options:0 error:&error];
  PatternDescriptor *descriptor = [[PatternDescriptor alloc]initWithRegex:regex
                                                           withSearchType:PatternSearchTypeAll
                                                    withPatternAttributes:dictionary];
  [self enablePatternDetection:descriptor];  
}

- (void)disableHashTagDetection {
  [self disablePatternDetection:[self.patternDescriptorDictionary objectForKey:kRegexStringForHashTag]];
}

- (void)enableUserHandleDetectionWithAttributes:(NSDictionary*)dictionary {
  NSError *error;
  NSRegularExpression	*regex = [[NSRegularExpression alloc]initWithPattern:kRegexStringForUserHandle
                                                                   options:0
                                                                     error:&error];
  PatternDescriptor *descriptor = [[PatternDescriptor alloc]initWithRegex:regex
                                                           withSearchType:PatternSearchTypeAll
                                                    withPatternAttributes:dictionary];
  [self enablePatternDetection:descriptor];
}

- (void)disableUserHandleDetection {
  [self disablePatternDetection:[self.patternDescriptorDictionary objectForKey:kRegexStringForUserHandle]];
}

- (void)enableStringDetection:(NSString *)string withAttributes:(NSDictionary*)dictionary {
  NSError *error;
  NSString *pattern = [NSString stringWithFormat:kRegexFormatForSearchWord,string];
  NSRegularExpression	*regex = [[NSRegularExpression alloc]initWithPattern:pattern
                                                                   options:0
                                                                     error:&error];

  PatternDescriptor *descriptor = [[PatternDescriptor alloc]initWithRegex:regex
                                                           withSearchType:PatternSearchTypeAll
                                                    withPatternAttributes:dictionary];
  [self enablePatternDetection:descriptor];
}

- (void)disableStringDetection:(NSString *)string {
  NSString *key = [NSString stringWithFormat:kRegexFormatForSearchWord,string];
  [self disablePatternDetection:[self.patternDescriptorDictionary objectForKey:key]];
}

- (void)enableDetectionForStrings:(NSArray *)stringsArray withAttributes:(NSDictionary *)dictionary {
  [stringsArray enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop) {
    [self enableStringDetection:string withAttributes:dictionary];
  }];
}

- (void)disableDetectionForStrings:(NSArray *)stringsArray {
  [stringsArray enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop) {
    [self disableStringDetection:string];
  }];
}

- (void)enablePatternDetection:(PatternDescriptor *)patternDescriptor {
  NSString *patternkey = [self patternNameKeyForPatternDescriptor:patternDescriptor];
  if (patternkey.length > 0) {
    [self.patternDescriptorDictionary setObject:patternDescriptor
                                       forKey:patternkey];
    [self addAttributesForPatternDescriptor:patternDescriptor];
  }
}

- (void)disablePatternDetection:(PatternDescriptor *)patternDescriptor {
  NSString *patternkey = [self patternNameKeyForPatternDescriptor:patternDescriptor];
  if (patternkey.length > 0) {
    [self.patternDescriptorDictionary removeObjectForKey:patternkey];
    [self removeAttributesForPatternDescriptor:patternDescriptor];
  }
}

- (void)enableURLDetectionWithAttributes:(NSDictionary*)dictionary {
  NSError *error = nil;
  NSDataDetector *detector = [[NSDataDetector alloc] initWithTypes:NSTextCheckingTypeLink error:&error];
  PatternDescriptor *descriptor = [[PatternDescriptor alloc]initWithRegex:detector
                                                           withSearchType:PatternSearchTypeAll
                                                    withPatternAttributes:dictionary];
  [self enablePatternDetection:descriptor];
}

- (void)disableURLDetection {
  NSString *key = [NSString stringWithFormat:@"%llu",NSTextCheckingTypeLink];
  [self disablePatternDetection:[self.patternDescriptorDictionary objectForKey:key]];
}

@end
