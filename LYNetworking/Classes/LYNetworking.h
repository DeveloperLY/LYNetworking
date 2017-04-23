//
//  LYNetworking.h
//  LYNetworking
//
//  Created by LiuY on 16/11/27.
//  Copyright © 2016年 DeveloperLY. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 网络请求成功Block

 @param response 请求成功返回数据
 */
typedef void(^LYResponseSuccess)(id response);


/**
 网络请求失败Block

 @param error 请求错误返回的错误对象
 */
typedef void(^LYResponseFailure)(NSError *error);

/**
 *  网络数据传输进度
 *
 *  @param bytesProgress      已经传输数据大小
 *  @param totalBytesProgress 总共需要传输的数据大小
 */
typedef void(^LYTransfeProgress)(int64_t bytesProgress, int64_t totalBytesProgress);

/******************** 请求方式 ********************/
typedef NS_ENUM(NSInteger, LYRequestMethod) {
    LYRequestMethodGet,
    LYRequestMethodPost,
    LYRequestMethodUpload,
    LYRequestMethodDownload
};

/******************** 请求serializer类型 ********************/
typedef NS_ENUM(NSInteger, LYRequestSerializerType) {
    LYRequestSerializerTypeJSON  = 0,   // JSON （默认）
    LYRequestSerializerTypeHTTP  = 1,   // text/html
};

/******************** 响应serializer类型 ********************/
typedef NS_ENUM(NSInteger, LYResponseSerializerType) {
    LYResponseSerializerTypeJSON        = 0,    // JSON object type
    LYResponseSerializerTypeXMLParser   = 1,    // NSXMLParser type
    LYResponseSerializerTypeHTTP        = 2,    // NSData type （默认）
};

/******************** 请求优先级 ********************/
typedef NS_ENUM(NSInteger, LYRequestPriority) {
    LYRequestPriorityLow        = -4L,
    LYRequestPriorityDefault    = 0,
    LYRequestPriorityHigh       = 4,
};

/******************** 网络状态 ********************/
typedef NS_ENUM(NSInteger,  LYNetworkStatus) {
    LYNetworkStatusUnknown            = -1,   // 未知
    LYNetworkStatusNotReachable       = 0,    // 无连接
    LYNetworkStatusReachableViaWWAN   = 1,    // 蜂窝网络
    LYNetworkStatusReachableViaWiFi   = 2     // WiFi
};

/**
 *  不直接使用NSURLSessionDataTask,以减少对第三方的依赖
 */
typedef NSURLSessionTask LYURLSessionTask;

@interface LYNetworking : NSObject

/**
 *  设置网络 Bese URL
 *  eg: https://api.developerly.net 或者 http://127.0.0.1:8080
 *  通常只要在appDelegate中设置一次就可以，如果接口有多个服务器，可以调用 + (void)updateBeseURL: 方法
 *  @return beseURL
 */
+ (NSString *)baseUrl;
+ (void)updateBaseUrl:(NSString *)baseUrl;

/**
 *	设置请求超时时间，默认为10秒
 *
 *	@param timeout 超时时间
 */
+ (void)setTimeout:(NSTimeInterval)timeout;

/**
 *  配置请求格式，默认为JSON。如果请求的是XML/PLIST,需要调用该方法全局配置
 *
 *  @param requestSerializerType         请求格式。默认JSON
 *  @param responseSerializerType        响应格式。默认JSON·
 *  @param shouldAutoEncode              是否自定encode url 默认为NO
 *  @param shouldCallbackOnCancelRequest 当取消请求时，是否需要回调，默认为YES
 */
+ (void)configRequestSerializerType:(LYRequestSerializerType)requestSerializerType
             responseSerializerType:(LYResponseSerializerType)responseSerializerType
                shouldAutoEncodeUrl:(BOOL)shouldAutoEncode
            callbackOnCancelRequest:(BOOL)shouldCallbackOnCancelRequest;

/**
 *  配置公共的请求头，只调用一次即可，通常放在应用启动时配置
 *
 *  @param httpHeaders 只需要将与服务器约定的固定参数设置 如@{"client" : "iOS"}
 */
+ (void)configCommonHttpHeaders:(NSDictionary *)httpHeaders;

/**
 *  取消某个请求
 *  取消请求最好是引用接口返回的LYURLSessionTask对象，调用cancel方法
 *  如果不想引用对象，可以调用该方法取消某个请求
 *
 *  @param url URL，可以是URL，也可以是path(不包含baseurl)
 */
+ (void)cancelRequestWithURL:(NSString *)url;

/**
 *  取消所有请求
 */
+ (void)cancelAllRequest;

/******************** GET请求 ********************/

/**
 *  GET请求
 *
 *  @param urlStr  请求路径（不包含beseURL）
 *  @param isCache 是否需要缓存数据
 *  @param success 成功的回调
 *  @param failure 失败的回调
 *
 *  @return 返回LYURLSessionTask对象中有用于取消请求API
 */
+ (LYURLSessionTask *)getRequestURLStr:(NSString *)urlStr
                               isCache:(BOOL)isCache
                               success:(LYResponseSuccess)success
                               failure:(LYResponseFailure)failure;


/**
 *  GET请求
 *
 *  @param urlStr       请求路径（不包含beseURL）
 *  @param isCache      是否需要缓存数据
 *  @param parameters   get参数
 *  @param success      成功的回调
 *  @param failure      失败的回调
 *
 *  @return 返回LYURLSessionTask对象中有用于取消请求API
 */
+ (LYURLSessionTask *)getRequestURLStr:(NSString *)urlStr
                               isCache:(BOOL)isCache
                            parameters:(NSDictionary *)parameters
                               success:(LYResponseSuccess)success
                               failure:(LYResponseFailure)failure;

/**
 *  GET请求
 *
 *  @param urlStr       请求路径（不包含beseURL）
 *  @param isCache      是否需要缓存数据
 *  @param parameters   get参数
 *  @param progress     进度回调
 *  @param success      成功的回调
 *  @param failure      失败的回调
 *
 *  @return 返回LYURLSessionTask对象中有用于取消请求API
 */
+ (LYURLSessionTask *)getRequestURLStr:(NSString *)urlStr
                               isCache:(BOOL)isCache
                            parameters:(NSDictionary *)parameters
                              progress:(LYTransfeProgress)progress
                               success:(LYResponseSuccess)success
                               failure:(LYResponseFailure)failure;

/******************** POST请求 ********************/

/**
 *  POST请求
 *
 *  @param urlStr     请求路径（不包含beseURL）
 *  @param isCache    是否需要缓存
 *  @param parameters post参数
 *  @param success    成功的回调
 *  @param failure    失败的回调
 *
 *  @return 返回LYURLSessionTask对象中有用于取消请求API
 */
+ (LYURLSessionTask *)postRequestURLStr:(NSString *)urlStr
                                isCache:(BOOL)isCache
                             parameters:(NSDictionary *)parameters
                                success:(LYResponseSuccess)success
                                failure:(LYResponseFailure)failure;

/**
 *  POST请求
 *
 *  @param urlStr     请求路径（不包含beseURL）
 *  @param isCache    是否需要缓存
 *  @param parameters post参数
 *  @param progress   进度回调
 *  @param success    成功的回调
 *  @param failure    失败的回调
 *
 *  @return 返回LYURLSessionTask对象中有用于取消请求API
 */
+ (LYURLSessionTask *)postRequestURLStr:(NSString *)urlStr
                                isCache:(BOOL)isCache
                             parameters:(NSDictionary *)parameters
                               progress:(LYTransfeProgress)progress
                                success:(LYResponseSuccess)success
                                failure:(LYResponseFailure)failure;

#pragma mark - 上传单个文件
/**
 *  上传单个文件
 *
 *  @param urlStr           服务器地址 (不包含beseURL)
 *  @param fileData         上传的文件
 *  @param parameters       参数
 *  @param fileName         上传文件名字（带后缀）
 *  @param name             指定与上传文件相关联的名称，这个是由写后台接口的人员指定，如上传图片：imageFile
 *  @param mimeType         默认image/jpeg
 *  @param uploadProgress   上传进度
 *  @param success          上传成功的回调
 *  @param failure          上传失败的回调
 *
 *  @return 返回LYURLSessionTask对象中有用于取消请求API
 */
+ (LYURLSessionTask *)uploadDataWithURLStr:(NSString *)urlStr
                                parameters:(NSDictionary *)parameters
                                  fileData:(NSData *)fileData
                                      name:(NSString *)name
                                  fileName:(NSString *)fileName
                                  mimeType:(NSString *)mimeType
                            uploadProgress:(LYTransfeProgress)uploadProgress
                                   success:(LYResponseSuccess)success
                                   failure:(LYResponseFailure)failure;


#pragma mark - 下载文件
/**
 *  下载单个文件
 *
 *  @param urlStr           下载地址
 *  @param saveToPath       文件保存路径
 *  @param downloadProgress 下载进度回调
 *  @param success          下载成功回到
 *  @param failure          下载失败回调
 *
 *  @return 返回LYURLSessionTask对象中有用于取消请求API
 */
+ (LYURLSessionTask *)downloadWithURLStr:(NSString *)urlStr
                              saveToPath:(NSString *)saveToPath
                        downloadProgress:(LYTransfeProgress)downloadProgress
                                 success:(LYResponseSuccess)success
                                 failure:(LYResponseFailure)failure;

@end
