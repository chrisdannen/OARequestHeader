//
//  OARequestHeader.m
//  TwitPic Uploader
//
//  Created by Gurpartap Singh on 19/06/10.
//  Copyright 2010 Gurpartap Singh. All rights reserved.
//

#import "OARequestHeader.h"

#include <CommonCrypto/CommonDigest.h>


@interface OARequestHeader (Private)
- (void)_generateTimestamp;
- (void)_generateNonce;
- (NSString *)_signatureBaseString;
@end

@implementation OARequestHeader

- (id)initWithProvider:(NSString *)theProvider
                method:(NSString *)theMethod
              consumer:(OAConsumer *)theConsumer
                 token:(OAToken *)theToken
                 realm:(NSString *)theRealm
       timestampOffset:(NSTimeInterval)theTimestampOffset
     requestParameters:(NSArray*)theRequestParameters
{
    self = [super init];

    if (self != nil) {
      provider = [theProvider copy];

      if (theMethod != nil) {
          method = [theMethod copy];
      }
      else {
          method = @"GET";
      }

      consumer = [theConsumer retain];
      token = [theToken retain];
      realm = [theRealm copy];
      signatureProvider = [[OAHMAC_SHA1SignatureProvider alloc] init]; // HMAC-SHA1
      timestampOffset = theTimestampOffset;
      requestParameters = [theRequestParameters copy];
    }

    return self;
}

- (void)dealloc
{
	[consumer release], consumer = nil;
	[token release], token = nil;
	[provider release], provider = nil;
	[method release], method = nil;
	[realm release], realm = nil;
	[signature release], signature = nil;
	[signatureProvider release], signatureProvider = nil;
	[nonce release], nonce = nil;
	[timestamp release], timestamp = nil;
	[requestParameters release], requestParameters = nil;
	[super dealloc];
}

- (NSString *)generateRequestHeaders {
    [self _generateTimestamp];
    [self _generateNonce];

		NSString * tmpSignature = [signatureProvider signClearText:[self _signatureBaseString]
                                      withSecret:[NSString stringWithFormat:@"%@&%@", [consumer.secret encodedURLString], token.secret ? [token.secret encodedURLString] : @""]];
    [signature release], signature = nil;
    signature = [tmpSignature copy];
    NSMutableArray *chunks = [[NSMutableArray alloc] init];

    [chunks addObject:[NSString stringWithFormat:@"realm=\"%@\"", [realm encodedURLParameterString]]];
    [chunks addObject:[NSString stringWithFormat:@"oauth_consumer_key=\"%@\"", [consumer.key encodedURLParameterString]]];

    NSDictionary *tokenParameters = [token parameters];
    for (NSString *k in tokenParameters) {
        [chunks addObject:[NSString stringWithFormat:@"%@=\"%@\"", k, [[tokenParameters objectForKey:k] encodedURLParameterString]]];
    }

    [chunks addObject:[NSString stringWithFormat:@"oauth_signature_method=\"%@\"", [[signatureProvider name] encodedURLParameterString]]];
    [chunks addObject:[NSString stringWithFormat:@"oauth_signature=\"%@\"", [signature encodedURLParameterString]]];
    [chunks addObject:[NSString stringWithFormat:@"oauth_timestamp=\"%@\"", timestamp]];
    [chunks addObject:[NSString stringWithFormat:@"oauth_nonce=\"%@\"", nonce]];
    [chunks addObject:@"oauth_version=\"1.0\""];

    NSString *oauthHeader = [NSString stringWithFormat:@"OAuth %@", [chunks componentsJoinedByString:@", "]];
		[chunks release], chunks = nil;

    // NSLog(@"oauthHeader: %@", oauthHeader);

    return oauthHeader;
}


- (void)_generateTimestamp {
    NSTimeInterval stamp = [[NSDate date] timeIntervalSince1970] + timestampOffset;
		[timestamp release], timestamp = nil;
    timestamp = [[NSString alloc] initWithFormat:@"%d", (int)stamp];
}


- (void)_generateNonce {
    const char *cStr = [[NSString stringWithFormat:@"%d%d", timestamp, random()] UTF8String];
    unsigned char result[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cStr, strlen(cStr), result);
    NSMutableString *out = [NSMutableString stringWithCapacity:20];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [out appendFormat:@"%02X", result[i]];
    }

    [nonce release], nonce = nil;
    nonce = [[out lowercaseString] copy];
}


- (NSString *)_signatureBaseString {
    // OAuth Spec, Section 9.1.1 "Normalize Request Parameters"
    // Build a sorted array of both request parameters and OAuth header parameters.
    NSDictionary *tokenParameters = [token parameters];
    // 5 being the number of OAuth params in the Signature Base String
    NSMutableArray *parameterPairs = [[NSMutableArray alloc] initWithCapacity:(5 + [tokenParameters count])];

    [parameterPairs addObject:[[[[OARequestParameter alloc] initWithName:@"oauth_consumer_key" value:consumer.key] autorelease] URLEncodedNameValuePair]];
    [parameterPairs addObject:[[[[OARequestParameter alloc] initWithName:@"oauth_signature_method" value:[signatureProvider name]] autorelease] URLEncodedNameValuePair]];
    [parameterPairs addObject:[[[[OARequestParameter alloc] initWithName:@"oauth_timestamp" value:timestamp] autorelease] URLEncodedNameValuePair]];
    [parameterPairs addObject:[[[[OARequestParameter alloc] initWithName:@"oauth_nonce" value:nonce] autorelease] URLEncodedNameValuePair]];
    [parameterPairs addObject:[[[[OARequestParameter alloc] initWithName:@"oauth_version" value:@"1.0"] autorelease] URLEncodedNameValuePair]];

    for (NSString *param in tokenParameters) {
        [parameterPairs addObject:[[OARequestParameter requestParameter:param value:[tokenParameters objectForKey:param]] URLEncodedNameValuePair]];
    }

    for (OARequestParameter *requestParam in requestParameters)
    {
        [parameterPairs addObject:[requestParam URLEncodedNameValuePair]];
    }

    NSArray *sortedPairs = [parameterPairs sortedArrayUsingSelector:@selector(compare:)];
    [parameterPairs release], parameterPairs = nil;
    NSString *normalizedRequestParameters = [[[NSString alloc] initWithString:[sortedPairs componentsJoinedByString:@"&"]] autorelease];

    // OAuth Spec, Section 9.1.2 "Concatenate Request Elements"
    return [NSString stringWithFormat:@"%@&%@&%@", method, [provider encodedURLParameterString], [normalizedRequestParameters encodedURLString]];
}


@end
