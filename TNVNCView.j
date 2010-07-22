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
TNVNCCappuccinoStateSecurityResult          = @"SecurityResult";



@implementation TNVNCView : CPView
{
    BOOL        _encrypted  @accessors(setter=setEncrypted:, getter=isEncrypted);
    BOOL        _trueColor  @accessors(setter=setTrueColor:, getter=isTrueColor);
    CPString    _host       @accessors(property=host);
    CPString    _message    @accessors(property=message);
    CPString    _oldState   @accessors(property=oldState);
    CPString    _password   @accessors(property=password);
    CPString    _port       @accessors(property=port);
    CPString    _state      @accessors(property=state);
    id          _delegate   @accessors(property=delegate);
    
    CPTextField _fieldFocusTrick;
    id          _DOMCanvas;
    id          _DOMClipboard;
    id          _oldResponder;

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
        _state  = TNVNCCappuccinoStateDisconnected;
        _oldState = nil;
        
        _fieldFocusTrick = [[CPTextField alloc] initWithFrame:CPRectMake(0,0,0,0)];
        [self addSubview:_fieldFocusTrick];
        
        var novnc_div               = document.createElement("div");
        novnc_div.id                = "vnc";
        
        var novnc_screen            = document.createElement("div");
        novnc_screen.id             = "VNC_screen"
        
        _DOMCanvas                  = document.createElement("canvas");
        _DOMCanvas.id               = "VNC_canvas";
        // _DOMCanvas.width            = "800px";
        // _DOMCanvas.height           = "600px";
        // _DOMCanvas.style.display    = "block";
        _DOMCanvas.innerHTML        = "Canvas not supported.";
        _DOMCanvas.style.border     = "3px solid #8F8F8F";
        
        
        _DOMCanvas.onmouseover    = function(e){
            [self focus];
        };
        
        _DOMCanvas.onmouseout     = function(e){
            [self unfocus];
        };
        
        novnc_screen.appendChild(_DOMCanvas);
        novnc_div.appendChild(novnc_screen);
        
        _DOMElement.appendChild(novnc_div);
    }
    
    return self;
}



/*
    Graphical configuration
*/
- (void)setBackgroundImage:(CPString)anImagePath
{
    _DOMCanvas.style.backgroundImage = "url("+anImagePath+")";
}

- (CPRect)canvasSize
{
    return CPSizeMake(_DOMCanvas.width, _DOMCanvas.height);
}



/*
    Loading / Status
*/
- (void)load
{
    RFB.load();
}

- (void)invalidate
{
    RFB.invalidateAllTimers();
    [_fieldFocusTrick setStringValue:@""];
    //Canvas.clear();
}

- (void)clear
{
    Canvas.clear();
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



/*
    Zoom
*/
- (float)zoom
{
    return Canvas.scale
}

- (void)setZoom:(int)aZoomFactor
{
    Canvas.rescale(aZoomFactor)
}



/*
    Controls
*/
- (IBAction)connect:(id)sender
{
    RFB.setEncrypt(_encrypted);
    RFB.setTrueColor(_trueColor);
    
    RFB.setClipboardReceive(function(text){
        [[CPPasteboard generalPasteboard] setString:text forType:CPStringPboardType];
    });
    
    RFB.setUpdateState(function(state, oldstate, msg){
        _state      = state;
        _oldState   = oldstate;
        _message    = msg;
        if (_delegate && ([_delegate respondsToSelector:@selector(vncView:updateState:message:)]))
            [_delegate vncView:self updateState:state message:msg];
    });
    
    RFB.connect(_host, _port, _password);
}

- (IBAction)disconnect:(id)sender
{
    Canvas.ctx = nil;
    RFB.disconnect();
}

- (void)sendPassword:(CPString)aPassword
{
    RFB.sendPassword(aPassword);
    _password = aPassword;
}

- (IBAction)sendLocalPasteboard:(id)sender
{
    var data = [[CPPasteboard generalPasteboard] stringForType:CPStringPboardType];
    
    if (data)
        RFB.clipboardPasteFrom("test");
}


@end

