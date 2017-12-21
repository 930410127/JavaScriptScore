//
//  ViewController.m
//  JSWeb
//
//  Created by mac on 2017/12/11.
//  Copyright © 2017年 Jess. All rights reserved.
//

#import "ViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "Person.h"

#import <objc/message.h>

#pragma mark -自定义协议(UILabelJSExport)
@protocol UILabelJSExport <JSExport>

@property (nonatomic,copy)NSString *text;

@end

#pragma mark - 通过JS对象的JS方法调用OC方法必须遵守JSExport协议
@protocol JSObjectExport <JSExport>

- (void)call;

JSExportAs(getCall, - (void)getCall:(NSString *)string);

@end

@interface ViewController ()<UIWebViewDelegate,JSObjectExport>

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@property(nonatomic,strong)JSContext *context;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSString *path = [[NSBundle mainBundle]pathForResource:@"index" ofType:@"html"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]];
   
    [self.webView loadRequest:request];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webView{
    NSString *kw = [self.webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByName('word')[0].value"];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView{
    NSString *title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    //获取js运行环境
    _context = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    //执行JS代码
    [_context evaluateScript:@"alert(1)"];
    //JS异常处理,OC不会处理JS的异常
    _context.exceptionHandler = ^(JSContext *context,JSValue *exceptionValue){
        NSLog(@"%@",exceptionValue);
    };
    
    _context[@"log"] = ^{
        NSLog(@"+++++++Begin Log+++++++");
        NSArray *args = [JSContext currentArguments];
        for (JSValue *jsVal in args) {
             NSLog(@"%@", jsVal);
        }
        
        JSValue *this = [JSContext currentThis];
         NSLog(@"this: %@",this);
    };
    
    __weak typeof(self)weakSelf = self;
    _context[@"callBack"] = ^{
        NSArray *args = [JSContext currentArguments];
        JSValue *value = args[0];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:value.toString preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        [alert addAction:action];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    };
    
    _context[@"tianbai"] = self;
    
    [self OCCallJSFunc];
    
    [self JSCallOCBlockWithNoneArguments];
    
    [self JSCallOCBlockWithArguments];
    
    [self jsCallOCCustomClass];
    
    [self jsCallOCSystemClass];
}

#pragma mark - OC调用JS方法
- (void)OCCallJSFunc{
    //创建JS运行环境
    JSContext *context = [[JSContext alloc]init];
    //JS代码
    NSString *js = @"function add(a,b) {return a+b}";
    //因为变量直接定义在JS中，所以可以直接通过JSContext获取，根据变量名获取，相当于字典的key
    [context evaluateScript:js];
    //只有先执行JS代码，才能获取变量
    JSValue *callBack = context[@"add"];
    JSValue *sum = [callBack callWithArguments:@[@10,@20]];
    NSInteger intsum = [sum toInt32];
    NSLog(@"intSum:%d",intsum);
}

#pragma mark -JS调用OC中不带参数的block
- (void)JSCallOCBlockWithNoneArguments{
    //创建JS运行环境
    JSContext *context = [[JSContext alloc]init];
    // 相当于在JS中定义一个叫eat的方法，eat的实现就是block中的实现，只要调用eat,就会调用block
    context[@"eat"] = ^{
        NSLog(@"吃了");
    };
    // JS执行代码，就会直接调用到block中
    NSString *jsCode = @"eat()";
    
    [context evaluateScript:jsCode];
}

#pragma mark -JS调用OC中带参数的block
- (void)JSCallOCBlockWithArguments{
    JSContext *context = [[JSContext alloc]init];
    // 还是一样的写法，会在JS中生成eat方法，只不过通过[JSContext currentArguments]获取JS执行方法时的参数
    context[@"eat"] = ^(){
        NSArray *argumnets = [JSContext currentArguments];
        NSLog(@"吃了%@和%@",argumnets[0],argumnets[1]);
    };
    NSString *jsCode = @"eat('面包','牛奶')";
    [context evaluateScript:jsCode];
}

//通过JS调用OC自定义类
#pragma mark - JS调用OC自定义类
/**
 * OC类必须遵守JSExport协议，只要遵守JSExport协议，JS才会生成这个类
 * 类里面有属性和方法，也要在JS中生成,JSExport本身不自带属性和方法，需要自定义一个协议，继承JSExport，在自己的协议中暴露需要在JS中用到的属性和方法
 * 自己的类只要继承自己的协议就好，JS就会自动生成类，包括自己协议中声明的属性和方法
 */
- (void)jsCallOCCustomClass{
    
    Person *person = [[Person alloc]init];
    person.name = @"yz";
    
    JSContext *context = [[JSContext alloc]init];
    
    // 会在JS中生成Person对象，并且拥有所有值,前提：Person对象必须遵守JSExport协议
    context[@"person"] = person;
    
    //执行JS代码
    //NSString *jsCode = @"person.play()";
     NSString *jsCode = @"person.playGame('德州扑克','晚上')";
    [context evaluateScript:jsCode];
}


#pragma mark - JS调用OC系统类
/**
 * 系统自带的类，想要通过JS调用怎么办，我们又没办法修改系统自带类的文件
 * 和调用自定义类一样，也要弄个自定义协议继承JSExport，描述需要暴露哪些属性（想要把系统类的哪些属性暴露，就在自己的协议声明）
 * 通过runtime,给类添加协议
 */
- (void)jsCallOCSystemClass{
    // 给系统类添加协议
    class_addProtocol([UILabel class], @protocol(UILabelJSExport));
    
    UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(50, 50, 100, 100)];
    [self.view addSubview:label];
    
    JSContext *context = [[JSContext alloc]init];
    //在JS中生成label对象,并且用label引用
    context[@"label"] = label;
    
    //利用JS给label设置文本
    NSString *jsCode = @"label.text = 'oh,myGod'";
    [context evaluateScript:jsCode];
}

- (void)call{
    NSLog(@"call");
    //成功调用OC方法之后，利用OC调用JS方法实现把callback内容回传给web
    JSValue *callBack = _context[@"callBack"];
    [callBack callWithArguments:@[@"唤起本地OC回调web成功"]];
}

- (void)getCall:(NSString *)string{
    NSLog(@"Get:%@",string);
    // 成功回调JavaScript的方法Callback
    JSValue *callback = _context[@"alertCallBack"];
    [callback callWithArguments:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
