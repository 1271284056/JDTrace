//
//  ViewController.m
//  TraceDemo
//
//

#import "ViewController.h"
#include <stdint.h>
#include <stdio.h>
#include <sanitizer/coverage_interface.h>
#import <dlfcn.h>
#import <libkern/OSAtomic.h>
#import "TraceDemo-Swift.h"

@interface ViewController ()
@property(nonatomic, assign) int age;

@end

@implementation ViewController
/*
 1 打开link map看输出方法
 2 other c flags里面添加
 3 -fsanitize-coverage=func,trace-pc-guard
 4 生成demo.order文件后,删掉这一行
 5 把文件添加到根目录,build setting - order files里加上./demo.order
 6 然后打开link map看输出方法顺序,二进制重拍就完成了
 */
+(void)load
{
    [SwiftTest swiftTest];
    block();
}

void(^block)(void) = ^(void){
    
    NSLog(@"block函数执行！");
};

void testCFunc() {
    printf("1234");
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    testCFunc();
    self.age = 10;
//    [self creatOrderFile];
    // Do any additional setup after loading the view.
}

//定义原子队列
static OSQueueHead symbolList = OS_ATOMIC_QUEUE_INIT;
//定义符号结构体
typedef struct {
    void * pc;
    void * next;
} SYNode;



//里面反应了项目中符号的个数 clang插桩 给起始位置 start 结束stop
void __sanitizer_cov_trace_pc_guard_init(uint32_t *start,
                                                    uint32_t *stop) {
  static uint64_t N;
  if (start == stop || *start) return;
//  printf("INIT: %p %p\n", start, stop);
  for (uint32_t *x = start; x < stop; x++)
    *x = ++N;
}


//HOOK一切的回调函数！！
void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    //内部的返回地址  调用者的方法地址
    void *PC = __builtin_return_address(0);
    //创建结构体
    SYNode * node = malloc(sizeof(SYNode));
    *node = (SYNode){PC,NULL};
    //结构体入栈 next存下一个节点的地址
    OSAtomicEnqueue(&symbolList, node, offsetof(SYNode, next));
    
}


//生成order文件！！
-(void)creatOrderFile
{
    //定义数组
    NSMutableArray<NSString *> * symbleNames = [NSMutableArray array];
    
    while (YES) {//循环体内！进行了拦截！！
        SYNode * node = OSAtomicDequeue(&symbolList, offsetof(SYNode,next));
        
        if (node == NULL) {
            break;
        }
        
        Dl_info info;
        dladdr(node->pc, &info);
        NSString * name = @(info.dli_sname);//转字符串
        //给函数名称添加 _
        BOOL isObjc = [name hasPrefix:@"+["] || [name hasPrefix:@"-["];
        NSString * symbolName = isObjc ? name : [@"_" stringByAppendingString:name];
        [symbleNames addObject:symbolName];
          
    }
    //反向遍历数组
//    symbleNames = (NSMutableArray<NSString *> *)[[symbleNames reverseObjectEnumerator] allObjects];
//    NSLog(@"%@",symbleNames);
    NSEnumerator * em = [symbleNames reverseObjectEnumerator];
    NSMutableArray * funcs = [NSMutableArray arrayWithCapacity:symbleNames.count];
    NSString * name;
    while (name = [em nextObject]) {
        if (![funcs containsObject:name]) {//数组没有name
            [funcs addObject:name];
        }
    }
    //去掉自己！
    [funcs removeObject:[NSString stringWithFormat:@"%s",__func__]];
    
    //写入文件
    //1.编程字符串
    NSString * funcStr = [funcs componentsJoinedByString:@"\n"];
    NSString * filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"demo.order"];
    NSData * file = [funcStr dataUsingEncoding:NSUTF8StringEncoding];
    
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:file attributes:nil];
    
    NSLog(@"%@ \n  %@",funcStr , filePath);
}





@end
