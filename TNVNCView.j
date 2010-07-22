/*  
 * TNNoVNCView.j
 *    
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


@import <AppKit/AppKit.j>

TNVNCCappuccinoStateNormal                  = @"normal";
TNVNCCappuccinoStateFailed                  = @"failed";
TNVNCCappuccinoStateFatal                   = @"fatal";
TNVNCCappuccinoStateDisconnected            = @"disconnected";
TNVNCCappuccinoStateLoaded                  = @"loaded";
TNVNCCappuccinoStatePassword                = @"password";



@implementation TNVNCView : CPView
{
    CPString    _host       @accessors(property=host);
    CPString    _port       @accessors(property=port);
    CPString    _password   @accessors(property=password);
    CPString    _state      @accessors(property=state);
    CPString    _message    @accessors(property=message);
    id          _delegate   @accessors(property=delegate);
    BOOL        _encrypted  @accessors(setter=setEncrypted:, getter=isEncrypted);
    BOOL        _trueColor  @accessors(setter=setTrueColor:, getter=isTrueColor);
    
    
    id          _DOMCanvas;
    id          _DOMClipboard;
    id          _oldResponder;
    

    
    CPTextField _fieldFocusTrick;
}

- (id)initWithFrame:(CPRect)aFrame
{
    if (self = [super initWithFrame:aFrame])
    {
        _host = nil;
        _port = 5900;
        _encrypted = NO;
        _trueColor = YES;
        _password = "";
        
        _fieldFocusTrick = [[CPTextField alloc] initWithFrame:CPRectMake(0,0,0,0)];
        [self addSubview:_fieldFocusTrick];
        
        var novnc_div               = document.createElement("div");
        novnc_div.id                = "vnc";
        
        var novnc_screen            = document.createElement("div");
        novnc_screen.id             = "VNC_screen"
        
        var novnc_canvas            = document.createElement("canvas");
        novnc_canvas.id             = "VNC_canvas";
        novnc_canvas.width          = "800px";
        novnc_canvas.height         = "600px";
        novnc_canvas.innerHTML      = "Canvas not supported.";
        novnc_canvas.style.border   = "3px solid #8F8F8F";
        novnc_canvas.style.display  = "block";
        // novnc_canvas.style.float    = "left";
        
        novnc_canvas.onmouseover    = function(e){
            [self focus];
        }
        
        novnc_canvas.onmouseout    = function(e){
            [self unfocus];
        }
        
        _DOMCanvas  = novnc_canvas;
        
        novnc_screen.appendChild(novnc_canvas);
        novnc_div.appendChild(novnc_screen);
        
        _DOMElement.appendChild(novnc_div);
    }
    
    return self;
}

- (void)setBackgroundImage:(CPString)anImagePath
{
    _DOMCanvas.style.backgroundImage = "url("+anImagePath+")";
}

- (IBAction)connect:(id)sender
{
    [self reset];
    RFB.load();
    RFB.setEncrypt(_encrypted);
    RFB.setTrueColor(_trueColor);
    
    RFB.setClipboardReceive(function(text){
        [[CPPasteboard generalPasteboard] setString:text forType:CPStringPboardType];
    });
    
    RFB.setUpdateState(function(state, msg){
        _state      = state;
        _message    = msg;
        if (_delegate && ([_delegate respondsToSelector:@selector(vncView:updateState:message:)]))
            [_delegate vncView:self updateState:state message:msg];
    });
    
    RFB.connect(_host, _port, _password);
}

- (IBAction)disconnect:(id)sender
{
    RFB.disconnect();
    [self reset];
}

- (void)setZoom:(int)aZoomFactor
{
    // _DOMCanvas.style.zoom = aZoomFactor + @"%";
    Canvas.rescale(aZoomFactor / 100)
}

- (float)zoom
{
    return Canvas.scale
}

- (void)reset
{
    [_fieldFocusTrick setStringValue:@""];
    
    _DOMCanvas.width          = "800px";
    _DOMCanvas.height         = "600px";
    
    RFB.init_vars();
}

- (CPRect)canvasSize
{
    return CPSizeMake(_DOMCanvas.width, _DOMCanvas.height);
}

- (CPRect)canvasZoom
{
    return Canvas.scale * 100;
}

- (void)focus
{
    _oldResponder = [[self window] firstResponder];
    [[self window] makeFirstResponder:_fieldFocusTrick];
    _DOMCanvas.focus();
    Canvas.focused = true;
    _DOMCanvas.style.border = "3px solid #A1CAE2";
}

- (void)unfocus
{
    [[self window] makeFirstResponder:_oldResponder];
    Canvas.focused = false;
    _DOMCanvas.style.border = "3px solid #8F8F8F";
}

- (IBAction)sendLocalPasteboard:(id)sender
{
    var data = [[CPPasteboard generalPasteboard] stringForType:CPStringPboardType];
    
    if (data)
        RFB.clipboardPasteFrom("test");
}

- (void)sendPassword:(CPString)aPassword
{
    RFB.sendPassword(aPassword);
    _password = aPassword;
}
@end

