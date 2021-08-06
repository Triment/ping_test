import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
class PingClient extends StatefulWidget {
  const PingClient({ Key? key, required this.ip }) : super(key: key);
  final String ip;
  @override
  _PingClientState createState() => _PingClientState();
}

class _PingClientState extends State<PingClient> {
  late Ping _ping;
  String txt = '';
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _ping = Ping(widget.ip, count: 1000);
    this.start();
  }
  void start() async {
    _ping.stream.listen((event) {
      setState(() {
        txt = event.response.toString();
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    return Text(txt);
  }
}

