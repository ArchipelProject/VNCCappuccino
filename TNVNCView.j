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


/*! This view 
*/
@implementation TNVNCView : CPControl
{
    BOOL        _encrypted      @accessors(setter=setEncrypted:, getter=isEncrypted);
    BOOL        _trueColor      @accessors(setter=setTrueColor:, getter=isTrueColor);
    CPString    _host           @accessors(property=host);
    CPString    _message        @accessors(property=message);
    CPString    _oldState       @accessors(property=oldState);
    CPString    _password       @accessors(property=password);
    CPString    _port           @accessors(property=port);
    CPString    _state          @accessors(property=state);
    id          _delegate       @accessors(property=delegate);
    CPSize      _defaultSize    @accessors(property=defaultSize);
    
    CPTextField _fieldFocusTrick;
    id          _DOMClipboard;
    id          _oldResponder;
    id          _canvas;
    id          _RFB;

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
        _defaultSize = CPSizeMake(800.0, 490.0);
        
        _fieldFocusTrick = [[CPTextField alloc] initWithFrame:CPRectMake(0,0,0,0)];
        [self addSubview:_fieldFocusTrick];
        
        _DOMCanvas                  = document.createElement("canvas");
        _DOMCanvas.id               = "VNC_canvas";
        _DOMCanvas.innerHTML        = "Canvas not supported.";
        _DOMCanvas.style.border     = "3px solid #8F8F8F";
        
        
        _DOMCanvas.onmouseover    = function(e){
            [self focus];
        };
        
        _DOMCanvas.onmouseout     = function(e){
            [self unfocus];
        };
        
        _DOMElement.appendChild(_DOMCanvas);
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

- (void)defaultSize:(CPRect)aRect
{
    _canvas.canvas_default_w = aRect.width;
    _canvas.canvas_default_h = aRect.height;
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
    CPLog.info("loading noVNC");
    
    _RFB = RFB({"target": "VNC_canvas"});
    _RFB.init();
    _canvas = _RFB.get_canvas();
    
    _RFB.set_encrypt(_encrypted);
    _RFB.set_true_color(_trueColor);
    
    _RFB.set_updateState(function(rfb, state, oldstate, msg){
        CPLog.info("noVNC state changed from " + oldstate + " to " + state);
        _state      = state;
        _oldState   = oldstate;
        _message    = msg;
        
        if (_state == TNVNCCappuccinoStateNormal)
            [self focus];
        else
            [self unfocus];
        
        if (_delegate && ([_delegate respondsToSelector:@selector(vncView:updateState:message:)]))
            [_delegate vncView:self updateState:state message:msg];
    });
    CPLog.info("noVNC loaded");
}

- (void)invalidate
{
    //_RFB.invalidateAllTimers();
    [_fieldFocusTrick setStringValue:@""];
}

- (void)clear
{
    _DOMCanvas.width = _defaultSize.width;
    _DOMCanvas.height = _defaultSize.height;
}

- (void)focus
{
    if (_canvas)
    {
        _oldResponder = [[self window] firstResponder];
        [[self window] makeFirstResponder:_fieldFocusTrick];
        _canvas.set_focused(YES);
        _DOMCanvas.style.border = "3px solid #A1CAE2";
    }
}

- (void)unfocus
{
    if (_canvas)
    {
        [[self window] makeFirstResponder:_oldResponder];
        _canvas.set_focused(NO);
        _DOMCanvas.style.border = "3px solid #8F8F8F";
    }
}



/*
    Zoom
*/
- (float)zoom
{
    if (_canvas)
        return _canvas.get_scale()
}

- (void)setZoom:(int)aZoomFactor
{
    if (_canvas)
        _canvas.rescale(aZoomFactor);
}



/*
    Controls
*/
- (IBAction)connect:(id)sender
{
    CPLog.info("connecting noVNC");
    _RFB.connect(_host, _port, _password);
}

- (IBAction)disconnect:(id)sender
{
    CPLog.info("disconnecting noVNC");
    _canvas.set_ctx = nil;
    _RFB.disconnect();
}

- (void)sendPassword:(CPString)aPassword
{
    CPLog.info("sending password to noVNC");
    _RFB.sendPassword(aPassword);
    _password = aPassword;
}

@end

