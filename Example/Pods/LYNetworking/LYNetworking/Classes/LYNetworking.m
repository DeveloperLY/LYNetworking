//
//  LYNetworking.m
//  LYNetworking
//
//  Created by LiuY on 16/11/27.
//  Copyright © 2016年 DeveloperLY. All rights reserved.
//

#import "LYNetworking.h"
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <YYCache/YYCache.h>
#import <CommonCrypto/CommonDigest.h>

// 优雅安全的执行Block
#define LY_SAFE_BLOCK(BlockName, ...) ({ !BlockName ? nil : BlockName(__VA_ARGS__); })
#ifdef DEBUG
#define NSLog(...) NSLog(__VA_ARGS__) // 如果不需要打印数据，把这__  NSLog(__VA_ARGS__) ___注释了
#else
#define NSLog(...)
#endif

static NSString *_baseUrl = nil;
static NSTimeInterval _timeout = 10.0f;
static BOOL _shouldAutoEncode = YES;
static NSDictionary *_httpHeaders = nil;
static LYRequestSerializerType _requestSerializerType = LYRequestSerializerTypeJSON;
static LYResponseSerializerType _responseSerializerType = LYResponseSerializerTypeHTTP;
static LYNetworkStatus _networkStatus = LYNetworkStatusReachableViaWWAN;
static NSMutableArray *_requestTasks;
static BOOL _shouldCallbackOnCancelRequest = YES;
static BOOL _isBaseURLChanged = YES;
static AFHTTPSessionManager *_sharedManager = nil;

// 缓存文件夹名称
static NSString * const LYNetworkingCache = @"LYNetworkingCache";
static YYCache *_cache;

@implementation LYNetworking

+ (NSString *)baseUrl {
    return _baseUrl;
}

+ (void)updateBaseUrl:(NSString *)baseUrl {
    if (![baseUrl isEqualToString:_baseUrl] && baseUrl && baseUrl.length) {
        _isBaseURLChanged = YES;
    } else {
        _isBaseURLChanged = NO;
    }
    _baseUrl = baseUrl;
}

+ (void)setTimeout:(NSTimeInterval)timeout {
    _timeout = timeout;
}

+ (void)configRequestSerializerType:(LYRequestSerializerType)requestSerializerType
             responseSerializerType:(LYResponseSerializerType)responseSerializerType
                shouldAutoEncodeUrl:(BOOL)shouldAutoEncode
            callbackOnCancelRequest:(BOOL)shouldCallbackOnCancelRequest {
    _requestSerializerType = requestSerializerType;
    _responseSerializerType = responseSerializerType;
    _shouldAutoEncode = shouldAutoEncode;
    _shouldCallbackOnCancelRequest = shouldCallbackOnCancelRequest;
}

+ (void)configCommonHttpHeaders:(NSDictionary *)httpHeaders {
    _httpHeaders = httpHeaders;
}

+ (BOOL)shouldEncode {
    return _shouldAutoEncode;
}

+ (NSMutableArray *)allTasks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!_requestTasks) {
            _requestTasks = [[NSMutableArray alloc] init];
        }
    });
    return _requestTasks;
}

+ (void)cancelRequestWithURL:(NSString *)url {
    if (url == nil) {
        return;
    }
    @synchronized(self) {
        [[self allTasks] enumerateObjectsUsingBlock:^(LYURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[LYURLSessionTask class]]
                && [task.currentRequest.URL.absoluteString hasSuffix:url]) {
                [task cancel];
                [[self allTasks] removeObject:task];
                return;
            }
        }];
    };
}

+ (void)cancelAllRequest {
    @synchronized(self) {
        [[self allTasks] enumerateObjectsUsingBlock:^(LYURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[LYURLSessionTask class]]) {
                [task cancel];
            }
        }];
        [[self allTasks] removeAllObjects];
    };
}

+ (YYCache *)cache {
    if (!_cache) {
        // 设置YYCache
        _cache = [[YYCache alloc] initWithName:LYNetworkingCache];
        _cache.memoryCache.shouldRemoveAllObjectsOnMemoryWarning = YES;
        _cache.memoryCache.shouldRemoveAllObjectsWhenEnteringBackground = YES;
    }
    return _cache;
}

#pragma mark - GET（SELECT）请求
+ (LYURLSessionTask *)getRequestURLStr:(NSString *)urlStr
                               isCache:(BOOL)isCache
                               success:(LYResponseSuccess)success
                               failure:(LYResponseFailure)failure {
    return [self getRequestURLStr:urlStr isCache:isCache parameters:nil success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

+ (LYURLSessionTask *)getRequestURLStr:(NSString *)urlStr
                               isCache:(BOOL)isCache
                            parameters:(NSDictionary *)parameters
                               success:(LYResponseSuccess)success
                               failure:(LYResponseFailure)failure {
    return [self getRequestURLStr:urlStr isCache:isCache parameters:parameters progress:nil success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

+ (LYURLSessionTask *)getRequestURLStr:(NSString *)urlStr
                               isCache:(BOOL)isCache
                            parameters:(NSDictionary *)parameters
                              progress:(LYTransfeProgress)progress
                               success:(LYResponseSuccess)success
                               failure:(LYResponseFailure)failure {
    return [self requestWithUrl:urlStr isCache:isCache requsetMethod:LYRequestMethodGet parameters:parameters fileData:nil name:nil fileName:nil mimeType:nil saveToPath:nil transfeProgress:^(int64_t bytesProgress, int64_t totalBytesProgress) {
        LY_SAFE_BLOCK(progress, bytesProgress, totalBytesProgress);
    } success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

#pragma mark - POST（CREATE）请求
+ (LYURLSessionTask *)postRequestURLStr:(NSString *)urlStr
                                isCache:(BOOL)isCache
                             parameters:(NSDictionary *)parameters
                                success:(LYResponseSuccess)success
                                failure:(LYResponseFailure)failure {
    return [self postRequestURLStr:urlStr isCache:isCache parameters:parameters progress:nil success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

+ (LYURLSessionTask *)postRequestURLStr:(NSString *)urlStr
                                isCache:(BOOL)isCache
                             parameters:(NSDictionary *)parameters progress:(LYTransfeProgress)progress success:(LYResponseSuccess)success failure:(LYResponseFailure)failure {
    return [self requestWithUrl:urlStr isCache:isCache requsetMethod:LYRequestMethodPost parameters:parameters fileData:nil name:nil fileName:nil mimeType:nil saveToPath:nil transfeProgress:^(int64_t bytesProgress, int64_t totalBytesProgress) {
        LY_SAFE_BLOCK(progress, bytesProgress, totalBytesProgress);
    } success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

#pragma mark - PUT (UPDATE) 请求
+ (LYURLSessionTask *)putRequestURLStr:(NSString *)urlStr
                            parameters:(NSDictionary *)parameters
                               success:(LYResponseSuccess)success
                               failure:(LYResponseFailure)failure {
    return [self requestWithUrl:urlStr isCache:NO requsetMethod:LYRequestMethodPut parameters:parameters fileData:nil name:nil fileName:nil mimeType:nil saveToPath:nil transfeProgress:nil success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

#pragma mark - PATCH (UPDATE) 请求
+ (LYURLSessionTask *)patchRequestURLStr:(NSString *)urlStr
                              parameters:(NSDictionary *)parameters
                                 success:(LYResponseSuccess)success
                                 failure:(LYResponseFailure)failure {
    return [self requestWithUrl:urlStr isCache:NO requsetMethod:LYRequestMethodPatch parameters:parameters fileData:nil name:nil fileName:nil mimeType:nil saveToPath:nil transfeProgress:nil success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

#pragma mark - DELETE (DELETE) 请求
+ (LYURLSessionTask *)deleteRequestURLStr:(NSString *)urlStr
                              parameters:(NSDictionary *)parameters
                                 success:(LYResponseSuccess)success
                                 failure:(LYResponseFailure)failure {
    return [self requestWithUrl:urlStr isCache:NO requsetMethod:LYRequestMethodDelete parameters:parameters fileData:nil name:nil fileName:nil mimeType:nil saveToPath:nil transfeProgress:nil success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

#pragma mark - 上传单个文件
+ (LYURLSessionTask *)uploadDataWithURLStr:(NSString *)urlStr parameters:(NSDictionary *)parameters fileData:(NSData *)fileData name:(NSString *)name fileName:(NSString *)fileName mimeType:(NSString *)mimeType uploadProgress:(LYTransfeProgress)uploadProgress success:(LYResponseSuccess)success failure:(LYResponseFailure)failure {
    return [self requestWithUrl:urlStr isCache:NO requsetMethod:LYRequestMethodUpload parameters:parameters fileData:fileData name:name fileName:fileName mimeType:mimeType saveToPath:nil transfeProgress:^(int64_t bytesProgress, int64_t totalBytesProgress) {
        LY_SAFE_BLOCK(uploadProgress, bytesProgress, totalBytesProgress);
    } success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

#pragma mark - 下载单个文件
+ (LYURLSessionTask *)downloadWithURLStr:(NSString *)urlStr saveToPath:(NSString *)saveToPath downloadProgress:(LYTransfeProgress)downloadProgress success:(LYResponseSuccess)success failure:(LYResponseFailure)failure {
    return [self requestWithUrl:urlStr isCache:NO requsetMethod:LYRequestMethodDownload parameters:nil fileData:nil name:nil fileName:nil mimeType:nil saveToPath:saveToPath transfeProgress:^(int64_t bytesProgress, int64_t totalBytesProgress) {
        LY_SAFE_BLOCK(downloadProgress, bytesProgress, totalBytesProgress);
    } success:^(id response) {
        LY_SAFE_BLOCK(success, response);
    } failure:^(NSError *error) {
        LY_SAFE_BLOCK(failure, error);
    }];
}

#pragma mark - 网络请求统一处理
+ (LYURLSessionTask *)requestWithUrl:(NSString *)url
                             isCache:(BOOL)isCache
                       requsetMethod:(LYRequestMethod)requestMethod
                          parameters:(NSDictionary *)parameters
                            fileData:(NSData *)fileData
                                name:(NSString *)name
                            fileName:(NSString *)fileName
                            mimeType:(NSString *)mimeType
                          saveToPath:(NSString *)saveToPath
                     transfeProgress:(LYTransfeProgress)transfeProgress
                             success:(LYResponseSuccess)success
                             failure:(LYResponseFailure)failure {
    if ([self shouldEncode]) {
        if ([NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9,0,0}]) {
            url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]; // iOS 9
        } else {
            [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }
    
    NSString *absolute = [self absoluteUrlWithPath:url];
    if ([self baseUrl] == nil) {
        if ([NSURL URLWithString:url] == nil) {
            @throw [NSException exceptionWithName:@"LY_Error" reason:@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL。" userInfo:nil];
            return nil;
        }
    } else {
        NSURL *absoluteURL = [NSURL URLWithString:absolute];
        if (absoluteURL == nil) {
            @throw [NSException exceptionWithName:@"LY_Error" reason:@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL。" userInfo:nil];
            return nil;
        }
    }
    
    NSString *cacheUrl = [self urlParametersToStringWithUrlStr:absolute parameters:parameters];
    NSLog(@"\n\n-网址--\n\n       %@--->     %@\n\n-网址--\n\n", (requestMethod == LYRequestMethodGet) ? @"GET" : @"POST", cacheUrl);
    
    id cacheData = nil;
    if (isCache) {
        cacheData = [self.cache objectForKey:[self md5StringFromString:cacheUrl]];
        if (!cacheData) {
            NSLog(@"cache = %@", cacheData);
            LY_SAFE_BLOCK(success, cacheData);
        }
    }
    
    //请求前网络检查
    if(![self requestBeforeCheckNetWork]) {
        LY_SAFE_BLOCK(failure, [NSError errorWithDomain:@"似乎已断开与互联网的连接" code:4001 userInfo:nil]);
        NSLog(@"\n\n---%@----\n\n", @"似乎已断开与互联网的连接");
        return nil;
    }
    
    AFHTTPSessionManager *manager = [self manager];
    
    LYURLSessionTask *sessionTask = nil;
    
    if (requestMethod == LYRequestMethodGet) {
        sessionTask = [manager GET:url parameters:parameters progress:^(NSProgress * _Nonnull downloadProgress) {
            LY_SAFE_BLOCK(transfeProgress, downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;// 关闭网络指示器
            });
            if (isCache) { /**更新缓存数据*/
                [self.cache setObject:responseObject forKey:[self md5StringFromString:cacheUrl]];
            }
            
            if (!isCache || ![cacheData isEqual:responseObject]) {
                LY_SAFE_BLOCK(success, responseObject);
            }
            
            [[self allTasks] removeObject:task];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [[self allTasks] removeObject:task];
            
            [self handleCallbackWithError:error failure:failure];
            NSLog(@"%zd---%@",error.code, error.description);
        }];
    }
    
    if (requestMethod == LYRequestMethodPost) {
        sessionTask = [manager POST:url parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
            LY_SAFE_BLOCK(transfeProgress, uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;// 关闭网络指示器
            });
            if (isCache) { /**更新缓存数据*/
                [self.cache setObject:responseObject forKey:[self md5StringFromString:cacheUrl]];
            }
            
            if (!isCache || ![cacheData isEqual:responseObject]) {
                LY_SAFE_BLOCK(success, responseObject);
            }
            
            [[self allTasks] removeObject:task];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [[self allTasks] removeObject:task];
            
            [self handleCallbackWithError:error failure:failure];
            
            NSLog(@"%zd---%@",error.code, error.description);
        }];
    }
    
    if (requestMethod == LYRequestMethodPut) {
        sessionTask = [manager PUT:url parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;// 关闭网络指示器
            });
            
            LY_SAFE_BLOCK(success, responseObject);
            
            [[self allTasks] removeObject:task];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [[self allTasks] removeObject:task];
            
            [self handleCallbackWithError:error failure:failure];
            
            NSLog(@"%zd---%@",error.code, error.description);
        }];
    }
    
    if (requestMethod == LYRequestMethodPatch) {
        sessionTask = [manager PATCH:url parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;// 关闭网络指示器
            });
            
            LY_SAFE_BLOCK(success, responseObject);
            
            [[self allTasks] removeObject:task];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [[self allTasks] removeObject:task];
            
            [self handleCallbackWithError:error failure:failure];
            
            NSLog(@"%zd---%@",error.code, error.description);
        }];
    }
    
    if (requestMethod == LYRequestMethodDelete) {
        sessionTask = [manager DELETE:url parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;// 关闭网络指示器
            });
            
            LY_SAFE_BLOCK(success, responseObject);
            
            [[self allTasks] removeObject:task];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [[self allTasks] removeObject:task];
            
            [self handleCallbackWithError:error failure:failure];
            
            NSLog(@"%zd---%@",error.code, error.description);
        }];
    }
    
    if (requestMethod == LYRequestMethodUpload) {
        if (fileName == nil || ![fileName isKindOfClass:[NSString class]] || fileName.length == 0) {
            @throw [NSException exceptionWithName:@"LY_Error" reason:@"fileName不能为空，请填写正确的文件名（带后缀）。" userInfo:nil];
            return nil;
        }
        
        if (!fileData) {
            @throw [NSException exceptionWithName:@"LY_Error" reason:@"fileData = nil，无法上传，请确认文件路径是否正确。" userInfo:nil];
            return nil;
        }
        
        sessionTask = [manager POST:url parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
            [formData appendPartWithFileData:fileData name:name fileName:fileName mimeType:mimeType];
        } progress:^(NSProgress * _Nonnull uploadProgress) {
            NSLog(@"上传的进度参数...\n\n上传进度  %lld \n总进度    %lld\n\n", uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
            
            LY_SAFE_BLOCK(transfeProgress, uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;// 关闭网络指示器
            });
            if (isCache) { /**更新缓存数据*/
                [self.cache setObject:responseObject forKey:[self md5StringFromString:cacheUrl]];
            }
            
            if (!isCache || ![cacheData isEqual:responseObject]) {
                LY_SAFE_BLOCK(success, responseObject);
            }
            [[self allTasks] removeObject:task];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            if (error) {
                [self handleCallbackWithError:error failure:failure];
            }
            [[self allTasks] removeObject:task];
        }];
    }
    
    if (requestMethod == LYRequestMethodDownload) {
        NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        
        sessionTask = [manager downloadTaskWithRequest:downloadRequest progress:^(NSProgress * _Nonnull downloadProgress) {
            LY_SAFE_BLOCK(transfeProgress, downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
            NSLog(@"下载进度------%.1f", 1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;// 关闭网络指示器
            });
            if (!saveToPath) {
                NSURL *downloadURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
                NSLog(@"下载默认保存路径-----%@", downloadURL);
                return [downloadURL URLByAppendingPathComponent:[response suggestedFilename]];
            } else {
                return [NSURL fileURLWithPath:saveToPath];
            }
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            [[self allTasks] removeObject:sessionTask];
            
            if (!error) {
                LY_SAFE_BLOCK(success, filePath.path);
            } else {
                [self handleCallbackWithError:error failure:failure];
            }
        }];
    }
    
    // 开启任务
    [sessionTask resume];
    
    if (sessionTask) {
        [[self allTasks] addObject:sessionTask];
    }
    
    return sessionTask;
}

#pragma mark - Private Method
+ (AFHTTPSessionManager *)manager {
    @synchronized (self) {
        // 只要不切换baseurl，就一直使用同一个session manager
        if (_sharedManager == nil || _isBaseURLChanged) {
            // 开启网络指示器
            [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
            
            AFHTTPSessionManager *manager = nil;;
            if ([self baseUrl] != nil) {
                manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:[self baseUrl]]];
            } else {
                manager = [AFHTTPSessionManager manager];
            }
            
            switch (_requestSerializerType) {
                    case LYRequestSerializerTypeJSON: {
                        manager.requestSerializer = [AFJSONRequestSerializer serializer];
                        break;
                    }
                    case LYRequestSerializerTypeHTTP: {
                        manager.requestSerializer = [AFHTTPRequestSerializer serializer];
                        break;
                    }
                default: {
                    break;
                }
            }
            
            switch (_responseSerializerType) {
                    case LYResponseSerializerTypeJSON: {
                        manager.responseSerializer = [AFJSONResponseSerializer serializer];
                        break;
                    }
                    case LYResponseSerializerTypeXMLParser: {
                        manager.responseSerializer = [AFXMLParserResponseSerializer serializer];
                        break;
                    }
                    case LYResponseSerializerTypeHTTP: {
                        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
                        break;
                    }
                default: {
                    break;
                }
            }
            
            manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
            
            for (NSString *key in _httpHeaders.allKeys) {
                if (_httpHeaders[key] != nil) {
                    [manager.requestSerializer setValue:_httpHeaders[key] forHTTPHeaderField:key];
                }
            }
            
            manager.responseSerializer.acceptableContentTypes = [NSSet setWithArray:@[@"application/json",
                                                                                      @"text/json",
                                                                                      @"text/javascript",
                                                                                      @"text/html",
                                                                                      @"text/plain",
                                                                                      @"text/xml",
                                                                                      @"application/zip",
                                                                                      @"image/*"]];
            
            manager.requestSerializer.timeoutInterval = _timeout;
            
            // 设置允许同时最大并发数量，过大容易出问题
            manager.operationQueue.maxConcurrentOperationCount = 3;
            _sharedManager = manager;
        }
    }
    
    return _sharedManager;
}

// 检测网络变化
+ (void)detectNetwork {
    // 获得网络监控的管理者
    AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager sharedManager];
    // 开启网络监测
    [reachabilityManager startMonitoring];
    // 设置网络状态改变后的处理
    [reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) { // 当网络状态改变了, 就会调用这个block
        switch (status) {
                case AFNetworkReachabilityStatusUnknown:            // 未知网络
                _networkStatus = LYNetworkStatusUnknown;
                NSLog(@"networkStatus-----未知网络");
                break;
                case AFNetworkReachabilityStatusNotReachable:       // 没有网络(断网)
                _networkStatus = LYNetworkStatusNotReachable;
                NSLog(@"networkStatus-----没有网络");
                break;
                case AFNetworkReachabilityStatusReachableViaWWAN:   // 手机自带网络(蜂窝网络)
                _networkStatus = LYNetworkStatusReachableViaWWAN;
                NSLog(@"networkStatus-----手机自带网络");
                break;
                case AFNetworkReachabilityStatusReachableViaWiFi:   // WiFi
                _networkStatus = LYNetworkStatusReachableViaWiFi;
                NSLog(@"networkStatus-----WiFi");
                break;
        }
    }];
}

+ (NSString *)absoluteUrlWithPath:(NSString *)path {
    if (path == nil || path.length == 0) {
        return @"";
    }
    
    if ([self baseUrl] == nil || [[self baseUrl] length] == 0) {
        return path;
    }
    
    NSString *absoluteUrl = path;
    
    if (![path hasPrefix:@"http://"] && ![path hasPrefix:@"https://"]) {
        if ([[self baseUrl] hasSuffix:@"/"]) {
            if ([path hasPrefix:@"/"]) {
                NSMutableString * mutablePath = [NSMutableString stringWithString:path];
                [mutablePath deleteCharactersInRange:NSMakeRange(0, 1)];
                absoluteUrl = [NSString stringWithFormat:@"%@%@", [self baseUrl], mutablePath];
            } else {
                absoluteUrl = [NSString stringWithFormat:@"%@%@", [self baseUrl], path];
            }
        } else {
            if ([path hasPrefix:@"/"]) {
                absoluteUrl = [NSString stringWithFormat:@"%@%@", [self baseUrl], path];
            } else {
                absoluteUrl = [NSString stringWithFormat:@"%@/%@", [self baseUrl], path];
            }
        }
    }
    return absoluteUrl;
}

+ (void)handleCallbackWithError:(NSError *)error failure:(LYResponseFailure)failure {
    if ([error code] == NSURLErrorCancelled) {
        NSLog(@"手动取消网络请求");
        if (_shouldCallbackOnCancelRequest) {
            LY_SAFE_BLOCK(failure, error);
        }
    } else {
        LY_SAFE_BLOCK(failure, error);
    }
}


#pragma mark - 请求前统一处理：如果是没有网络，则不论是GET请求还是POST请求，均无需继续处理
+ (BOOL)requestBeforeCheckNetWork {
    struct sockaddr zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sa_len = sizeof(zeroAddress);
    zeroAddress.sa_family = AF_INET;
    SCNetworkReachabilityRef defaultRouteReachability =
    SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
    if (!didRetrieveFlags) {
        printf("Error. Count not recover network reachability flags\n");
        return NO;
    }
    BOOL isReachable = flags & kSCNetworkFlagsReachable;
    BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
    BOOL isNetworkEnable = (isReachable && !needsConnection) ? YES : NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].networkActivityIndicatorVisible = isNetworkEnable; /*  网络指示器的状态： 有网络 ： 开  没有网络： 关  */
    });
    return isNetworkEnable;
}

#pragma mark - 拼接 POST 请求的网址
+ (NSString *)urlParametersToStringWithUrlStr:(NSString *)urlStr parameters:(NSDictionary *)parameters {
    if (!parameters) {
        return urlStr;
    }
    NSMutableArray *parts = [NSMutableArray array];
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id<NSObject> obj, BOOL *stop) {
        NSString *encodedKey = [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *encodedValue = [obj.description stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *part = [NSString stringWithFormat: @"%@=%@", encodedKey, encodedValue];
        [parts addObject: part];
    }];
    NSString *queryString = [parts componentsJoinedByString:@"&"];
    queryString =  queryString ? [NSString stringWithFormat:@"%@", queryString] : @"";
    NSString * pathStr =[NSString stringWithFormat:@"%@?%@", urlStr, queryString];
    return pathStr;
}

#pragma mark - 处理json格式的字符串中的换行符、回车符
+ (NSString *)deleteSpecialCodeWithStr:(NSString *)str {
    NSString *string = [str stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"\t" withString:@""];
//    string = [string stringByReplacingOccurrencesOfString:@" " withString:@""];
//    string = [string stringByReplacingOccurrencesOfString:@"(" withString:@""];
//    string = [string stringByReplacingOccurrencesOfString:@")" withString:@""];
    return string;
}

#pragma mark - Private Method

#pragma mark - MD5
+ (NSString *)md5StringFromString:(NSString *)string {
    NSParameterAssert(string != nil && [string length] > 0);
    
    const char *value = [string UTF8String];
    
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    
    return outputString;
}

@end
