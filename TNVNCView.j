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


/*!
    @global
    @group TNVNCCappuccinoState
    noVNC is connected
*/
TNVNCCappuccinoStateNormal                  = @"normal";

/*!
    @global
    @group TNVNCCappuccinoState
    noVNC can't connect
*/
TNVNCCappuccinoStateFailed                  = @"failed";

/*!
    @global
    @group TNVNCCappuccinoState
    noVNC has encounter a fatal error
*/
TNVNCCappuccinoStateFatal                   = @"fatal";

/*!
    @global
    @group TNVNCCappuccinoState
    noVNC is disconnecting
*/
TNVNCCappuccinoStateDisconnect              = @"disconnect";

/*!
    @global
    @group TNVNCCappuccinoState
    noVNC is disconnected
*/
TNVNCCappuccinoStateDisconnected            = @"disconnected";

/*!
    @global
    @group TNVNCCappuccinoState
    noVNC is loaded
*/
TNVNCCappuccinoStateLoaded                  = @"loaded";

/*!
    @global
    @group TNVNCCappuccinoState
    noVNC wait for password
*/
TNVNCCappuccinoStatePassword                = @"password";

/*!
    @global
    @group TNVNCCappuccinoState
    noVNC is computing the security handshake
*/
TNVNCCappuccinoStateSecurityResult          = @"SecurityResult";



/*! This class is a container for VNC
    Consider it as a VNC Screen.

    the delegate can implement the following:
     - vncView:updateState:message: this message is sent to the delegate when the VNCState change
     - vncView:didReceivePasteBoardText: this message is send to the delegate when the server send the content of its pasteboard
*/
@implementation TNVNCView : CPView
{
    BOOL        _encrypted              @accessors(setter=setEncrypted:, getter=isEncrypted);
    BOOL        _trueColor              @accessors(setter=setTrueColor:, getter=isTrueColor);
    BOOL        _trueColor              @accessors(setter=setTrueColor:, getter=isTrueColor);
    CPSize      _defaultSize            @accessors(property=defaultSize);
    CPString    _host                   @accessors(property=host);
    CPString    _message                @accessors(property=message);
    CPString    _oldState               @accessors(property=oldState);
    CPString    _password               @accessors(property=password);
    CPString    _port                   @accessors(property=port);
    CPString    _state                  @accessors(property=state);
    id          _delegate               @accessors(property=delegate);
    id          _focusContainer         @accessors(property=focusContainer);
    int         _checkRate              @accessors(property=checkRate);
    int         _frameBufferRequestRate @accessors(property=frameBufferRequestRate);

    CPString    _canvasID;
    CPTextField _fieldFocusTrick;
    float       _zoom;
    id          _canvas;
    id          _DOMCanvas;
    id          _DOMClipboard;
    id          _oldResponder;
    id          _RFB;
}

/*! intialize the VNCView in the given frame
    @param aFrame CPRect representing the frame
    @return the initialized TNVNCView
*/
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


/*! allow to set an a image (not a CPImage)
    in the background of the VNCView.

    @param anImagePath CPString containing the path of the image
*/
- (void)setBackgroundImage:(CPString)anImagePath
{
    _DOMCanvas.style.backgroundImage = "url("+anImagePath+")";
}

/*! set the default size of the VNCView
    @param aRect CPRect representing the default frame
*/
- (void)defaultSize:(CPRect)aRect
{
    _canvas.canvas_default_w = aRect.width;
    _canvas.canvas_default_h = aRect.height;
}

/*! return the current VNCView's canvas size
    @return CPSize representing the canvas size
*/
- (CPRect)canvasSize
{
    return CPSizeMake(_DOMCanvas.width, _DOMCanvas.height);
}


/*! loads the VNCView
    it will initialize the pure javascript noVNC component
    it takes care of the value of the properties focusContainer,
    frameBufferRequestRate and checkRate
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


/*! reset the size of the canvas to the defaultSize
*/
- (void)resetSize
{
    _DOMCanvas.width = _defaultSize.width;
    _DOMCanvas.height = _defaultSize.height;
}

/*! give the focus to the VNCView. when focused, all
    mouse events, key events or whatever are sent to
    VNC server.
*/
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

/*! leave focus. all
    mouse events, key events or whatever are sent
    to the Cappuccino Application
*/
- (void)unfocus
{
    if (_canvas)
    {
        _canvas.set_focused(NO);
        [[self window] makeFirstResponder:_oldResponder];
        _DOMCanvas.style.border = "3px solid #8F8F8F";
    }
}

/*! get the zoom value
*/
- (float)zoom
{
    if (_canvas)
        return _canvas.get_scale()
}

/*! set the zoom value
    @param aZoomFactor float value from 0.0 to 1.0 representing
    the zoom scale factor
*/
- (void)setZoom:(float)aZoomFactor
{
    _zoom = aZoomFactor;
    if (_canvas)
        _canvas.rescale(aZoomFactor);
}


/*! IBAction that connects to the parametrized VNC Server
    @param aSender the origin control of action
*/
- (IBAction)connect:(id)aSender
{
    CPLog.info("connecting noVNC");
    _RFB.connect(_host, _port, _password);
    if (_canvas)
        _canvas.rescale(_zoom);
}

/*! IBAction that disconnects to the connected VNC Server
    @param aSender the origin control of action
*/
- (IBAction)disconnect:(id)sender
{
    CPLog.info("disconnecting noVNC");
    _canvas.set_ctx = nil;
    _RFB.force_disconnect();
}

/*! send a password to the VNC Server
    use this function in case of state TNVNCCappuccinoStatePassword.
    @param aPassword CPString containing the password
*/
- (void)sendPassword:(CPString)aPassword
{
    CPLog.info("sending password to noVNC");
    _RFB.sendPassword(aPassword);
    _password = aPassword;
}

/*! IBAction that sends CTRL+ALT+DEL key combination to the VNC Server
    @param aSender the origin control of action
*/
- (IBAction)sendCtrlAltDel:(id)sender
{
    if ((_RFB) && (_state == TNVNCCappuccinoStateNormal))
        _RFB.sendCtrlAltDel();
}

/*! send the given text to the VNC Server pasteboard
    @param aText the text to send to the distant server
*/
- (void)sendTextToPasteboard:(CPString)aText
{
    if ((_RFB) && (_state == TNVNCCappuccinoStateNormal))
        _RFB.clipboardPasteFrom(aText);
}
@end

