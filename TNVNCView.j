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
TNVNCCappuccinoStateDisconnect              = @"disconnect";
TNVNCCappuccinoStateDisconnected            = @"disconnected";
TNVNCCappuccinoStateLoaded                  = @"loaded";
TNVNCCappuccinoStatePassword                = @"password";
TNVNCCappuccinoStateSecurityResult          = @"SecurityResult";


/*! This view 
*/
@implementation TNVNCView : CPControl
{
    BOOL        _encrypted              @accessors(setter=setEncrypted:, getter=isEncrypted);
    BOOL        _trueColor              @accessors(setter=setTrueColor:, getter=isTrueColor);
    BOOL        _trueColor              @accessors(setter=setTrueColor:, getter=isTrueColor);
    int         _frameBufferRequestRate @accessors(property=frameBufferRequestRate);
    int         _checkRate              @accessors(property=checkRate);
    CPSize      _defaultSize            @accessors(property=defaultSize);
    CPString    _host                   @accessors(property=host);
    CPString    _message                @accessors(property=message);
    CPString    _oldState               @accessors(property=oldState);
    CPString    _password               @accessors(property=password);
    CPString    _port                   @accessors(property=port);
    CPString    _state                  @accessors(property=state);
    id          _delegate               @accessors(property=delegate);
    id          _focusContainer         @accessors(property=focusContainer);
    
    CPString    _canvasID;
    CPTextField _fieldFocusTrick;
    float       _zoom;
    id          _canvas;
    id          _DOMCanvas;
    id          _DOMClipboard;
    id          _oldResponder;
    id          _RFB;


}

- (id)initWithFrame:(CPRect)aFrame
{
    if (self = [super initWithFrame:aFrame])
    {
        _host                   = nil;
        _port                   = 5900;
        _encrypted              = NO;
        _trueColor              = YES;
        _frameBufferRequestRate = 1413;
        _checkRate              = 217;
        _password               = "";
        _state                  = TNVNCCappuccinoStateDisconnected;
        _oldState               = nil;
        _defaultSize            = CPSizeMake(800.0, 490.0);
        _zoom                   = 1;
        _canvasID               = [CPString UUID];
        _focusContainer         = document
        
        _fieldFocusTrick = [[CPTextField alloc] initWithFrame:CPRectMake(0,0,0,0)];
        [self addSubview:_fieldFocusTrick];
        
        _DOMCanvas                  = _focusContainer.createElement("canvas");
        _DOMCanvas.id               = _canvasID;
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
    
    _RFB = RFB({"target":           _DOMCanvas, 
                "focusContainer":   _focusContainer,
                "fbu_req_rate":     _frameBufferRequestRate,
                "check_rate":       _checkRate
                });
    
    _canvas = _RFB.get_canvas();
    if (!_canvas)
        [CPException raise:@"No canvas" reason:@"Cannot get canvas with ID: " + _canvasID];
        
    
    _RFB.set_encrypt(_encrypted);
    _RFB.set_true_color(_trueColor);
    
    _RFB.set_updateState(function(rfb, state, oldstate, msg){
        CPLog.info("noVNC state changed from " + oldstate + " to " + state);
        _state      = state;
        _oldState   = oldstate;
        _message    = msg;
        
        if (_delegate && ([_delegate respondsToSelector:@selector(vncView:updateState:message:)]))
            [_delegate vncView:self updateState:state message:msg];
    });
    
    _RFB.set_clipboardReceive(function(rfb, text){
        CPLog.info("noVNC received clipboard text: " + text);
        
        if (_delegate && ([_delegate respondsToSelector:@selector(vncView:didReceivePasteBoardText:)]))
            [_delegate vncView:self didReceivePasteBoardText:text]
    });
    
    CPLog.info("noVNC loaded");
}

- (void)invalidate
{
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
        _canvas.set_focused(YES);
        _oldResponder = [[self window] firstResponder];
        [[self window] makeFirstResponder:_fieldFocusTrick];
        _DOMCanvas.style.border = "3px solid #A1CAE2";
        _DOMCanvas.focus();
    }
}

- (void)unfocus
{
    if (_canvas)
    {
        _canvas.set_focused(NO);
        [[self window] makeFirstResponder:_oldResponder];
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
    _zoom = aZoomFactor;
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
    if (_canvas)
        _canvas.rescale(_zoom);
}

- (IBAction)disconnect:(id)sender
{
    CPLog.info("disconnecting noVNC");
    _canvas.set_ctx = nil;
    _RFB.force_disconnect();
}

- (void)sendPassword:(CPString)aPassword
{
    CPLog.info("sending password to noVNC");
    _RFB.sendPassword(aPassword);
    _password = aPassword;
}


- (IBAction)sendCtrlAltDel:(id)sender
{
    if ((_RFB) && (_state == TNVNCCappuccinoStateNormal))
        _RFB.sendCtrlAltDel();
}

- (void)sendTextToPasteboard:(CPString)aText
{
    if ((_RFB) && (_state == TNVNCCappuccinoStateNormal))
        _RFB.clipboardPasteFrom(aText);
}
@end

