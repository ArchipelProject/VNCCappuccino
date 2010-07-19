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

@implementation TNVNCView : CPView
{
    CPString    _host       @accessors(property=host);
    CPString    _port       @accessors(property=port);
    CPString    _password   @accessors(property=password);
    BOOL        _encrypted  @accessors(setter=setEncrypted:, getter=isEncrypted);
    BOOL        _trueColor  @accessors(setter=setTrueColor:, getter=isTrueColor);

    id          _DOMCanvas;
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
         // <div id='vnc'>
         //        <div id="VNC_screen">
         //          <canvas id="VNC_canvas" width="0px" height="0px" style="zoom: ::SCALE::%">
         //              Canvas not supported.
         //          </canvas>
         //        </div>
         //    </div>
            
        var novnc_div               = document.createElement("div");
        novnc_div.id                = "vnc";
        novnc_div.width             = "100%";
        novnc_div.height            = "100%";
        
        var novnc_screen            = document.createElement("div");
        novnc_screen.id             = "VNC_screen"
        novnc_screen.width          = "100%";
        novnc_screen.height         = "100%";
        
        var novnc_canvas            = document.createElement("canvas");
        novnc_canvas.id             = "VNC_canvas";
        novnc_canvas.width          = "0px";
        novnc_canvas.height         = "0px";
        novnc_canvas.innerHTML      = "Canvas not supported.";
        
        _DOMCanvas = novnc_canvas;
        
        novnc_screen.appendChild(novnc_canvas);
        novnc_div.appendChild(novnc_screen);
        
        _DOMElement.appendChild(novnc_div);
    }
    
    return self;
}



- (IBAction)connect:(id)sender
{
    RFB.load();
    RFB.connect(_host, _port, _password, _encrypted, _trueColor);
}

- (IBAction)disconnect:(id)sender
{
    RFB.disconnect();
}

- (void)setZoom:(int)aZoomFactor
{
    _DOMCanvas.style.zoom = aZoomFactor + @"%";
}

@end

