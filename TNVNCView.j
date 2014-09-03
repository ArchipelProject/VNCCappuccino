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

@import "TNRemoteScreenView.j"

noVNC_logo = nil;
INCLUDE_URI     = "/Frameworks/VNCCappuccino/Resources/novnc";

Websock_native   = YES;

@import "Resources/novnc/keysym.js"
@import "Resources/novnc/keysymdef.js"
@import "Resources/novnc/keyboard.js"
@import "Resources/novnc/keysym.js"
@import "Resources/novnc/util.js"
@import "Resources/novnc/jsunzip.js"
@import "Resources/novnc/input.js"
@import "Resources/novnc/base64.js"
@import "Resources/novnc/des.js"
@import "Resources/novnc/display.js"
@import "Resources/novnc/rfb.js"
@import "Resources/novnc/websock.js"
@import "Resources/novnc/util.js"

TNVNCStateNormal         = @"normal";
TNVNCStateFailed         = @"failed";
TNVNCStateFatal          = @"fatal";
TNVNCStateDisconnect     = @"disconnect";
TNVNCStateDisconnected   = @"disconnected";
TNVNCStateLoaded         = @"loaded";
TNVNCStatePassword       = @"password";
TNVNCStateSecurityResult = @"SecurityResult";


/*! This class is a container for VNC
    Consider it as a VNC Screen.

    the delegate can implement the following:
     - vncView:updateState:message: this message is sent to the delegate when the VNCState change
     - vncView:didReceivePasteBoardText: this message is send to the delegate when the server send the content of its pasteboard
     - vncView:didBecomeFullScreen:size:zoomFactor: this message is sent when VNCView becomes full screen. it will pass the new size and the zoomFactor
     - vncViewDoesNotSupportFullScreen: this message is sent when the VNCView received a setFullScreen message, but browser doesn't support it
*/
@implementation TNVNCView : TNRemoteScreenView
{
    BOOL        _trueColor              @accessors(setter=setTrueColor:, getter=isTrueColor);
    CPString    _message                @accessors(property=message);
    CPString    _oldState               @accessors(property=oldState);
    CPString    _path                   @accessors(property=path);
    int         _checkRate              @accessors(property=checkRate);
    int         _frameBufferRequestRate @accessors(property=frameBufferRequestRate);

    id          _display;
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
        _trueColor              = YES;
        _frameBufferRequestRate = 1413;
        _checkRate              = 217;
    }

    return self;
}

- (id)_createScreenContainer
{
    return _focusContainer.createElement("canvas")
}

- (CPString)_translateState:(CPString)aState
{
    switch (aState)
    {
        case TNVNCStateNormal:          return TNRemoteScreenViewStateConnected;
        case TNVNCStateFailed:          return TNRemoteScreenViewStateError;
        case TNVNCStateFatal:           return TNRemoteScreenViewStateError;
        case TNVNCStateDisconnected:    return TNRemoteScreenViewStateDisconnected;
        case TNVNCStatePassword:        return TNRemoteScreenViewNeedsPassword;
    }

    return [super _translateState:aState];
}


#pragma mark -
#pragma mark Focus

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

        [super focus];
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

        [super unfocus];
    }
}


#pragma mark -
#pragma mark Zoom Management

/*! return the FBU actual size
    @return FBU CGSize
*/
- (CGSize)displaySize
{
    return CGSizeMake(_display.get_width(), _display.get_height());
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
    [super setZoom:aZoomFactor];

    if (_display)
    {
        _display.set_scale(aZoomFactor);
        _RFB.get_mouse().set_scale(aZoomFactor);
        [self _syncSize];
    }
}


#pragma mark -
#pragma mark Connection Management

/*! loads the VNCView
    it will initialize the pure javascript noVNC component
    it takes care of the value of the properties focusContainer,
    frameBufferRequestRate and checkRate
*/
- (void)load
{
    CPLog.info("loading noVNC");

    _RFB = RFB({"target":           _screenContainer,
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
        _state      = [self _translateState:state];
        _oldState   = [self _translateState:oldstate];
        _message    = msg;

        if (_delegate && ([_delegate respondsToSelector:@selector(remoteScreenView:updateState:message:)]))
            [_delegate remoteScreenView:self updateState:_state message:msg];
    });

    _RFB.set_clipboardReceive(function(rfb, text){
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        CPLog.info("noVNC received clipboard text: " + text);

        if (_delegate && ([_delegate respondsToSelector:@selector(remoteScreenView:didReceivePasteBoardText:)]))
            [_delegate remoteScreenView:self didReceivePasteBoardText:text]
    });

    _RFB.set_onFBResize(function(rfb, width, height) {
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];

        // needs to enqueue this because noVNC calls callbacks before actually doing the changes
        setTimeout(function() {
            [self _syncSize];
            if (_delegate && ([_delegate respondsToSelector:@selector(remoteScreenView:didDesktopSizeChange:)]))
                [_delegate remoteScreenView:self didDesktopSizeChange:CGSizeMake(width, height)];
        }, 0);
    });

    CPLog.info("noVNC loaded");
}

/*! IBAction that connects to the parametrized VNC Server
    @param aSender the origin control of action
*/
- (IBAction)connect:(id)aSender
{
    CPLog.info("connecting noVNC");
    if (_path)
        _RFB.connect(_host, _port, _password, _path);
    else
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


#pragma mark -
#pragma mark VNC Specials

/*! send a password to the VNC Server
    use this function in case of state TNVNCStatePassword.
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
    if ((_RFB) && (_state == TNRemoteScreenViewStateConnected))
        _RFB.clipboardPasteFrom(aText);
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

