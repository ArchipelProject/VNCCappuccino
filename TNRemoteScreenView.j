/*
 * TNRemoteScreenView.j
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

TNRemoteScreenViewStateConnecting       = @"connecting";
TNRemoteScreenViewStateConnected        = @"connected";
TNRemoteScreenViewStateDisconnecting    = @"disconnecting";
TNRemoteScreenViewStateDisconnected     = @"disconnected";
TNRemoteScreenViewStateError            = @"error";
TNRemoteScreenViewNeedsPassword         = @"needs_password";


@implementation TNRemoteScreenView : CPView
{
    BOOL        _encrypted              @accessors(setter=setEncrypted:, getter=isEncrypted);
    BOOL        _autoResizeViewPort     @accessors(setter=setAutoResizeViewPort:, getter=isAutoResizeViewPort);
    BOOL        _isFullScreen           @accessors(getter=isFullScreen);
    CPString    _host                   @accessors(property=host);
    CPString    _password               @accessors(property=password);
    CPString    _port                   @accessors(property=port);
    CPString    _state                  @accessors(property=state);
    CPString    _oldState               @accessors(property=oldState);
    id          _delegate               @accessors(property=delegate);
    id          _focusContainer         @accessors(property=focusContainer);

    BOOL        _isFocused;
    CPString    _displayID;
    float       _zoom;
    id          _screenContainer;
}


#pragma mark -
#pragma mark Initialization

/*! Initialize the TNRemoteScreenView
*/
- (id)initWithFrame:(CGRect)aFrame
{
    if (self = [super initWithFrame:aFrame])
    {
        _autoResizeViewPort = YES;
        _focusContainer     = document;
        _host               = nil;
        _isFullScreen       = NO;
        _isFullScreen       = NO;
        _password           = "";
        _port               = 5900;
        _state              = TNRemoteScreenViewStateDisconnected;
        _zoom               = 1;
        _encrypted          = NO;
        _oldState           = nil;

        [self _refreshScreenContainer];
    }

    return self;
}

- (void)_refreshScreenContainer
{
    if (_screenContainer)
        self._DOMElement.removeChild(_screenContainer);

    _displayID          = [CPString UUID];
    _screenContainer    = [self _createScreenContainer];
    _screenContainer.id = _displayID;

    self._DOMElement.appendChild(_screenContainer);

    _screenContainer.addEventListener("mouseover", function(e) {
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        [self focus];
    }, true)

    _screenContainer.addEventListener("mouseout", function(e) {
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        [self unfocus];
    }, true)
}


#pragma mark -
#pragma mark TNRemoteScreenView Protocol

/*! This needs to be overwritten in order to return
    The DOM element that will be used as the main screen
    by the external library
    @return DOMElement the DOM element to use (mostly canvas or div)
*/
- (id)_createScreenContainer
{
    [CPException raise:@"MethodNotImplemented" reason:@"_createScreenContainer must be implemented"];
}

/*! TNRemoteScreenView provides different state. External libraries might use
    Different terminologies. Overides this function to return standardized states.
*/
- (void)_translateState:(CPString)aState
{
    return aState;
}

/*! Return the screen size. You must overide this and use the external lib
    API to create a CGSize
    @return CGSize representing the remote screen resolution
*/
- (CGSize)displaySize
{
    [CPException raise:@"MethodNotImplemented" reason:@"displaySize: must be implemented"];
}


#pragma mark -
#pragma mark CPResponder implementation

/*! @ignore
*/
- (BOOL)acceptsFirstResponder
{
    return YES;
}

/*! @ignore
*/
- (BOOL)resignFirstResponder
{
    return !_isFocused;
}


#pragma mark -
#pragma mark Focus

/*! give the focus to the VNCView. when focused, all
    mouse events, key events or whatever are sent to
    VNC server.
*/
- (void)focus
{
    _screenContainer.focus();
    _isFocused = YES;
    [[self window] makeFirstResponder:self];

    if (_delegate && [_delegate respondsToSelector:@selector(remoteScreenView:didGetFocus:)])
        [_delegate remoteScreenView:self didGetFocus:YES];
}

/*! leave focus. all
    mouse events, key events or whatever are sent
    to the Cappuccino Application
*/
- (void)unfocus
{
    _isFocused = NO;

    if (_delegate && ([_delegate respondsToSelector:@selector(remoteScreenView:didGetFocus:)]))
        [_delegate remoteScreenView:self didGetFocus:NO];
}


#pragma mark -
#pragma mark Zoom Management

/*! get the zoom value
*/
- (float)zoom
{
    return _zoom;
}

/*! set the zoom value
    @param aZoomFactor float value from 0.0 to 1.0 representing
    the zoom scale factor
*/
- (void)setZoom:(float)aZoomFactor
{
    _zoom = aZoomFactor;
}

/*! This will be called when the screen resize to actually resize the CPView
*/
- (void)_syncSize
{
    if (_autoResizeViewPort)
    {
        var currentSize = [self displaySize];
        [self setFrameSize:CGSizeMake(currentSize.width * _zoom, currentSize.height * _zoom)];
    }
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

        if (_delegate && [_delegate respondsToSelector:@selector(remoteScreenViewDoesNotSupportFullScreen:)])
            [_delegate remoteScreenViewDoesNotSupportFullScreen:self];

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

    if (_delegate && [_delegate respondsToSelector:@selector(remoteScreenView:didBecomeFullScreen:size:zoomFactor:)])
        [_delegate remoteScreenView:self didBecomeFullScreen:_isFullScreen size:CGSizeMake(currentDOMObject.offsetWidth, currentDOMObject.offsetHeight) zoomFactor:zoomFactor];

}


#pragma mark -
#pragma mark Connection Management

/*! Overide this if you external library needs any loading stuff before connection
*/
- (void)load
{
}

/*! IBAction that connects to the parametrized VNC Server
    @param aSender the origin control of action
*/
- (IBAction)connect:(id)aSender
{
}

/*! IBAction that disconnects to the connected VNC Server
    @param aSender the origin control of action
*/
- (IBAction)disconnect:(id)sender
{
}

@end
