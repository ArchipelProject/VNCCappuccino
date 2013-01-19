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

@import <Foundation/Foundation.j>

@import <AppKit/CPView.j>
@import <AppKit/CPTextField.j>

#if PLATFORM(BROWSER)
@import "Resources/jsunzip.js"
@import "Resources/util.js"
@import "Resources/input.js"
@import "Resources/base64.js"
@import "Resources/des.js"
@import "Resources/display.js"
@import "Resources/websock.js"
#endif

@import "Resources/rfb.js"

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
     - vncView:didBecomeFullScreen:size:zoomFactor: this message is sent when VNCView becomes full screen. it will pass the new size and the zoomFactor
     - vncViewDoesNotSupportFullScreen: this message is sent when the VNCView received a setFullScreen message, but browser doesn't support it
*/
@implementation TNVNCView : CPView
{
    BOOL        _encrypted              @accessors(setter=setEncrypted:, getter=isEncrypted);
    BOOL        _isFullScreen           @accessors(getter=isFullScreen);
    BOOL        _trueColor              @accessors(setter=setTrueColor:, getter=isTrueColor);
    BOOL        _trueColor              @accessors(setter=setTrueColor:, getter=isTrueColor);
    CGSize      _defaultSize            @accessors(property=defaultSize);
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

    BOOL        _isFocused;
    CPString    _displayID;
    float       _zoom;
    id          _display;
    id          _DOMCanvas;
    id          _DOMClipboard;
    id          _RFB;
}


#pragma mark -
#pragma mark Initialization

/*! intialize the VNCView in the given frame
    @param aFrame CGRect representing the frame
    @return the initialized TNVNCView
*/
- (id)initWithFrame:(CGRect)aFrame
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
        _defaultSize            = CGSizeMake(800.0, 490.0);
        _zoom                   = 1;
        _displayID              = [CPString UUID];
        _focusContainer         = document;
        _isFullScreen           = NO;

        _DOMCanvas                  = _focusContainer.createElement("canvas");
        _DOMCanvas.id               = _displayID;
        _DOMCanvas.innerHTML        = "Canvas not supported.";
        _DOMCanvas.style.border     = "3px solid #8F8F8F";

        _DOMCanvas.onmouseover    = function(e){
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
            [self focus];
        };

        _DOMCanvas.onmouseout     = function(e){
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
            [self unfocus];
        };

        self._DOMElement.appendChild(_DOMCanvas);
    }

    return self;
}


#pragma mark -
#pragma mark CPResponder implementation

- (void)acceptsFirstResponder
{
    return YES;
}

- (void)resignFirstResponder
{
    return !_isFocused;
}


#pragma mark -
#pragma mark Utilities

/*! set the default size of the VNCView
    @param aRect CGRect representing the default frame
*/
- (void)defaultSize:(CGRect)aRect
{
    _display.canvas_default_w = aRect.width;
    _display.canvas_default_h = aRect.height;
}

/*! return the FBU actual size
    @return FBU CGSize
*/
- (CGSize)displaySize
{
    return CGSizeMake(_display.get_width(), _display.get_height());
}

/*! reset the size of the canvas to the defaultSize
*/
- (void)resetSize
{
    _DOMCanvas.width = _defaultSize.width;
    _DOMCanvas.height = _defaultSize.height;
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

    _display = _RFB.get_display();
    if (!_display)
        [CPException raise:@"No canvas" reason:@"Cannot get canvas with ID: " + _displayID];


    _RFB.set_encrypt(_encrypted);
    _RFB.set_true_color(_trueColor);

    _RFB.set_onUpdateState(function(rfb, state, oldstate, msg){
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        CPLog.info("noVNC state changed from " + oldstate + " to " + state);
        _state      = state;
        _oldState   = oldstate;
        _message    = msg;

        if (_delegate && ([_delegate respondsToSelector:@selector(vncView:updateState:message:)]))
            [_delegate vncView:self updateState:state message:msg];
    });

    _RFB.set_clipboardReceive(function(rfb, text){
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        CPLog.info("noVNC received clipboard text: " + text);

        if (_delegate && ([_delegate respondsToSelector:@selector(vncView:didReceivePasteBoardText:)]))
            [_delegate vncView:self didReceivePasteBoardText:text]
    });

    _RFB.set_onFBUReceive(function(rfb, fbu) {
        if (fbu.encodingName === 'DesktopSize')
        {
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
            if (_delegate && ([_delegate respondsToSelector:@selector(vncView:didDesktopSizeChange:)]))
                [_delegate vncView:self didDesktopSizeChange:CGSizeMake(fbu.width, fbu.height)];
        }
    });

    CPLog.info("noVNC loaded");
}

/*! give the focus to the VNCView. when focused, all
    mouse events, key events or whatever are sent to
    VNC server.
*/
- (void)focus
{
    if (_display)
    {
        _RFB.get_keyboard().set_focused(YES);
        _RFB.get_mouse().set_focused(YES);
        _DOMCanvas.style.border = "3px solid #A1CAE2";
        _DOMCanvas.focus();
        _isFocused = YES;
        [[self window] makeFirstResponder:self];
    }
}

/*! leave focus. all
    mouse events, key events or whatever are sent
    to the Cappuccino Application
*/
- (void)unfocus
{
    if (_display)
    {
        _RFB.get_keyboard().set_focused(NO);
        _RFB.get_mouse().set_focused(NO);
        _DOMCanvas.style.border = "3px solid #8F8F8F";
        _isFocused = NO;
    }
}

/*! get the zoom value
*/
- (float)zoom
{
    if (_display)
        return _display.get_scale();
}

/*! set the zoom value
    @param aZoomFactor float value from 0.0 to 1.0 representing
    the zoom scale factor
*/
- (void)setZoom:(float)aZoomFactor
{
    _zoom = aZoomFactor;
    if (_display)
    {
        _display.set_scale(aZoomFactor);
        _RFB.get_mouse().set_scale(aZoomFactor);
    }
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

/*! send the given text to the VNC Server pasteboard
    @param aText the text to send to the distant server
*/
- (void)sendTextToPasteboard:(CPString)aText
{
    if ((_RFB) && (_state == TNVNCCappuccinoStateNormal))
        _RFB.clipboardPasteFrom(aText);
}

/*! display in fullscreen if support
    @param shouldBeFullScreen if true, display full screen
*/
- (void)setFullScreen:(BOOL)shouldBeFullScreen
{
    if (shouldBeFullScreen === _isFullScreen)
        return;

    var currentDOMObject = _focusContainer.getElementsByTagName("html")[0],
        oldSize,
        newSize,
        zoomFactor;

    currentDOMObject.style.height = "100%";

    oldSize = CGSizeMake(currentDOMObject.offsetWidth, currentDOMObject.offsetHeight);

    if (![CPPlatform isBrowser] || !currentDOMObject.webkitRequestFullScreen || !_focusContainer.webkitCancelFullScreen)
    {
        CPLog.warn("you need last version of webkit to support fullscreen."
                    + " use Webkit nightlies and set 'defaults write com.apple.Safari WebKitFullScreenEnabled 1' in Terminal");

        if (_delegate && [_delegate respondsToSelector:@selector(vncViewDoesNotSupportFullScreen:)])
            [_delegate vncViewDoesNotSupportFullScreen:self];

        return;
    }

    if (shouldBeFullScreen)
    {
        currentDOMObject.webkitRequestFullScreen();
        _isFullScreen   = YES;
        zoomFactor      = currentDOMObject.offsetWidth / oldSize.width;
        [self focus];
    }
    else
    {
        _focusContainer.webkitCancelFullScreen();
        _isFullScreen   = NO;
        zoomFactor      = 1.0;
    }

    if (_delegate && [_delegate respondsToSelector:@selector(vncView:didBecomeFullScreen:size:zoomFactor:)])
        [_delegate vncView:self didBecomeFullScreen:_isFullScreen size:CGSizeMake(currentDOMObject.offsetWidth, currentDOMObject.offsetHeight) zoomFactor:zoomFactor];

}


#pragma mark -
#pragma mark Actions

/*! IBAction that connects to the parametrized VNC Server
    @param aSender the origin control of action
*/
- (IBAction)connect:(id)aSender
{
    CPLog.info("connecting noVNC");
    _RFB.connect(_host, _port, _password);
    if (_display)
    {
        _display.set_scale(_zoom);
        _RFB.get_mouse().set_scale(_zoom);
    }
}

/*! IBAction that disconnects to the connected VNC Server
    @param aSender the origin control of action
*/
- (IBAction)disconnect:(id)sender
{
    CPLog.info("disconnecting noVNC");
    _display.set_ctx = nil;
    _RFB.force_disconnect();
}

/*! send CTRL ALT DEL key combination to the VNC server
    @param aSender the sender of the action
*/
- (void)sendCtrlAltDel:(id)aSender
{
    CPLog.info("sending CTRL ALT DEL noVNC");
    _RFB.sendCtrlAltDel();
}

@end

