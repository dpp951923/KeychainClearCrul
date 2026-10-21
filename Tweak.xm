#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <sys/un.h>
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

static const uint16_t kHTTPPort = 18765;

static NSArray *ItemClasses(void) {
    return @[
        (__bridge NSString *)kSecClassKey,
        (__bridge NSString *)kSecClassIdentity,
        (__bridge NSString *)kSecClassCertificate,
        (__bridge NSString *)kSecClassGenericPassword,
        (__bridge NSString *)kSecClassInternetPassword
    ];
}

static NSDictionary *ClearKeychain(void) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    for (NSString *itemClass in ItemClasses()) {
        NSDictionary *query = @{
            (__bridge NSString *)kSecClass: itemClass,
            (__bridge NSString *)kSecAttrSynchronizable:
                (__bridge id)kSecAttrSynchronizableAny
        };

        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        result[itemClass] = @(status);
        NSLog(@"[KeychainClear] SecItemDelete(%@) => OSStatus %d", itemClass, (int)status);
    }

    return result;
}

static NSString *RunClear(void) {
    @try {
        NSLog(@"[KeychainClear] Clearing keychain...");
        NSDictionary *result = ClearKeychain();
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"[KeychainClear] Done.");
        return [NSString stringWithFormat:@"%@\n", json ?: @"{}"]; 
    } @catch (NSException *exception) {
        NSLog(@"[KeychainClear] Error: %@", exception);
        return [NSString stringWithFormat:@"error: %@\n", exception.reason ?: @"unknown"];
    }
}

static NSString *HandleCommand(NSString *command) {
    NSString *value = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([value isEqualToString:@"ping"]) return @"pong\n";
    if ([value isEqualToString:@"status"]) return @"ready\n";
    if ([value isEqualToString:@"clear"]) return RunClear();
    return @"error: unknown command\n";
}

static NSData *HTTPResponse(NSString *body, NSInteger statusCode) {
    NSString *status = statusCode == 200 ? @"200 OK" : @"400 Bad Request";
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: application/json\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n", status, (unsigned long)body.lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *data = [NSMutableData data];
    [data appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    return data;
}

static void StartHTTPServer(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int serverFD = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFD < 0) return;

        int reuse = 1;
        setsockopt(serverFD, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

        struct sockaddr_in address;
        memset(&address, 0, sizeof(address));
        address.sin_family = AF_INET;
        address.sin_port = htons(kHTTPPort);
        address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

        if (bind(serverFD, (struct sockaddr *)&address, sizeof(address)) != 0) {
            close(serverFD);
            return;
        }
        if (listen(serverFD, 4) != 0) {
            close(serverFD);
            return;
        }

        NSLog(@"[KeychainClearCrul] HTTP server ready: 127.0.0.1:%d", kHTTPPort);

        for (;;) {
            int clientFD = accept(serverFD, NULL, NULL);
            if (clientFD < 0) continue;

            char buffer[4096] = {0};
            ssize_t length = read(clientFD, buffer, sizeof(buffer) - 1);
            NSString *request = length > 0 ? [[NSString alloc] initWithBytes:buffer length:(NSUInteger)length encoding:NSUTF8StringEncoding] : @"";
            NSString *firstLine = [[request componentsSeparatedByString:@"\r\n"] firstObject] ?: @"";
            NSArray *parts = [firstLine componentsSeparatedByString:@" "];
            NSString *method = parts.count > 0 ? parts[0] : @"";
            NSString *path = parts.count > 1 ? parts[1] : @"";

            NSString *body;
            NSInteger status = 200;
            if ([method isEqualToString:@"GET"] && [path isEqualToString:@"/ping"]) {
                body = @"{\"status\":\"pong\"}\n";
            } else if ([method isEqualToString:@"GET"] && [path isEqualToString:@"/status"]) {
                body = @"{\"status\":\"ready\"}\n";
            } else if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/clear"]) {
                body = RunClear();
            } else {
                status = 400;
                body = @"{\"error\":\"use GET /ping, GET /status, or POST /clear\"}\n";
            }

            NSData *response = HTTPResponse(body, status);
            write(clientFD, response.bytes, response.length);
            close(clientFD);
        }
    });
}
%ctor {
    StartHTTPServer();
}
