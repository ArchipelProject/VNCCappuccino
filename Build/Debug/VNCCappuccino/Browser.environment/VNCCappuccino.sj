@STATIC;1.0;p;11;TNVNCView.jt;3520;@STATIC;1.0;I;15;AppKit/AppKit.jt;3481;objj_executeFile("AppKit/AppKit.j", NO);
{var the_class = objj_allocateClassPair(CPView, "TNVNCView"),
meta_class = the_class.isa;class_addIvars(the_class, [new objj_ivar("_host"), new objj_ivar("_port"), new objj_ivar("_password"), new objj_ivar("_encrypted"), new objj_ivar("_trueColor"), new objj_ivar("_DOMCanvas")]);
objj_registerClassPair(the_class);
class_addMethods(the_class, [new objj_method(sel_getUid("host"), function $TNVNCView__host(self, _cmd)
{ with(self)
{
return _host;
}
},["id"]),
new objj_method(sel_getUid("setHost:"), function $TNVNCView__setHost_(self, _cmd, newValue)
{ with(self)
{
_host = newValue;
}
},["void","id"]),
new objj_method(sel_getUid("port"), function $TNVNCView__port(self, _cmd)
{ with(self)
{
return _port;
}
},["id"]),
new objj_method(sel_getUid("setPort:"), function $TNVNCView__setPort_(self, _cmd, newValue)
{ with(self)
{
_port = newValue;
}
},["void","id"]),
new objj_method(sel_getUid("password"), function $TNVNCView__password(self, _cmd)
{ with(self)
{
return _password;
}
},["id"]),
new objj_method(sel_getUid("setPassword:"), function $TNVNCView__setPassword_(self, _cmd, newValue)
{ with(self)
{
_password = newValue;
}
},["void","id"]),
new objj_method(sel_getUid("isEncrypted"), function $TNVNCView__isEncrypted(self, _cmd)
{ with(self)
{
return _encrypted;
}
},["id"]),
new objj_method(sel_getUid("setEncrypted:"), function $TNVNCView__setEncrypted_(self, _cmd, newValue)
{ with(self)
{
_encrypted = newValue;
}
},["void","id"]),
new objj_method(sel_getUid("isTrueColor"), function $TNVNCView__isTrueColor(self, _cmd)
{ with(self)
{
return _trueColor;
}
},["id"]),
new objj_method(sel_getUid("setTrueColor:"), function $TNVNCView__setTrueColor_(self, _cmd, newValue)
{ with(self)
{
_trueColor = newValue;
}
},["void","id"]), new objj_method(sel_getUid("initWithFrame:"), function $TNVNCView__initWithFrame_(self, _cmd, aFrame)
{ with(self)
{
    if (self = objj_msgSendSuper({ receiver:self, super_class:objj_getClass("TNVNCView").super_class }, "initWithFrame:", aFrame))
    {
        _host = nil;
        _port = 5900;
        _encrypted = NO;
        _trueColor = YES;
        _password = "";
        var novnc_div = document.createElement("div");
        novnc_div.id = "vnc";
        novnc_div.width = "100%";
        novnc_div.height = "100%";
        var novnc_screen = document.createElement("div");
        novnc_screen.id = "VNC_screen"
        novnc_screen.width = "100%";
        novnc_screen.height = "100%";
        var novnc_canvas = document.createElement("canvas");
        novnc_canvas.id = "VNC_canvas";
        novnc_canvas.width = "0px";
        novnc_canvas.height = "0px";
        novnc_canvas.innerHTML = "Canvas not supported.";
        _DOMCanvas = novnc_canvas;
        novnc_screen.appendChild(novnc_canvas);
        novnc_div.appendChild(novnc_screen);
        _DOMElement.appendChild(novnc_div);
    }
    return self;
}
},["id","CPRect"]), new objj_method(sel_getUid("connect:"), function $TNVNCView__connect_(self, _cmd, sender)
{ with(self)
{
    RFB.load();
    RFB.connect(_host, _port, _password, _encrypted, _trueColor);
}
},["IBAction","id"]), new objj_method(sel_getUid("disconnect:"), function $TNVNCView__disconnect_(self, _cmd, sender)
{ with(self)
{
    RFB.disconnect();
}
},["IBAction","id"]), new objj_method(sel_getUid("setZoom:"), function $TNVNCView__setZoom_(self, _cmd, aZoomFactor)
{ with(self)
{
    _DOMCanvas.style.zoom = aZoomFactor + "%";
}
},["void","int"])]);
}

p;15;VNCCappuccino.jt;869;@STATIC;1.0;i;17;Resources/util.jsi;19;Resources/base64.jsi;16;Resources/des.jsi;19;Resources/canvas.jsi;16;Resources/vnc.jsi;36;Resources/web-socket-js/swfobject.jsi;35;Resources/web-socket-js/FABridge.jsi;37;Resources/web-socket-js/web_socket.jsi;11;TNVNCView.jt;600;objj_executeFile("Resources/util.js", YES);;
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

e;