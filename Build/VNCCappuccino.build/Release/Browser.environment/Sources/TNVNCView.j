@STATIC;1.0;I;15;AppKit/AppKit.jt;2288;
objj_executeFile("AppKit/AppKit.j",NO);
var _1=objj_allocateClassPair(CPView,"TNVNCView"),_2=_1.isa;
class_addIvars(_1,[new objj_ivar("_host"),new objj_ivar("_port"),new objj_ivar("_password"),new objj_ivar("_encrypted"),new objj_ivar("_trueColor"),new objj_ivar("_DOMCanvas")]);
objj_registerClassPair(_1);
class_addMethods(_1,[new objj_method(sel_getUid("host"),function(_3,_4){
with(_3){
return _host;
}
}),new objj_method(sel_getUid("setHost:"),function(_5,_6,_7){
with(_5){
_host=_7;
}
}),new objj_method(sel_getUid("port"),function(_8,_9){
with(_8){
return _port;
}
}),new objj_method(sel_getUid("setPort:"),function(_a,_b,_c){
with(_a){
_port=_c;
}
}),new objj_method(sel_getUid("password"),function(_d,_e){
with(_d){
return _password;
}
}),new objj_method(sel_getUid("setPassword:"),function(_f,_10,_11){
with(_f){
_password=_11;
}
}),new objj_method(sel_getUid("isEncrypted"),function(_12,_13){
with(_12){
return _encrypted;
}
}),new objj_method(sel_getUid("setEncrypted:"),function(_14,_15,_16){
with(_14){
_encrypted=_16;
}
}),new objj_method(sel_getUid("isTrueColor"),function(_17,_18){
with(_17){
return _trueColor;
}
}),new objj_method(sel_getUid("setTrueColor:"),function(_19,_1a,_1b){
with(_19){
_trueColor=_1b;
}
}),new objj_method(sel_getUid("initWithFrame:"),function(_1c,_1d,_1e){
with(_1c){
if(_1c=objj_msgSendSuper({receiver:_1c,super_class:objj_getClass("TNVNCView").super_class},"initWithFrame:",_1e)){
_host=nil;
_port=5900;
_encrypted=NO;
_trueColor=YES;
_password="";
var _1f=document.createElement("div");
_1f.id="vnc";
_1f.width="100%";
_1f.height="100%";
var _20=document.createElement("div");
_20.id="VNC_screen";
_20.width="100%";
_20.height="100%";
var _21=document.createElement("canvas");
_21.id="VNC_canvas";
_21.width="0px";
_21.height="0px";
_21.innerHTML="Canvas not supported.";
_DOMCanvas=_21;
_20.appendChild(_21);
_1f.appendChild(_20);
_DOMElement.appendChild(_1f);
}
return _1c;
}
}),new objj_method(sel_getUid("connect:"),function(_22,_23,_24){
with(_22){
RFB.load();
RFB.connect(_host,_port,_password,_encrypted,_trueColor);
}
}),new objj_method(sel_getUid("disconnect:"),function(_25,_26,_27){
with(_25){
RFB.disconnect();
}
}),new objj_method(sel_getUid("setZoom:"),function(_28,_29,_2a){
with(_28){
_DOMCanvas.style.zoom=_2a+"%";
}
})]);
