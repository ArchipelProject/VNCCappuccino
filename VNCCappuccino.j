/*  
 * VNCCappuccino.j
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

VNC_native_ws = true;

@import "Resources/util.js";
@import "Resources/base64.js";
@import "Resources/des.js";
@import "Resources/canvas.js";
@import "Resources/rfb.js";

// if (!window.WebSocket)
// {
//     WebSocket__swfLocation = "/Frameworks/NOVNCCappuccino/Resources/web-socket-js/WebSocketMain.swf";
//     @import "Resources/web-socket-js/swfobject.js";
//     @import "Resources/web-socket-js/FABridge.js";
//     @import "Resources/web-socket-js/web_socket.js";
// }

@import "TNVNCView.j";