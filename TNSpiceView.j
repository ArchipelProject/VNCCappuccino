/*
 * TNSpiceView.j
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
@import "TNRemoteScreenView.j"

@import "Resources/spice/enums.js"
@import "Resources/spice/atKeynames.js"
@import "Resources/spice/utils.js"
@import "Resources/spice/png.js"
@import "Resources/spice/lz.js"
@import "Resources/spice/quic.js"
@import "Resources/spice/bitmap.js"
@import "Resources/spice/spicedataview.js"
@import "Resources/spice/spicetype.js"
@import "Resources/spice/spicemsg.js"
@import "Resources/spice/wire.js"
@import "Resources/spice/spiceconn.js"
@import "Resources/spice/display.js"
@import "Resources/spice/main.js"
@import "Resources/spice/inputs.js"
@import "Resources/spice/cursor.js"
@import "Resources/spice/jsbn.js"
@import "Resources/spice/rsa.js"
@import "Resources/spice/prng4.js"
@import "Resources/spice/rng.js"
@import "Resources/spice/sha1.js"
@import "Resources/spice/ticket.js"

TNSpiceViewStateConnecting    = @"connecting";
TNSpiceViewStateReady         = @"ready";
TNSpiceViewStateLink          = @"link";
TNSpiceViewStateTicket        = @"ticket";
TNSpiceViewStateError         = @"error";
TNSpiceViewStateClosed        = @"closed";
TNSpiceViewStateNeedsPassword = @"needs_password";

SPICE_CONNECT_TIMEOUT = 300;

@implementation TNSpiceView : TNRemoteScreenView
{
    id          _spice;
    CGSize      _currentDisplaySize;
    CPString    _remoteURL;
}

#pragma mark -
#pragma mark Initialization

- (id)initWithFrame:(CGRect)aFrame focusContainer:(id)aFocusContainer
{
    if (self = [self initWithFrame:aFrame])
    {
        _focusContainer = aFocusContainer;
        [self _refreshScreenContainer];
    }

    return self;
}

#pragma mark -
#pragma mark TNRemoteScreenView Protocol

/*! Create the screen container
    @return a DOM div element
*/
- (id)_createScreenContainer
{
    return _focusContainer.createElement("div");
}

/*! Translate SPICEHTML5 state to TNRemoteScreenView states
    @return translated state
*/
- (CPString)_translateState:(CPString)aState
{
    switch (aState)
    {
        case TNSpiceViewStateConnecting:    return TNRemoteScreenViewStateConnecting;
        case TNSpiceViewStateReady:         return TNRemoteScreenViewStateConnected;
        case TNSpiceViewStateClosed:        return TNRemoteScreenViewStateDisconnected;
        case TNSpiceViewStateError:         return TNRemoteScreenViewStateError;
        case TNSpiceViewStateNeedsPassword: return TNRemoteScreenViewNeedsPassword;
    }

    return [super _translateState:aState];
}

- (CGSize)displaySize
{
    return _currentDisplaySize || CGSizeMakeZero();
}

- (void)setZoom:(float)aZoomFactor
{
    [super setZoom:aZoomFactor];

    if (_spice)
    {
        _spice.set_scale(aZoomFactor);
        [self _syncSize];
    }
}

#pragma mark -
#pragma mark Connection management

- (void)load
{
    _remoteURL = (_encrypted ? @"wss" : @"ws") + "://" + _host + ":" + _port;
}

- (void)_connect
{
    _spice = new SpiceMainConn(
        {
            screen_id:          _displayID,
            uri:                _remoteURL,
            password:           _password,
            focus_container:    _focusContainer,

            onresize: function(width, height){
                [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
                _currentDisplaySize = CGSizeMake(width, height);

                setTimeout(function() {
                    [self _syncSize];
                    if (_delegate && ([_delegate respondsToSelector:@selector(remoteScreenView:didDesktopSizeChange:)]))
                        [_delegate remoteScreenView:self didDesktopSizeChange:CGSizeMake(width, height)];
                }, 0);
            },

            onchange_state: function(oldstate, state) {
                [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
                CPLog.info("SPICE state changed from " + oldstate + " to " + state);
                _state      = [self _translateState:state];
                _oldState   = [self _translateState:oldstate];

                if (_delegate && ([_delegate respondsToSelector:@selector(remoteScreenView:updateState:message:)]))
                    [_delegate remoteScreenView:self updateState:_state message:nil];
            },

            onerror : function(e) {
                _state = [self _translateState:TNSpiceViewStateError];
                _oldState = [self _translateState:TNSpiceViewStateConnecting];
                if (_delegate && ([_delegate respondsToSelector:@selector(remoteScreenView:updateState:message:)]))
                    [_delegate remoteScreenView:self updateState:_state message:nil];
            }
        });
    }

- (void)sendPassword:(CPString)aPassword
{
    [self disconnect:nil];
    _password = aPassword;
    [self _connect];
}

- (IBAction)connect:(id)aSender
{
    [self disconnect:aSender];
    [self _connect];
}

- (IBAction)disconnect:(id)aSender
{
    if (_spice)
        _spice.stop();
    _spice = nil;
    _password = nil;
}


@end
