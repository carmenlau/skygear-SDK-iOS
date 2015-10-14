//
//  SKYDeleteSubscriptionsOperationTests.m
//  SkyKit
//
//  Created by Kenji Pa on 17/5/15.
//  Copyright (c) 2015 Kwok-kuen Cheung. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SkyKit/SkyKit.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

SpecBegin(SKYDeleteSubscriptionsOperation)

describe(@"delete subscription", ^{
    __block SKYContainer *container = nil;
    __block SKYDatabase *database = nil;

    beforeEach(^{
        container = [[SKYContainer alloc] init];
        [container configureWithAPIKey:@"API_KEY"];
        [container updateWithUserRecordID:[SKYUserRecordID recordIDWithUsername:@"USER_ID"]
                              accessToken:[[SKYAccessToken alloc] initWithTokenString:@"ACCESS_TOKEN"]];
        database = [container publicCloudDatabase];
    });

    it(@"multiple subscriptions", ^{
        SKYDeleteSubscriptionsOperation *operation = [SKYDeleteSubscriptionsOperation operationWithSubscriptionIDsToDelete:@[@"my notes", @"ben's notes"]];
        operation.deviceID = @"DEVICE_ID";
        operation.database = database;
        operation.container = container;
        [operation prepareForRequest];
        SKYRequest *request = operation.request;
        expect([request class]).to.beSubclassOf([SKYRequest class]);
        expect(request.action).to.equal(@"subscription:delete");
        expect(request.APIKey).to.equal(@"API_KEY");
        expect(request.accessToken).to.equal(container.currentAccessToken);
        expect(request.payload).to.equal(@{
                                           @"device_id": @"DEVICE_ID",
                                           @"database_id": database.databaseID,
                                           @"ids": @[@"my notes", @"ben's notes"],
                                           });
    });

    it(@"make request", ^{
        SKYDeleteSubscriptionsOperation *operation = [SKYDeleteSubscriptionsOperation operationWithSubscriptionIDsToDelete:@[@"my notes", @"ben's notes"]];

        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return YES;
        } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
            NSDictionary *parameters = @{
                                         @"request_id": @"REQUEST_ID",
                                         @"database_id": database.databaseID,
                                         @"result": @[
                                                 @{@"id": @"my notes"},
                                                 @{@"id": @"ben's notes"},
                                                 ]
                                         };
            NSData *payload = [NSJSONSerialization dataWithJSONObject:parameters
                                                              options:0
                                                                error:nil];

            return [OHHTTPStubsResponse responseWithData:payload
                                              statusCode:200
                                                 headers:@{}];
        }];

        waitUntil(^(DoneCallback done) {
            operation.deleteSubscriptionsCompletionBlock = ^(NSArray *subscriptionIDs, NSError *operationError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    expect(subscriptionIDs).to.equal(@[@"my notes", @"ben's notes"]);
                    expect(operationError).to.beNil();
                    done();
                });
            };

            [database executeOperation:operation];
        });
    });

    it(@"pass error", ^{
        SKYDeleteSubscriptionsOperation *operation = [SKYDeleteSubscriptionsOperation operationWithSubscriptionIDsToDelete:@[@"my notes", @"ben's notes"]];

        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return YES;
        } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
            return [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil]];
        }];

        waitUntil(^(DoneCallback done) {
            operation.deleteSubscriptionsCompletionBlock = ^(NSArray *subscriptionIDs, NSError *operationError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    expect(operationError).toNot.beNil();
                    done();
                });
            };

            [database executeOperation:operation];
        });
    });

    it(@"pass per item error", ^{
        SKYDeleteSubscriptionsOperation *operation = [SKYDeleteSubscriptionsOperation operationWithSubscriptionIDsToDelete:@[@"my notes", @"ben's notes"]];

        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return YES;
        } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
            NSDictionary *parameters = @{
                                         @"request_id": @"REQUEST_ID",
                                         @"database_id": database.databaseID,
                                         @"result": @[
                                                 @{@"id": @"my notes"},
                                                 @{
                                                     @"_type": @"error",
                                                     @"_id": @"ben's notes",
                                                     @"message": @"cannot find subscription \"ben's notes\"",
                                                     @"type": @"ResourceNotFound",
                                                     @"code": @101,
                                                     @"info": @{@"id": @"ben's notes"},
                                                     },
                                                 ]
                                         };
            NSData *payload = [NSJSONSerialization dataWithJSONObject:parameters
                                                              options:0
                                                                error:nil];

            return [OHHTTPStubsResponse responseWithData:payload
                                              statusCode:200
                                                 headers:@{}];
        }];

        waitUntil(^(DoneCallback done) {
            operation.deleteSubscriptionsCompletionBlock = ^(NSArray *subscriptionIDs, NSError *operationError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    expect(subscriptionIDs).to.equal(@[@"my notes"]);
                    expect(operationError).toNot.beNil();
                    expect(operationError.domain).to.equal(SKYOperationErrorDomain);
                    expect(operationError.code).to.equal(SKYErrorPartialFailure);

                    NSDictionary *errorBySubscriptionID = operationError.userInfo[SKYPartialErrorsByItemIDKey];
                    expect(errorBySubscriptionID).toNot.beNil();
                    NSError *benError = errorBySubscriptionID[@"ben's notes"];
                    expect(benError).toNot.beNil();
                    expect(benError.userInfo).to.equal(@{
                                                         SKYErrorCodeKey: @101,
                                                         SKYErrorMessageKey: @"cannot find subscription \"ben's notes\"",
                                                         SKYErrorTypeKey: @"ResourceNotFound",
                                                         SKYErrorInfoKey: @{@"id": @"ben's notes"},
                                                         NSLocalizedDescriptionKey: @"An error occurred while deleting subscription."
                                                         });
                    done();
                });
            };

            [database executeOperation:operation];
        });
    });

    describe(@"when there exists device id", ^{
        __block SKYDeleteSubscriptionsOperation *operation;

        beforeEach(^{
            id odDefaultsMock = OCMClassMock(SKYDefaults.class);
            OCMStub([odDefaultsMock sharedDefaults]).andReturn(odDefaultsMock);
            OCMStub([odDefaultsMock deviceID]).andReturn(@"EXISTING_DEVICE_ID");

            operation = [[SKYDeleteSubscriptionsOperation alloc] initWithSubscriptionIDsToDelete:@[]];
            operation.container = container;
            operation.database = database;
        });

        it(@"request with device id", ^{
            [operation prepareForRequest];
            expect(operation.request.payload[@"device_id"]).to.equal(@"EXISTING_DEVICE_ID");
        });

        it(@"user-set device id overrides existing device id", ^{
            operation.deviceID = @"ASSIGNED_DEVICE_ID";
            [operation prepareForRequest];
            expect(operation.request.payload[@"device_id"]).to.equal(@"ASSIGNED_DEVICE_ID");
        });
    });

    afterEach(^{
        [OHHTTPStubs removeAllStubs];
    });
});

SpecEnd
