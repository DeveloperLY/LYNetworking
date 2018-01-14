//
//  ViewController.m
//  LYNetworking
//
//  Created by LiuY on 2017/4/22.
//  Copyright © 2017年 DeveloperLY. All rights reserved.
//

#import "ViewController.h"
#import <LYNetworking/LYNetworking.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIProgressView *getProgress;
@property (weak, nonatomic) IBOutlet UIProgressView *postProgress;
@property (weak, nonatomic) IBOutlet UIProgressView *uploadProgress;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgress;
@property (weak, nonatomic) IBOutlet UILabel *savePathLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [LYNetworking configRequestSerializerType:LYRequestSerializerTypeJSON responseSerializerType:LYResponseSerializerTypeJSON shouldAutoEncodeUrl:YES callbackOnCancelRequest:YES];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)getRequest:(UIButton *)sender {
    [LYNetworking getRequestURLStr:@"http://httpbin.org/get" isCache:NO parameters:@{@"show_env" : @1} progress:^(int64_t bytesProgress, int64_t totalBytesProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.getProgress.progress = bytesProgress/totalBytesProgress;
        });
    } success:^(id response) {
        NSLog(@"result = %@", response);
    } failure:^(NSError *error) {
        NSLog(@"error = %@", error);
    }];
}


- (IBAction)postRequest:(UIButton *)sender {
    [LYNetworking postRequestURLStr:@"http://httpbin.org/post" isCache:NO parameters:nil progress:^(int64_t bytesProgress, int64_t totalBytesProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.postProgress.progress = bytesProgress/totalBytesProgress;
        });
        
    } success:^(id response) {
        NSLog(@"result = %@", response);
    } failure:^(NSError *error) {
        NSLog(@"error = %@", error);
    }];
}

- (IBAction)putRequest:(UIButton *)sender {
    [LYNetworking putRequestURLStr:@"http://httpbin.org/put" parameters:nil success:^(id response) {
        NSLog(@"result = %@", response);
    } failure:^(NSError *error) {
        
    }];
}


- (IBAction)patchRequest:(UIButton *)sender {
    [LYNetworking patchRequestURLStr:@"http://httpbin.org/patch" parameters:nil success:^(id response) {
        NSLog(@"result = %@", response);
    } failure:^(NSError *error) {
        NSLog(@"error = %@", error);
    }];
}

- (IBAction)deleteRequest:(UIButton *)sender {
    [LYNetworking deleteRequestURLStr:@"http://httpbin.org/delete" parameters:nil success:^(id response) {
        NSLog(@"result = %@", response);
    } failure:^(NSError *error) {
        NSLog(@"error = %@", error);
    }];
}



- (IBAction)upload:(UIButton *)sender {
    [LYNetworking uploadDataWithURLStr:@"http://127.0.0.1:8080/upload" parameters:nil fileData:UIImageJPEGRepresentation([UIImage imageNamed:@"WeChat_1446115231"], 0.3) name:@"file" fileName:@"WeChat_1446115231.jpeg" mimeType:@"image/jpeg" uploadProgress:^(int64_t bytesProgress, int64_t totalBytesProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.uploadProgress.progress = bytesProgress/totalBytesProgress;
        });
    } success:^(id response) {
        NSLog(@"result = %@", response);
    } failure:^(NSError *error) {
        NSLog(@"error = %@", error);
    }];
}


- (IBAction)download:(UIButton *)sender {
    [LYNetworking downloadWithURLStr:@"http://httpbin.org/image/png" saveToPath:nil downloadProgress:^(int64_t bytesProgress, int64_t totalBytesProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.downloadProgress.progress = bytesProgress/totalBytesProgress;
        });
        
    } success:^(id response) {
        NSLog(@"result = %@", response);
    } failure:^(NSError *error) {
        NSLog(@"error = %@", error);
    }];
}


@end
