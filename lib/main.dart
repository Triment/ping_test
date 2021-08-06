import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:device_info/device_info.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';
//import 'ping.dart';
void main() {
  runApp(MyApp());
}

void checkoutExistFolder(String path){
  var dir = Directory('/sdcard/ping日志文件');
  if (!dir.existsSync()){
    dir.createSync(recursive: false);
  }
}

void timedWork(SendPort port){
  ReceivePort rp = new ReceivePort();
  SendPort sp = rp.sendPort;
  rp.listen((message) {
    print('这是主isolate发送的消息${message}');
  });
  port.send([0,sp]);//0 表示发送通信端口
  var framTime = [19,20,21,22,23,0];
  var currentTime = 19;//
  while(true){
    print('当前事件${DateTime.now().toLocal().hour}');
    var currTmpTime = DateTime.now().toLocal().hour;
    print(framTime.any((element) => currTmpTime==element));
    if (framTime.any((element) => currTmpTime==element)){
      if(currentTime != currTmpTime){
        port.send([1, true]);
        currentTime = currentTime;
      }
      
    }
    sleep(Duration(seconds: 60));
  }
}



class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ping测试工具',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'ping工具'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}
class PingInterface {
  const PingInterface(Ping instance, String ip): this.instance = instance, this.ip = ip;
  final Ping instance;
  final String ip; 
}
class _MyHomePageState extends State<MyHomePage> {
  String guid = '';//唯一标识符
  bool start = false;//开始停止服务
  String newIp = '';//新IP
  List<PingInterface> listOfIp = [];//ping的服务器列表
  String currentState = '';//显示当下状态
  String serverIp = '';//上传服务器IP
  String serverRes = '';
  String device_code = '';
  String wifi_status = '';
  String generate_time = '';
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getWifiInfo();
    requestPermission();
  }
  void requestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.locationAlways,
      Permission.locationWhenInUse,
      Permission.manageExternalStorage,
      Permission.mediaLibrary,
      Permission.storage
    ].request();
    if(statuses[Permission.location] == PermissionStatus.granted){
      getWifiInfo();
    } else {
      Fluttertoast.showToast(msg: "未赋予位置权限");
    }
    if(statuses[Permission.storage] != PermissionStatus.granted){
      Fluttertoast.showToast(msg: "未赋予储存权限，无法生成日志文件");
    }
  }
  void getWifiInfo() async{
    var file = File('/sdcard/ping日志文件/test.txt');
    file.createSync();
    var handler=file.openWrite(mode: FileMode.writeOnlyAppend);
    file.writeAsStringSync("hello");
    handler.close();
    var code = (await DeviceInfoPlugin().androidInfo).product;
    var status = await NetworkInfo().getWifiName();
    setState(() {
      device_code = code ;
      wifi_status = status == null ? "请前往设置为本应用授予位置权限": status;
    });
    //await (NetworkInfo().toString());
  }

  void startPing() async{
    ReceivePort mainRp = new ReceivePort();
    SendPort mainsp = mainRp.sendPort;
    Isolate isl = await Isolate.spawn(timedWork, mainsp); 
    mainsp.send("hello");
    mainRp.listen((message) {
      if(message[0]==1){
        if (message![1]==true){
          print('子线程发来消息');
          for (var p in listOfIp){
            p.instance.stream.listen((event) async {
              setState(() {
                currentState = event.response.toString();
                generate_time = DateTime.now().toString();
              });
              
              var file = File('/sdcard/ping日志文件/【${wifi_status}】-toPing-<${p.ip}>-${DateTime.now().hour}.txt');
              if (!file.existsSync())
                file.createSync();
              if(event.error!=null){
                file.writeAsStringSync('req:${event.response!.seq} ping失败\n', mode: FileMode.writeOnlyAppend);
              } else {
                var lineData = '当前时间: ${DateTime.now().toLocal().toString()} 输入地址: ${p.ip} 真实ip: ${event.response!.ip} wifi: ${wifi_status} 延迟: ${event.response!.time!.inMilliseconds}\n' ;
                file.writeAsStringSync(lineData,mode: FileMode.writeOnlyAppend);
              }
              if (serverIp == '') return;
              var res = await http.post(Uri.parse('http://${serverIp}/upload'),body: {
                'req': event.response!.seq.toString(),
                'ttl': event.response!.ttl.toString(),
                'times': event.response!.time.toString(),
                'guid': guid,
                'device': device_code,
                'wifi_name': wifi_status,
                'generate_time': DateTime.now()
              });
              setState(() {
                serverRes = res.body;
              });
            });
            setState(() {
                start = true;
            });
          }
        }
      }
    });
  }
  void  changeStart  () async {//改变开始状态
  checkoutExistFolder('');
  //检测是否有ip
  getWifiInfo();
    if (listOfIp.length <= 0){
      return;
    }
    var now = DateTime.now();
    print(now);
    if (start){
      for (var p in listOfIp){
        p.instance.stop();
      }
      setState(() {
          start = false;
          listOfIp = [];
      });
      print("change");
    } else {
      startPing();
    }
  }
  void addIp(){
    if (newIp!=''&& newIp != listOfIp.firstWhere((element) => element.ip == newIp,orElse: () => PingInterface(Ping(''), '')).ip){
      setState(() {
        listOfIp.add(PingInterface(Ping(newIp,count: 500),newIp));
      });
    } else {
      Fluttertoast.showToast(msg: 'ip已存在或输入框为空');
    }
  }

  void saveData(){
    //写入本地
    //上传服务器
    final now = DateTime.now();
    var year = now.year;
    var mouth = now.month;
    var day = now.day;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('bata版本,如有异常联系IT', style: TextStyle(color: Colors.greenAccent, fontSize: 20.0, fontWeight: FontWeight.bold),),
            Text('设备型号: ${device_code}'),
            Text('wifi: ${wifi_status}'),
            for (var i in listOfIp) Text(i.ip),//显示ip列表
            Text(start.toString()),
            TextField(
              decoration: const InputDecoration(
                labelText: '唯一标识符（身份识别id 暂不可用）'
              ),
            //   onChanged: (str)=>setState((){
            //   guid = str;
            // }),
              onChanged: (str)=>{
                Fluttertoast.showToast(msg: '功能开发中，暂时不可用')
              },
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'ping服务器地址'
              ),
              onChanged: (str){
                setState(() {
                  newIp = str;
                });
              },
            ),
            TextButton(onPressed: addIp, child: Text('添加ip')),//添加ip到列表
            TextField(
              decoration: const InputDecoration(
                labelText: '服务器上传地址（可选）暂不可用'
            ),
            onChanged: (str)=>{
              Fluttertoast.showToast(msg: '功能开发中，暂时不可用')
              // setState(()=>{
              //   serverIp = str
              // })
            },
            ),
            TextButton(
              onPressed: changeStart, child: Text(start? '停止':'开始')),
            Text(start? '已开始': '点击开始进行测试'),
            Text(currentState),
            Text(serverIp),
            Text(serverRes),
            Text(generate_time)
          ],
        ),
      )
    );
  }
}
