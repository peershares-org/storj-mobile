//
//  SyncModule.m
//  StorjMobile
//
//  Created by Barterio on 3/28/18.
//  Copyright © 2018 Storj. All rights reserved.
//

#import "SyncModule.h"

#define RESOLVER "RCTresolver"
#define REJECTER "RCTrejecter"

@implementation SyncModule

RCT_EXPORT_MODULE(SyncModuleIOS);

@synthesize _database;
@synthesize _bucketRepository, _fileRepository, _uploadFileRepository;

-(FMDatabase *) database{
  if(!_database){
    _database = [[DatabaseFactory getSharedDatabaseFactory] getSharedDb];
  }
  return _database;
}

-(BucketRepository *)bucketRepository{
  if(!_bucketRepository){
    _bucketRepository = [[BucketRepository alloc] initWithDB:[self database]];
  }
  return _bucketRepository;
}

-(FileRepository *) fileRepository{
  if(!_fileRepository){
    _fileRepository = [[FileRepository alloc] initWithDB:[self database]];
  }
  return _fileRepository;
}

-(UploadFileRepository *) uploadFileRepository{
  if(!_uploadFileRepository){
    _uploadFileRepository = [[UploadFileRepository alloc] initWithDB:[self database]];
  }
  return _uploadFileRepository;
}

RCT_REMAP_METHOD(listBuckets,
                 listBucketsWithSortingMode: (NSString *) sortingMode
                 withResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  NSLog(@"SyncModule: listBuckets");
  [MethodHandler
   invokeParallelWithParams:@{@RESOLVER: resolver,
                               @REJECTER : rejecter}
   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
     
     NSArray *bucketDbos = [NSArray arrayWithArray:
                            [sortingMode isEqualToString:@"name"]
                              ? [[self bucketRepository] getAllWithOrderByColumn:sortingMode order:YES]
                              : [[self bucketRepository] getAll]];
     
     int length = bucketDbos.count;
     NSMutableArray<BucketModel *> * bucketModels = [NSMutableArray arrayWithCapacity:length];
     for (int i = 0; i < length; i++){
       bucketModels[i] = [bucketDbos[i] toModel];
     }
     SingleResponse *response = [SingleResponse
                                 successSingleResponseWithResult:
                                 [DictionaryUtils convertToJsonWithArray:bucketModels]];
     RCTPromiseResolveBlock resolve = param[@RESOLVER];
     resolve([response toDictionary]);
   }];
}

RCT_REMAP_METHOD(listFiles,
                 listFilesFromBucket: (NSString *) bucketId
                 withSortingMode: (NSString *) sortingMode
                 withResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  [MethodHandler
   invokeParallelWithParams:@{@RESOLVER: resolver,
                               @REJECTER : rejecter}
   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
     
     NSArray <FileDbo *> * fileDbos = [sortingMode isEqualToString:@"name"]
     ? [NSArray arrayWithArray: [[self fileRepository] getAllFromBucket: bucketId
                                                          orderByColumn: sortingMode
                                                             descending: YES]]
     : [NSArray arrayWithArray:[[self fileRepository] getAllFromBucket:bucketId]];
     
     int length = fileDbos.count;
     NSMutableArray <FileModel *> * fileModels = [NSMutableArray arrayWithCapacity:length];
     for(int i = 0; i < length; i++){
       fileModels[i] = [[FileModel alloc] initWithFileDbo:fileDbos[i]];
     }

     SingleResponse *response = [SingleResponse
                                 successSingleResponseWithResult:
                                 [DictionaryUtils convertToJsonWithArray:fileModels]];
     RCTPromiseResolveBlock resolve = param[@RESOLVER];
     resolve([response toDictionary]);
   }];
}

RCT_REMAP_METHOD(listAllFiles,
                 listAllFilesBySortingMode: (NSString *) sortingMode
                 withResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter) {
  [MethodHandler
   invokeParallelWithParams:@{@RESOLVER: resolver,
                               @REJECTER : rejecter}
   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
     NSArray<FileDbo *> *fileDbos = [sortingMode isEqualToString:@"name"]
     ? [[self fileRepository] getAllWithOrderByColumn:sortingMode order:YES]
     : [[self fileRepository] getAll];
     int length = fileDbos.count;
     NSMutableArray *fileModels = [NSMutableArray arrayWithCapacity: length];
     for(int i = 0; i < length; i++){
       fileModels[i] = [[FileModel alloc] initWithFileDbo:fileDbos[i]];
     }
     RCTPromiseResolveBlock resolve = param[@RESOLVER];
     resolve([[SingleResponse successSingleResponseWithResult:
               [DictionaryUtils convertToJsonWithArray:fileModels]]toDictionary] );
   }];
}

RCT_REMAP_METHOD(listUploadingFiles,
                 listUploadingFilesWithBucketId: (NSString *) bucketId
                 withResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  [MethodHandler
   invokeParallelWithParams:@{@RESOLVER: resolver,
                               @REJECTER : rejecter}
   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
     NSArray <UploadFileDbo *> *ufileDbos = [NSArray arrayWithArray:[[self uploadFileRepository]
                                                                     getAll]];
     int length = ufileDbos.count;
     NSMutableArray <UploadFileModel *> *fileModels = [NSMutableArray arrayWithCapacity:length];
     for (int i = 0; i < length; i++) {
       fileModels[i] = [[UploadFileModel alloc] initWithUploadFileDbo:ufileDbos[i]];
     }
     SingleResponse *response = [SingleResponse successSingleResponseWithResult:
                                 [DictionaryUtils convertToJsonWithArray:fileModels]];
     RCTPromiseResolveBlock resolve = param[@RESOLVER];
     resolve([response toDictionary]);
   }];
}

RCT_REMAP_METHOD(getUploadingFile, getUploadingFileWithFileHandle: (NSString *) fileHandle
                 WithResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  [MethodHandler
   invokeParallelWithParams:@{@RESOLVER: resolver,
                               @REJECTER : rejecter}
   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
     RCTPromiseResolveBlock resolve = param[@RESOLVER];
     if(!fileHandle){
       SingleResponse *response = [SingleResponse errorResponseWithMessage:@"invalid file handle"];
       resolve([response toDictionary]);
       return;
     }
     UploadFileModel *uploadingFileModel = [[self uploadFileRepository] getByFileId:fileHandle];
     SingleResponse *response;
     if(!uploadingFileModel){
       response = [SingleResponse errorResponseWithMessage:@"Uploading file not found"];
     } else {
       response = [SingleResponse successSingleResponseWithResult:
                   [DictionaryUtils convertToJsonWithDictionary:
                    [uploadingFileModel toDictionaryProgress]]];
     }
     resolve([response toDictionary]);
   }];
}

RCT_REMAP_METHOD(listSettings,
                 listSettingsWithSettingsId: (NSString *) settingsId
                 withResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  resolver(@[@{}]);
}

RCT_REMAP_METHOD(getFile,
                 getFileWithFileId: (NSString *) fileId
                 WithResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  [MethodHandler
   invokeParallelWithParams:@{@RESOLVER: resolver,
                               @REJECTER : rejecter}
   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
     RCTPromiseResolveBlock resolve = param[@RESOLVER];
     if(!fileId){
       SingleResponse *errorResponse = [SingleResponse errorResponseWithMessage:@"Invalid fileId"];
       resolve([errorResponse toDictionary]);
       return;
     }
     FileDbo *fileDbo = [[self fileRepository] getByFileId:fileId];
     SingleResponse *response;
     if(!fileDbo){
       response = [SingleResponse errorResponseWithMessage:@"File Not Found"];
     } else {
       FileModel *fileModel = [[FileModel alloc] initWithFileDbo:fileDbo];
       NSDictionary *fileModelDict = [fileModel toDictionary];
       response = [SingleResponse successSingleResponseWithResult:[DictionaryUtils
                                                                   convertToJsonWithDictionary:
                                                                   fileModelDict]];
     }
     resolve([response toDictionary]);
   }];
}

RCT_REMAP_METHOD(updateBucketStarred,
                 updateBucketStarredWithBucketId: (NSString *) bucketId
                 starredFlag:(BOOL) isStarred
                 WithResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  [MethodHandler
   invokeParallelWithParams:@{@RESOLVER: resolver,
                               @REJECTER : rejecter}
   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
     RCTPromiseResolveBlock resolve = param[@RESOLVER];
     resolve([[[self bucketRepository] updateById:bucketId starred:isStarred] toDictionary]);
   }];
}

RCT_REMAP_METHOD(updateFileStarred,
                 updateFileStarredWithBucketId: (NSString *) fileId
                 starredFlag:(BOOL) isStarred
                 WithResolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  [MethodHandler
   invokeParallelWithParams:@{@RESOLVER: resolver,
                               @REJECTER : rejecter}
   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
     RCTPromiseResolveBlock resolve = param[@RESOLVER];
     resolve([[[self fileRepository] updateById:fileId starred:isStarred] toDictionary]);
   }];
}

RCT_REMAP_METHOD(checkFile,
                 checkFileWithFileId: (NSString *) fileID localPath: (NSString *) localPath esolver: (RCTPromiseResolveBlock) resolver
                 andRejecter: (RCTPromiseRejectBlock) rejecter){
  
  if(!localPath) {
    resolver([[Response errorResponseWithMessage:@"Error: Path is null"] toDictionary]);
    return;
  }
  
  BOOL isDirectory;
  BOOL isFileExists = [[NSFileManager defaultManager] fileExistsAtPath:localPath
                                                           isDirectory:&isDirectory];
  NSLog(@"Is file Exists: %hhd, isDir: %hhd", isFileExists, isDirectory);
  if(!isFileExists || isDirectory) {
    Response *updateResponse = [[self _fileRepository] updateById:fileID
                                                    downloadState:0
                                                       fileHandle:0
                                                          fileUri:nil];
    if([updateResponse isSuccess]){
      NSLog(@"File entry updated successfully");
    } else {
      NSLog(@"Error while updating file entry");
    }
    
    resolver([[Response errorResponseWithMessage:@"File has been removed from file system."] toDictionary]);
    return;
  }
  resolver([[Response successResponse] toDictionary]);
}


//WithResolver: (RCTPromiseResolveBlock) resolver
//andRejecter: (RCTPromiseRejectBlock) rejecter){
//  [MethodHandler
//   invokeParallelWithParams:@{@RESOLVER: resolver,
//                               @REJECTER : rejecter}
//   andMethodHandlerBlock:^(NSDictionary * _Nonnull param) {
//
//   }];
//}

@end
