@STATIC;1.0;i;17;Resources/util.jsi;19;Resources/base64.jsi;16;Resources/des.jsi;19;Resources/canvas.jsi;16;Resources/vnc.jsi;36;Resources/web-socket-js/swfobject.jsi;35;Resources/web-socket-js/FABridge.jsi;37;Resources/web-socket-js/web_socket.jsi;11;TNVNCView.jt;600;objj_executeFile("Resources/util.js", YES);;
objj_executeFile("Resources/base64.js", YES);;
objj_executeFile("Resources/des.js", YES);;
objj_executeFile("Resources/canvas.js", YES);;
objj_executeFile("Resources/vnc.js", YES);;
if (!window.WebSocket)
{
    WebSocket__swfLocation = "/Frameworks/NOVNCCappuccino/Resources/web-socket-js/WebSocketMain.swf";
    objj_executeFile("Resources/web-socket-js/swfobject.js", YES);;
    objj_executeFile("Resources/web-socket-js/FABridge.js", YES);;
    objj_executeFile("Resources/web-socket-js/web_socket.js", YES);;
}
objj_executeFile("TNVNCView.j", YES);;

