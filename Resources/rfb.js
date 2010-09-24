/*
 * noVNC: HTML5 VNC client
 * Copyright (C) 2010 Joel Martin
 * Licensed under LGPL-3 (see LICENSE.txt)
 *
 * See README.md for usage and integration instructions.
 */

//"use strict";
/*jslint white: false, browser: true, bitwise: false */
/*global window, WebSocket, Util, Canvas, VNC_native_ws, Base64, DES */


RFB = function(conf) {
conf               = conf || {}; // Configuration
var that           = {},         // Public API interface

    // Pre-declare private functions used before definitions (jslint)
    init_vars, updateState, init_msg, normal_msg, recv_message,
    framebufferUpdate,

    pixelFormat, clientEncodings, fbUpdateRequest,
    keyEvent, pointerEvent, clientCutText,

    extract_data_uri, scan_tight_imgQ,

    send_array, checkEvents,  // Overridable for testing


    //
    // Private RFB namespace variables
    //
    rfb_host       = '',
    rfb_port       = 5900,
    rfb_password   = '',

    rfb_state      = 'disconnected',
    rfb_version    = 0,
    rfb_max_version= 3.8,
    rfb_auth_scheme= '',
    rfb_shared     = 1,


    // In preference order
    encodings      = [
        ['COPYRECT',         0x01 ],
        ['TIGHT_PNG',        -260 ],
        ['HEXTILE',          0x05 ],
        ['RRE',              0x02 ],
        ['RAW',              0x00 ],
        ['DesktopSize',      -223 ],
        ['Cursor',           -239 ],

        // Psuedo-encoding settings
        ['JPEG_quality_lo',   -32 ],
        //['JPEG_quality_hi',   -23 ],
        ['compress_lo',      -255 ]
        //['compress_hi',      -247 ]
        ],

    encHandlers    = {},
    encNames       = {}, 

    ws             = null,   // Web Socket object
    canvas         = null,   // Canvas object
    sendTimer      = null,   // Send Queue check timer
    connTimer      = null,   // connection timer
    disconnTimer   = null,   // disconnection timer
    msgTimer       = null,   // queued handle_message timer

    // Receive and send queues
    rQ             = [],     // Receive Queue
    rQi            = 0,      // Receive Queue Index
    rQmax          = 100000, // Max size before compacting
    sQ             = "",     // Send Queue

    // Frame buffer update state
    FBU            = {
        rects          : 0,
        subrects       : 0,  // RRE and HEXTILE
        lines          : 0,  // RAW
        tiles          : 0,  // HEXTILE
        bytes          : 0,
        x              : 0,
        y              : 0,
        width          : 0, 
        height         : 0,
        encoding       : 0,
        subencoding    : -1,
        background     : null,
        imgQ           : []   // TIGHT_PNG image queue
    },

    fb_Bpp         = 4,
    fb_depth       = 3,
    fb_width       = 0,
    fb_height      = 0,
    fb_name        = "",

    cuttext        = 'none', // ServerCutText wait state
    cuttext_length = 0,

    scan_imgQ_rate = 100,
    last_req_time  = 0,
    rre_chunk_sz   = 100,

    timing         = {
        last_fbu       : 0,
        fbu_total      : 0,
        fbu_total_cnt  : 0,
        full_fbu_total : 0,
        full_fbu_cnt   : 0,

        fbu_rt_start   : 0,
        fbu_rt_total   : 0,
        fbu_rt_cnt     : 0
    },

    test_mode        = false,

    /* Mouse state */
    mouse_buttonMask = 0,
    mouse_arr        = [];


//
// Configuration settings
//
function cdef(v, type, defval, desc) {
    Util.conf_default(conf, that, v, type, defval, desc); }

cdef('target',         'str', 'VNC_canvas', 'VNC viewport rendering Canvas');
cdef('focusContainer', 'dom', document, 'Area that traps keyboard input');

cdef('encrypt',        'bool', false, 'Use TLS/SSL/wss encryption');
cdef('true_color',     'bool', true,  'Request true color pixel data');
cdef('local_cursor',   'bool', false, 'Request locally rendered cursor');

cdef('connectTimeout',    'int', 2,    'Time (s) to wait for connection');
cdef('disconnectTimeout', 'int', 3,    'Time (s) to wait for disconnection');
cdef('check_rate',        'int', 217,  'Timing (ms) of send/receive check');
cdef('fbu_req_rate',      'int', 1413, 'Timing (ms) of frameBufferUpdate requests');

cdef('updateState',
     'func', function() { Util.Debug("updateState stub"); },
     'callback: state update');
cdef('clipboardReceive',
     'func', function() { Util.Debug("clipboardReceive stub"); },
     'callback: clipboard contents received');


// Override/add some specific getters/setters
that.set_local_cursor = function(cursor) {
    if ((!cursor) || (cursor in {'0':1, 'no':1, 'false':1})) {
        conf.local_cursor = false;
    } else {
        if (canvas.get_cursor_uri()) {
            conf.local_cursor = true;
        } else {
            Util.Warn("Browser does not support local cursor");
        }
    }
};

that.get_canvas = function() {
    return canvas;
};




//
// Private functions
//

//
// Receive Queue functions
//
function rQlen() {
    return rQ.length - rQi;
}

function rQshift16() {
    return (rQ[rQi++] <<  8) +
           (rQ[rQi++]      );
}
function rQshift32() {
    return (rQ[rQi++] << 24) +
           (rQ[rQi++] << 16) +
           (rQ[rQi++] <<  8) +
           (rQ[rQi++]      );
}
function rQshiftStr(len) {
    var arr = rQ.slice(rQi, rQi + len);
    rQi += len;
    return arr.map(function (num) {
            return String.fromCharCode(num); } ).join('');

}
function rQshiftBytes(len) {
    rQi += len;
    return rQ.slice(rQi-len, rQi);
}

//
// Setup routines
//

// Create the public API interface and initialize
function constructor() {
    var i;
    Util.Debug(">> RFB.constructor");

    // Create lookup tables based encoding number
    for (i=0; i < encodings.length; i+=1) {
        encHandlers[encodings[i][1]] = encHandlers[encodings[i][0]];
        encNames[encodings[i][1]] = encodings[i][0];
    }
    // Initialize canvas
    try {
        canvas = new Canvas({'target': conf.target,
                             'focusContainer': conf.focusContainer});
    } catch (exc) {
        Util.Error("Canvas exception: " + exc);
        updateState('fatal', "No working Canvas");
    }

    init_vars();

    /* Check web-socket-js if no builtin WebSocket support */
    if (VNC_native_ws) {
        Util.Info("Using native WebSockets");
        updateState('loaded', 'noVNC ready (using native WebSockets)');
    } else {
        Util.Warn("Using web-socket-js flash bridge");
        if ((! Util.Flash) ||
            (Util.Flash.version < 9)) {
            updateState('fatal', "WebSockets or Adobe Flash is required");
        } else if (document.location.href.substr(0, 7) === "file://") {
            updateState('fatal',
                    "'file://' URL is incompatible with Adobe Flash");
        } else {
            updateState('loaded', 'noVNC ready (using Flash WebSockets emulation)');
        }
    }

    Util.Debug("<< RFB.constructor");
    return that;  // Return the public API interface
}

function init_ws() {
    Util.Debug(">> RFB.init_ws");

    var uri = "";
    if (conf.encrypt) {
        uri = "wss://";
    } else {
        uri = "ws://";
    }
    uri += rfb_host + ":" + rfb_port + "/";
    Util.Info("connecting to " + uri);
    ws = new WebSocket(uri);

    ws.onmessage = recv_message;
    ws.onopen = function(e) {
        Util.Debug(">> WebSocket.onopen");
        if (rfb_state === "connect") {
            updateState('ProtocolVersion', "Starting VNC handshake");
        } else {
            updateState('failed', "Got unexpected WebSockets connection");
        }
        Util.Debug("<< WebSocket.onopen");
    };
    ws.onclose = function(e) {
        Util.Debug(">> WebSocket.onclose");
        if (rfb_state === 'disconnect') {
            updateState('disconnected', 'VNC disconnected');
        } else if (rfb_state === 'ProtocolVersion') {
            updateState('failed', 'Failed to connect to server');
        } else if (rfb_state in {'failed':1, 'disconnected':1}) {
            Util.Error("Received onclose while disconnected");
        } else  {
            updateState('failed', 'Server disconnected');
        }
        Util.Debug("<< WebSocket.onclose");
    };
    ws.onerror = function(e) {
        Util.Debug(">> WebSocket.onerror");
        updateState('failed', "WebSocket error");
        Util.Debug("<< WebSocket.onerror");
    };

    Util.Debug("<< RFB.init_ws");
}

init_vars = function() {
    /* Reset state */
    cuttext          = 'none';
    cuttext_length   = 0;
    rQ               = [];
    rQi              = 0;
    sQ               = "";
    FBU.rects        = 0;
    FBU.subrects     = 0;  // RRE and HEXTILE
    FBU.lines        = 0;  // RAW
    FBU.tiles        = 0;  // HEXTILE
    FBU.imgQ         = []; // TIGHT_PNG image queue
    mouse_buttonMask = 0;
    mouse_arr        = [];
};

//
// Utility routines
//


/*
 * Running states:
 *   disconnected - idle state
 *   normal       - connected
 *
 * Page states:
 *   loaded       - page load, equivalent to disconnected
 *   connect      - starting initialization
 *   disconnect   - starting disconnect
 *   failed       - abnormal transition to disconnected
 *   fatal        - failed to load page, or fatal error
 *
 * VNC initialization states:
 *   ProtocolVersion
 *   Security
 *   Authentication
 *   password     - waiting for password, not part of RFB
 *   SecurityResult
 *   ServerInitialization
 */
updateState = function(state, statusMsg) {
    var func, cmsg, oldstate = rfb_state;

    if (state === oldstate) {
        /* Already here, ignore */
        Util.Debug("Already in state '" + state + "', ignoring.");
        return;
    }

    /* 
     * These are disconnected states. A previous connect may
     * asynchronously cause a connection so make sure we are closed.
     */
    if (state in {'disconnected':1, 'loaded':1, 'connect':1,
                  'disconnect':1, 'failed':1, 'fatal':1}) {
        if (sendTimer) {
            clearInterval(sendTimer);
            sendTimer = null;
        }

        if (msgTimer) {
            clearInterval(msgTimer);
            msgTimer = null;
        }

        if (canvas && canvas.getContext()) {
            canvas.stop();
            if (Util.get_logging() !== 'debug') {
                canvas.clear();
            }
        }

        if (ws) {
            if ((ws.readyState === WebSocket.OPEN) || 
               (ws.readyState === WebSocket.CONNECTING)) {
                Util.Info("Closing WebSocket connection");
                ws.close();
            }
            ws.onmessage = function (e) { return; };
        }
    }

    if (oldstate === 'fatal') {
        Util.Error("Fatal error, cannot continue");
    }

    if ((state === 'failed') || (state === 'fatal')) {
        func = Util.Error;
    } else {
        func = Util.Warn;
    }

    if ((oldstate === 'failed') && (state === 'disconnected')) {
        // Do disconnect action, but stay in failed state.
        rfb_state = 'failed';
    } else {
        rfb_state = state;
    }

    cmsg = typeof(statusMsg) !== 'undefined' ? (" Msg: " + statusMsg) : "";
    func("New state '" + rfb_state + "', was '" + oldstate + "'." + cmsg);

    if (connTimer && (rfb_state !== 'connect')) {
        Util.Debug("Clearing connect timer");
        clearInterval(connTimer);
        connTimer = null;
    }

    if (disconnTimer && (rfb_state !== 'disconnect')) {
        Util.Debug("Clearing disconnect timer");
        clearInterval(disconnTimer);
        disconnTimer = null;
    }

    switch (state) {
    case 'normal':
        if ((oldstate === 'disconnected') || (oldstate === 'failed')) {
            Util.Error("Invalid transition from 'disconnected' or 'failed' to 'normal'");
        }

        break;


    case 'connect':
        
        connTimer = setTimeout(function () {
                updateState('failed', "Connect timeout");
            }, conf.connectTimeout * 1000);

        init_vars();
        init_ws();

        // WebSocket.onopen transitions to 'ProtocolVersion'
        break;


    case 'disconnect':

        if (! test_mode) {
            disconnTimer = setTimeout(function () {
                    updateState('failed', "Disconnect timeout");
                }, conf.disconnectTimeout * 1000);
        }
        // WebSocket.onclose transitions to 'disconnected'
        break;


    case 'failed':
        if (oldstate === 'disconnected') {
            Util.Error("Invalid transition from 'disconnected' to 'failed'");
        }
        if (oldstate === 'normal') {
            Util.Error("Error while connected.");
        }
        if (oldstate === 'init') {
            Util.Error("Error while initializing.");
        }

        // Make sure we transition to disconnected
        setTimeout(function() { updateState('disconnected'); }, 50);

        break;


    default:
        // No state change action to take

    }

    if ((oldstate === 'failed') && (state === 'disconnected')) {
        // Leave the failed message
        conf.updateState(that, state, oldstate);
    } else {
        conf.updateState(that, state, oldstate, statusMsg);
    }
};

function encode_message(arr) {
    /* base64 encode */
    sQ = sQ + Base64.encode(arr);
}

function decode_message(data) {
    //Util.Debug(">> decode_message: " + data);
    /* base64 decode */
    rQ = rQ.concat(Base64.decode(data, 0));
    //Util.Debug(">> decode_message, rQ: " + rQ);
}

function handle_message() {
    //Util.Debug("rQ.slice(rQi,rQi+20): " + rQ.slice(rQi,rQi+20) + " (" + rQlen() + ")");
    if (rQlen() === 0) {
        Util.Warn("handle_message called on empty receive queue");
        return;
    }
    switch (rfb_state) {
    case 'disconnected':
    case 'failed':
        Util.Error("Got data while disconnected");
        break;
    case 'normal':
        if (normal_msg() && rQlen() > 0) {
            // true means we can continue processing
            // Give other events a chance to run
            if (msgTimer === null) {
                Util.Debug("More data to process, creating timer");
                msgTimer = setTimeout(function () {
                            msgTimer = null;
                            handle_message();
                        }, 10);
            } else {
                Util.Debug("More data to process, existing timer");
            }
        }
        // Compact the queue
        if (rQ.length > rQmax) {
            //Util.Debug("Compacting receive queue");
            rQ = rQ.slice(rQi);
            rQi = 0;
        }
        break;
    default:
        init_msg();
        break;
    }
}

recv_message = function(e) {
    //Util.Debug(">> recv_message: " + e.data.length);

    try {
        decode_message(e.data);
        if (rQlen() > 0) {
            handle_message();
        } else {
            Util.Debug("Ignoring empty message");
        }
    } catch (exc) {
        if (typeof exc.stack !== 'undefined') {
            Util.Warn("recv_message, caught exception: " + exc.stack);
        } else if (typeof exc.description !== 'undefined') {
            Util.Warn("recv_message, caught exception: " + exc.description);
        } else {
            Util.Warn("recv_message, caught exception:" + exc);
        }
        if (typeof exc.name !== 'undefined') {
            updateState('failed', exc.name + ": " + exc.message);
        } else {
            updateState('failed', exc);
        }
    }
    //Util.Debug("<< recv_message");
};

// overridable for testing
send_array = function(arr) {
    //Util.Debug(">> send_array: " + arr);
    encode_message(arr);
    if (ws.bufferedAmount === 0) {
        //Util.Debug("arr: " + arr);
        //Util.Debug("sQ: " + sQ);
        ws.send(sQ);
        sQ = "";
    } else {
        Util.Debug("Delaying send");
    }
};

function send_string(str) {
    //Util.Debug(">> send_string: " + str);
    send_array(str.split('').map(
        function (chr) { return chr.charCodeAt(0); } ) );
}

function genDES(password, challenge) {
    var i, passwd, response;
    passwd = [];
    response = challenge.slice();
    for (i=0; i < password.length; i += 1) {
        passwd.push(password.charCodeAt(i));
    }

    DES.setKeys(passwd);
    DES.encrypt(response, 0, response, 0);
    DES.encrypt(response, 8, response, 8);
    return response;
}

function flushClient() {
    if (mouse_arr.length > 0) {
        //send_array(mouse_arr.concat(fbUpdateRequest(1)));
        send_array(mouse_arr);
        setTimeout(function() {
                send_array(fbUpdateRequest(1));
            }, 50);

        mouse_arr = [];
        return true;
    } else {
        return false;
    }
}

// overridable for testing
checkEvents = function() {
    var now;
    if (rfb_state === 'normal') {
        if (! flushClient()) {
            now = new Date().getTime();
            if (now > last_req_time + conf.fbu_req_rate) {
                last_req_time = now;
                send_array(fbUpdateRequest(1));
            }
        }
    }
    setTimeout(checkEvents, conf.check_rate);
};

function keyPress(keysym, down) {
    var arr;
    arr = keyEvent(keysym, down);
    arr = arr.concat(fbUpdateRequest(1));
    send_array(arr);
}

function mouseButton(x, y, down, bmask) {
    if (down) {
        mouse_buttonMask |= bmask;
    } else {
        mouse_buttonMask ^= bmask;
    }
    mouse_arr = mouse_arr.concat( pointerEvent(x, y) );
    flushClient();
}

function mouseMove(x, y) {
    //Util.Debug('>> mouseMove ' + x + "," + y);
    mouse_arr = mouse_arr.concat( pointerEvent(x, y) );
}


//
// Server message handlers
//

// RFB/VNC initialisation message handler
init_msg = function() {
    //Util.Debug(">> init_msg [rfb_state '" + rfb_state + "']");

    var strlen, reason, reason_len, sversion, cversion,
        i, types, num_types, challenge, response, bpp, depth,
        big_endian, true_color, name_length;

    //Util.Debug("rQ (" + rQlen() + ") " + rQ);
    switch (rfb_state) {

    case 'ProtocolVersion' :
        if (rQlen() < 12) {
            updateState('failed',
                    "Disconnected: incomplete protocol version");
            return;
        }
        sversion = rQshiftStr(12).substr(4,7);
        Util.Info("Server ProtocolVersion: " + sversion);
        switch (sversion) {
            case "003.003": rfb_version = 3.3; break;
            case "003.006": rfb_version = 3.3; break;  // UltraVNC
            case "003.007": rfb_version = 3.7; break;
            case "003.008": rfb_version = 3.8; break;
            default:
                updateState('failed',
                        "Invalid server version " + sversion);
                return;
        }
        if (rfb_version > rfb_max_version) { 
            rfb_version = rfb_max_version;
        }

        if (! test_mode) {
            sendTimer = setInterval(function() {
                    // Send updates either at a rate of one update
                    // every 50ms, or whatever slower rate the network
                    // can handle.
                    if (ws.bufferedAmount === 0) {
                        if (sQ) {
                            ws.send(sQ);
                            sQ = "";
                        }
                    } else {
                        Util.Debug("Delaying send");
                    }
                }, 50);
        }

        cversion = "00" + parseInt(rfb_version,10) +
                   ".00" + ((rfb_version * 10) % 10);
        send_string("RFB " + cversion + "\n");
        updateState('Security', "Sent ProtocolVersion: " + sversion);
        break;

    case 'Security' :
        if (rfb_version >= 3.7) {
            num_types = rQ[rQi++];
            if (rQlen() < num_types) {
                rQi--;
                Util.Debug("   waiting for security types");
                return;
            }
            if (num_types === 0) {
                strlen = rQshift32();
                reason = rQshiftStr(strlen);
                updateState('failed',
                        "Disconnected: security failure: " + reason);
                return;
            }
            rfb_auth_scheme = 0;
            types = rQshiftBytes(num_types);
            Util.Debug("Server security types: " + types);
            for (i=0; i < types.length; i+=1) {
                if ((types[i] > rfb_auth_scheme) && (types[i] < 3)) {
                    rfb_auth_scheme = types[i];
                }
            }
            if (rfb_auth_scheme === 0) {
                updateState('failed',
                        "Disconnected: unsupported security types: " + types);
                return;
            }
            
            send_array([rfb_auth_scheme]);
        } else {
            if (rQlen() < 4) {
                Util.Debug("   waiting for security scheme bytes");
                return;
            }
            rfb_auth_scheme = rQshift32();
        }
        updateState('Authentication',
                "Authenticating using scheme: " + rfb_auth_scheme);
        init_msg();  // Recursive fallthrough (workaround JSLint complaint)
        break;

    case 'Authentication' :
        //Util.Debug("Security auth scheme: " + rfb_auth_scheme);
        switch (rfb_auth_scheme) {
            case 0:  // connection failed
                if (rQlen() < 4) {
                    Util.Debug("   waiting for auth reason bytes");
                    return;
                }
                strlen = rQshift32();
                reason = rQshiftStr(strlen);
                updateState('failed',
                        "Disconnected: auth failure: " + reason);
                return;
            case 1:  // no authentication
                updateState('SecurityResult');
                break;
            case 2:  // VNC authentication
                if (rfb_password.length === 0) {
                    updateState('password', "Password Required");
                    return;
                }
                if (rQlen() < 16) {
                    Util.Debug("   waiting for auth challenge bytes");
                    return;
                }
                challenge = rQshiftBytes(16);
                //Util.Debug("Password: " + rfb_password);
                //Util.Debug("Challenge: " + challenge +
                //           " (" + challenge.length + ")");
                response = genDES(rfb_password, challenge);
                //Util.Debug("Response: " + response +
                //           " (" + response.length + ")");
                
                //Util.Debug("Sending DES encrypted auth response");
                send_array(response);
                updateState('SecurityResult');
                break;
            default:
                updateState('failed',
                        "Disconnected: unsupported auth scheme: " +
                        rfb_auth_scheme);
                return;
        }
        break;

    case 'SecurityResult' :
        if (rQlen() < 4) {
            updateState('failed', "Invalid VNC auth response");
            return;
        }
        switch (rQshift32()) {
            case 0:  // OK
                updateState('ServerInitialisation', "Authentication OK");
                break;
            case 1:  // failed
                if (rfb_version >= 3.8) {
                    reason_len = rQshift32();
                    if (rQlen() < reason_len) {
                        Util.Debug("   waiting for SecurityResult reason bytes");
                        rQi -= 8; // Unshift the status and length
                        return;
                    }
                    reason = rQshiftStr(reason_len);
                    updateState('failed', reason);
                } else {
                    updateState('failed', "Authentication failed");
                }
                return;
            case 2:  // too-many
                updateState('failed',
                        "Disconnected: too many auth attempts");
                return;
        }
        send_array([rfb_shared]); // ClientInitialisation
        break;

    case 'ServerInitialisation' :
        if (rQlen() < 24) {
            updateState('failed', "Invalid server initialisation");
            return;
        }

        /* Screen size */
        fb_width  = rQshift16();
        fb_height = rQshift16();

        /* PIXEL_FORMAT */
        bpp            = rQ[rQi++];
        depth          = rQ[rQi++];
        big_endian     = rQ[rQi++];
        true_color     = rQ[rQi++];

        Util.Info("Screen: " + fb_width + "x" + fb_height + 
                  ", bpp: " + bpp + ", depth: " + depth +
                  ", big_endian: " + big_endian +
                  ", true_color: " + true_color);

        /* Connection name/title */
        rQshiftStr(12);
        name_length   = rQshift32();
        fb_name = rQshiftStr(name_length);

        canvas.resize(fb_width, fb_height, conf.true_color);
        canvas.start(keyPress, mouseButton, mouseMove);

        if (conf.true_color) {
            fb_Bpp           = 4;
            fb_depth         = 3;
        } else {
            fb_Bpp           = 1;
            fb_depth         = 1;
        }

        response = pixelFormat();
        response = response.concat(clientEncodings());
        response = response.concat(fbUpdateRequest(0));
        timing.fbu_rt_start = (new Date()).getTime();
        send_array(response);
        
        /* Start pushing/polling */
        setTimeout(checkEvents, conf.check_rate);
        setTimeout(scan_tight_imgQ, scan_imgQ_rate);

        if (conf.encrypt) {
            updateState('normal', "Connected (encrypted) to: " + fb_name);
        } else {
            updateState('normal', "Connected (unencrypted) to: " + fb_name);
        }
        break;
    }
    //Util.Debug("<< init_msg");
};


/* Normal RFB/VNC server message handler */
normal_msg = function() {
    //Util.Debug(">> normal_msg");

    var ret = true, msg_type,
        c, first_colour, num_colours, red, green, blue;

    if (FBU.rects > 0) {
        msg_type = 0;
    } else if (cuttext !== 'none') {
        msg_type = 3;
    } else {
        msg_type = rQ[rQi++];
    }
    switch (msg_type) {
    case 0:  // FramebufferUpdate
        ret = framebufferUpdate(); // false means need more data
        break;
    case 1:  // SetColourMapEntries
        Util.Debug("SetColourMapEntries");
        rQi++;  // Padding
        first_colour = rQshift16(); // First colour
        num_colours = rQshift16();
        for (c=0; c < num_colours; c+=1) { 
            red = rQshift16();
            //Util.Debug("red before: " + red);
            red = parseInt(red / 256, 10);
            //Util.Debug("red after: " + red);
            green = parseInt(rQshift16() / 256, 10);
            blue = parseInt(rQshift16() / 256, 10);
            canvas.set_colourMap([red, green, blue], first_colour + c);
        }
        Util.Info("Registered " + num_colours + " colourMap entries");
        //Util.Debug("colourMap: " + canvas.get_colourMap());
        break;
    case 2:  // Bell
        Util.Warn("Bell (unsupported)");
        break;
    case 3:  // ServerCutText
        Util.Debug("ServerCutText");
        Util.Debug("rQ:" + rQ.slice(0,20));
        if (cuttext === 'none') {
            cuttext = 'header';
        }
        if (cuttext === 'header') {
            if (rQlen() < 7) {
                //Util.Debug("waiting for ServerCutText header");
                return false;
            }
            rQshiftBytes(3);  // Padding
            cuttext_length = rQshift32();
        }
        cuttext = 'bytes';
        if (rQlen() < cuttext_length) {
            //Util.Debug("waiting for ServerCutText bytes");
            return false;
        }
        conf.clipboardReceive(that, rQshiftStr(cuttext_length));
        cuttext = 'none';
        break;
    default:
        updateState('failed',
                "Disconnected: illegal server message type " + msg_type);
        Util.Debug("rQ.slice(0,30):" + rQ.slice(0,30));
        break;
    }
    //Util.Debug("<< normal_msg");
    return ret;
};

framebufferUpdate = function() {
    var now, hdr, fbu_rt_diff, last_bytes, last_rects, ret = true;

    if (FBU.rects === 0) {
        //Util.Debug("New FBU: rQ.slice(0,20): " + rQ.slice(0,20));
        if (rQlen() < 3) {
            if (rQi === 0) {
                rQ.unshift(0);  // FBU msg_type
            } else {
                rQi -= 1;
            }
            //Util.Debug("   waiting for FBU header bytes");
            return false;
        }
        rQi++;
        FBU.rects = rQshift16();
        //Util.Debug("FramebufferUpdate, rects:" + FBU.rects);
        FBU.bytes = 0;
        timing.cur_fbu = 0;
        if (timing.fbu_rt_start > 0) {
            now = (new Date()).getTime();
            Util.Info("First FBU latency: " + (now - timing.fbu_rt_start));
        }
    }

    while (FBU.rects > 0) {
        if (rfb_state !== "normal") {
            return false;
        }
        if (rQlen() < FBU.bytes) {
            //Util.Debug("   waiting for " + (FBU.bytes - rQlen()) + " FBU bytes");
            return false;
        }
        if (FBU.bytes === 0) {
            if (rQlen() < 12) {
                //Util.Debug("   waiting for rect header bytes");
                return false;
            }
            /* New FramebufferUpdate */

            hdr = rQshiftBytes(12);
            FBU.x      = (hdr[0] << 8) + hdr[1];
            FBU.y      = (hdr[2] << 8) + hdr[3];
            FBU.width  = (hdr[4] << 8) + hdr[5];
            FBU.height = (hdr[6] << 8) + hdr[7];
            FBU.encoding = parseInt((hdr[8] << 24) + (hdr[9] << 16) +
                                    (hdr[10] << 8) +  hdr[11], 10);

            if (encNames[FBU.encoding]) {
                // Debug:
                /*
                var msg =  "FramebufferUpdate rects:" + FBU.rects;
                msg += " x: " + FBU.x + " y: " + FBU.y;
                msg += " width: " + FBU.width + " height: " + FBU.height;
                msg += " encoding:" + FBU.encoding;
                msg += "(" + encNames[FBU.encoding] + ")";
                msg += ", rQlen(): " + rQlen();
                Util.Debug(msg);
                */
            } else {
                updateState('failed',
                        "Disconnected: unsupported encoding " +
                        FBU.encoding);
                return false;
            }
        }

        timing.last_fbu = (new Date()).getTime();
        last_bytes = rQlen();
        last_rects = FBU.rects;

        // false ret means need more data
        ret = encHandlers[FBU.encoding]();

        now = (new Date()).getTime();
        timing.cur_fbu += (now - timing.last_fbu);

        if (FBU.rects === 0) {
            if (((FBU.width === fb_width) &&
                        (FBU.height === fb_height)) ||
                    (timing.fbu_rt_start > 0)) {
                timing.full_fbu_total += timing.cur_fbu;
                timing.full_fbu_cnt += 1;
                Util.Info("Timing of full FBU, cur: " +
                          timing.cur_fbu + ", total: " +
                          timing.full_fbu_total + ", cnt: " +
                          timing.full_fbu_cnt + ", avg: " +
                          (timing.full_fbu_total /
                              timing.full_fbu_cnt));
            }
            if (timing.fbu_rt_start > 0) {
                fbu_rt_diff = now - timing.fbu_rt_start;
                timing.fbu_rt_total += fbu_rt_diff;
                timing.fbu_rt_cnt += 1;
                Util.Info("full FBU round-trip, cur: " +
                          fbu_rt_diff + ", total: " +
                          timing.fbu_rt_total + ", cnt: " +
                          timing.fbu_rt_cnt + ", avg: " +
                          (timing.fbu_rt_total /
                              timing.fbu_rt_cnt));
                timing.fbu_rt_start = 0;
            }
        }
        if (! ret) {
            break; // false ret means need more data
        }
    }
    return ret;
};

//
// FramebufferUpdate encodings
//

encHandlers.RAW = function display_raw() {
    //Util.Debug(">> display_raw");

    var cur_y, cur_height; 

    if (FBU.lines === 0) {
        FBU.lines = FBU.height;
    }
    FBU.bytes = FBU.width * fb_Bpp; // At least a line
    if (rQlen() < FBU.bytes) {
        //Util.Debug("   waiting for " +
        //           (FBU.bytes - rQlen()) + " RAW bytes");
        return false;
    }
    cur_y = FBU.y + (FBU.height - FBU.lines);
    cur_height = Math.min(FBU.lines,
                          Math.floor(rQlen()/(FBU.width * fb_Bpp)));
    canvas.blitImage(FBU.x, cur_y, FBU.width, cur_height, rQ, rQi);
    rQshiftBytes(FBU.width * cur_height * fb_Bpp);
    FBU.lines -= cur_height;

    if (FBU.lines > 0) {
        FBU.bytes = FBU.width * fb_Bpp; // At least another line
    } else {
        FBU.rects -= 1;
        FBU.bytes = 0;
    }
    return true;
};

encHandlers.COPYRECT = function display_copy_rect() {
    //Util.Debug(">> display_copy_rect");

    var old_x, old_y;

    if (rQlen() < 4) {
        //Util.Debug("   waiting for " +
        //           (FBU.bytes - rQlen()) + " COPYRECT bytes");
        return false;
    }
    old_x = rQshift16();
    old_y = rQshift16();
    canvas.copyImage(old_x, old_y, FBU.x, FBU.y, FBU.width, FBU.height);
    FBU.rects -= 1;
    FBU.bytes = 0;
    return true;
};

encHandlers.RRE = function display_rre() {
    //Util.Debug(">> display_rre (" + rQlen() + " bytes)");
    var color, x, y, width, height, chunk;

    if (FBU.subrects === 0) {
        if (rQlen() < 4 + fb_Bpp) {
            //Util.Debug("   waiting for " +
            //           (4 + fb_Bpp - rQlen()) + " RRE bytes");
            return false;
        }
        FBU.subrects = rQshift32();
        color = rQshiftBytes(fb_Bpp); // Background
        canvas.fillRect(FBU.x, FBU.y, FBU.width, FBU.height, color);
    }
    while ((FBU.subrects > 0) && (rQlen() >= (fb_Bpp + 8))) {
        color = rQshiftBytes(fb_Bpp);
        x = rQshift16();
        y = rQshift16();
        width = rQshift16();
        height = rQshift16();
        canvas.fillRect(FBU.x + x, FBU.y + y, width, height, color);
        FBU.subrects -= 1;
    }
    //Util.Debug("   display_rre: rects: " + FBU.rects +
    //           ", FBU.subrects: " + FBU.subrects);

    if (FBU.subrects > 0) {
        chunk = Math.min(rre_chunk_sz, FBU.subrects);
        FBU.bytes = (fb_Bpp + 8) * chunk;
    } else {
        FBU.rects -= 1;
        FBU.bytes = 0;
    }
    //Util.Debug("<< display_rre, FBU.bytes: " + FBU.bytes);
    return true;
};

encHandlers.HEXTILE = function display_hextile() {
    //Util.Debug(">> display_hextile");
    var subencoding, subrects, tile, color, cur_tile,
        tile_x, x, w, tile_y, y, h, xy, s, sx, sy, wh, sw, sh;

    if (FBU.tiles === 0) {
        FBU.tiles_x = Math.ceil(FBU.width/16);
        FBU.tiles_y = Math.ceil(FBU.height/16);
        FBU.total_tiles = FBU.tiles_x * FBU.tiles_y;
        FBU.tiles = FBU.total_tiles;
    }

    /* FBU.bytes comes in as 1, rQlen() at least 1 */
    while (FBU.tiles > 0) {
        FBU.bytes = 1;
        if (rQlen() < FBU.bytes) {
            //Util.Debug("   waiting for HEXTILE subencoding byte");
            return false;
        }
        //Util.Debug("   2 rQ length: " + rQlen() + " rQ[rQi]: " + rQ[rQi] + " rQ.slice(rQi,rQi+20): " + rQ.slice(rQi,rQi+20) + ", FBU.rects: " + FBU.rects + ", FBU.tiles: " + FBU.tiles);
        subencoding = rQ[rQi];  // Peek
        if (subencoding > 30) { // Raw
            updateState('failed',
                    "Disconnected: illegal hextile subencoding " + subencoding);
            //Util.Debug("rQ.slice(0,30):" + rQ.slice(0,30));
            return false;
        }
        subrects = 0;
        cur_tile = FBU.total_tiles - FBU.tiles;
        tile_x = cur_tile % FBU.tiles_x;
        tile_y = Math.floor(cur_tile / FBU.tiles_x);
        x = FBU.x + tile_x * 16;
        y = FBU.y + tile_y * 16;
        w = Math.min(16, (FBU.x + FBU.width) - x);
        h = Math.min(16, (FBU.y + FBU.height) - y);

        /* Figure out how much we are expecting */
        if (subencoding & 0x01) { // Raw
            //Util.Debug("   Raw subencoding");
            FBU.bytes += w * h * fb_Bpp;
        } else {
            if (subencoding & 0x02) { // Background
                FBU.bytes += fb_Bpp;
            }
            if (subencoding & 0x04) { // Foreground
                FBU.bytes += fb_Bpp;
            }
            if (subencoding & 0x08) { // AnySubrects
                FBU.bytes += 1;   // Since we aren't shifting it off
                if (rQlen() < FBU.bytes) {
                    /* Wait for subrects byte */
                    //Util.Debug("   waiting for hextile subrects header byte");
                    return false;
                }
                subrects = rQ[rQi + FBU.bytes-1]; // Peek
                if (subencoding & 0x10) { // SubrectsColoured
                    FBU.bytes += subrects * (fb_Bpp + 2);
                } else {
                    FBU.bytes += subrects * 2;
                }
            }
        }

        /*
        Util.Debug("   tile:" + cur_tile + "/" + (FBU.total_tiles - 1) +
              " (" + tile_x + "," + tile_y + ")" +
              " [" + x + "," + y + "]@" + w + "x" + h +
              ", subenc:" + subencoding +
              "(last: " + FBU.lastsubencoding + "), subrects:" +
              subrects +
              ", rQlen():" + rQlen() + ", FBU.bytes:" + FBU.bytes +
              " last:" + rQ.slice(FBU.bytes-10, FBU.bytes) +
              " next:" + rQ.slice(FBU.bytes-1, FBU.bytes+10));
        */
        if (rQlen() < FBU.bytes) {
            //Util.Debug("   waiting for " +
            //           (FBU.bytes - rQlen()) + " hextile bytes");
            return false;
        }

        /* We know the encoding and have a whole tile */
        FBU.subencoding = rQ[rQi];
        rQi += 1;
        if (FBU.subencoding === 0) {
            if (FBU.lastsubencoding & 0x01) {
                /* Weird: ignore blanks after RAW */
                Util.Debug("     Ignoring blank after RAW");
            } else {
                canvas.fillRect(x, y, w, h, FBU.background);
            }
        } else if (FBU.subencoding & 0x01) { // Raw
            canvas.blitImage(x, y, w, h, rQ, rQi);
            rQi += FBU.bytes - 1;
        } else {
            if (FBU.subencoding & 0x02) { // Background
                FBU.background = rQ.slice(rQi, rQi + fb_Bpp);
                rQi += fb_Bpp;
            }
            if (FBU.subencoding & 0x04) { // Foreground
                FBU.foreground = rQ.slice(rQi, rQi + fb_Bpp);
                rQi += fb_Bpp;
            }

            tile = canvas.getTile(x, y, w, h, FBU.background);
            if (FBU.subencoding & 0x08) { // AnySubrects
                subrects = rQ[rQi];
                rQi += 1;
                for (s = 0; s < subrects; s += 1) {
                    if (FBU.subencoding & 0x10) { // SubrectsColoured
                        color = rQ.slice(rQi, rQi + fb_Bpp);
                        rQi += fb_Bpp;
                    } else {
                        color = FBU.foreground;
                    }
                    xy = rQ[rQi];
                    rQi += 1;
                    sx = (xy >> 4);
                    sy = (xy & 0x0f);

                    wh = rQ[rQi];
                    rQi += 1;
                    sw = (wh >> 4)   + 1;
                    sh = (wh & 0x0f) + 1;

                    canvas.setSubTile(tile, sx, sy, sw, sh, color);
                }
            }
            canvas.putTile(tile);
        }
        //rQshiftBytes(FBU.bytes);
        FBU.lastsubencoding = FBU.subencoding;
        FBU.bytes = 0;
        FBU.tiles -= 1;
    }

    if (FBU.tiles === 0) {
        FBU.rects -= 1;
    }

    //Util.Debug("<< display_hextile");
    return true;
};


encHandlers.TIGHT_PNG = function display_tight_png() {
    //Util.Debug(">> display_tight_png");
    var ctl, cmode, clength, getCLength, color, img;
    //Util.Debug("   FBU.rects: " + FBU.rects);
    //Util.Debug("   starting rQ.slice(rQi,rQi+20): " + rQ.slice(rQi,rQi+20) + " (" + rQlen() + ")");

    FBU.bytes = 1; // compression-control byte
    if (rQlen() < FBU.bytes) {
        Util.Debug("   waiting for TIGHT compression-control byte");
        return false;
    }

    // Get 'compact length' header and data size
    getCLength = function (arr, offset) {
        var header = 1, data = 0;
        data += arr[offset + 0] & 0x7f;
        if (arr[offset + 0] & 0x80) {
            header += 1;
            data += (arr[offset + 1] & 0x7f) << 7;
            if (arr[offset + 1] & 0x80) {
                header += 1;
                data += arr[offset + 2] << 14;
            }
        }
        return [header, data];
    };

    ctl = rQ[rQi];
    switch (ctl >> 4) {
        case 0x08: cmode = "fill"; break;
        case 0x09: cmode = "jpeg"; break;
        case 0x0A: cmode = "png";  break;
        default:   throw("Illegal basic compression received, ctl: " + ctl);
    }
    switch (cmode) {
        // fill uses fb_depth because TPIXELs drop the padding byte
        case "fill": FBU.bytes += fb_depth; break; // TPIXEL
        case "jpeg": FBU.bytes += 3;            break; // max clength
        case "png":  FBU.bytes += 3;            break; // max clength
    }

    if (rQlen() < FBU.bytes) {
        Util.Debug("   waiting for TIGHT " + cmode + " bytes");
        return false;
    }

    //Util.Debug("   rQ.slice(0,20): " + rQ.slice(0,20) + " (" + rQlen() + ")");
    //Util.Debug("   cmode: " + cmode);

    // Determine FBU.bytes
    switch (cmode) {
    case "fill":
        rQi++; // shift off ctl
        color = rQshiftBytes(fb_depth);
        canvas.fillRect(FBU.x, FBU.y, FBU.width, FBU.height, color);
        break;
    case "jpeg":
    case "png":
        clength = getCLength(rQ, rQi+1);
        FBU.bytes = 1 + clength[0] + clength[1]; // ctl + clength size + jpeg-data
        if (rQlen() < FBU.bytes) {
            Util.Debug("   waiting for TIGHT " + cmode + " bytes");
            return false;
        }

        // We have everything, render it
        //Util.Debug("   png, rQlen(): " + rQlen() + ", clength[0]: " + clength[0] + ", clength[1]: " + clength[1]);
        rQshiftBytes(1 + clength[0]); // shift off ctl + compact length
        img = new Image();
        img.onload = scan_tight_imgQ;
        FBU.imgQ.push([img, FBU.x, FBU.y]);
        img.src = "data:image/" + cmode +
            extract_data_uri(rQshiftBytes(clength[1]));
        img = null;
        break;
    }
    FBU.bytes = 0;
    FBU.rects -= 1;
    //Util.Debug("   ending rQ.slice(rQi,rQi+20): " + rQ.slice(rQi,rQi+20) + " (" + rQlen() + ")");
    //Util.Debug("<< display_tight_png");
    return true;
};

extract_data_uri = function(arr) {
    //var i, stra = [];
    //for (i=0; i< arr.length; i += 1) {
    //    stra.push(String.fromCharCode(arr[i]));
    //}
    //return "," + escape(stra.join(''));
    return ";base64," + Base64.encode(arr);
};

scan_tight_imgQ = function() {
    var img, imgQ, ctx;
    ctx = canvas.getContext();
    if (rfb_state === 'normal') {
        imgQ = FBU.imgQ;
        while ((imgQ.length > 0) && (imgQ[0][0].complete)) {
            img = imgQ.shift();
            ctx.drawImage(img[0], img[1], img[2]);
        }
        setTimeout(scan_tight_imgQ, scan_imgQ_rate);
    }
};

encHandlers.DesktopSize = function set_desktopsize() {
    Util.Debug(">> set_desktopsize");
    fb_width = FBU.width;
    fb_height = FBU.height;
    canvas.clear();
    canvas.resize(fb_width, fb_height);
    timing.fbu_rt_start = (new Date()).getTime();
    // Send a new non-incremental request
    send_array(fbUpdateRequest(0));

    FBU.bytes = 0;
    FBU.rects -= 1;

    Util.Debug("<< set_desktopsize");
    return true;
};

encHandlers.Cursor = function set_cursor() {
    var x, y, w, h, pixelslength, masklength;
    //Util.Debug(">> set_cursor");
    x = FBU.x;  // hotspot-x
    y = FBU.y;  // hotspot-y
    w = FBU.width;
    h = FBU.height;

    pixelslength = w * h * fb_Bpp;
    masklength = Math.floor((w + 7) / 8) * h;

    if (rQlen() < (pixelslength + masklength)) {
        //Util.Debug("waiting for cursor encoding bytes");
        FBU.bytes = pixelslength + masklength;
        return false;
    }

    //Util.Debug("   set_cursor, x: " + x + ", y: " + y + ", w: " + w + ", h: " + h);

    canvas.changeCursor(rQshiftBytes(pixelslength),
                            rQshiftBytes(masklength),
                            x, y, w, h);

    FBU.bytes = 0;
    FBU.rects -= 1;

    //Util.Debug("<< set_cursor");
    return true;
};

encHandlers.JPEG_quality_lo = function set_jpeg_quality() {
    Util.Error("Server sent jpeg_quality pseudo-encoding");
};

encHandlers.compress_lo = function set_compress_level() {
    Util.Error("Server sent compress level pseudo-encoding");
};

/*
 * Client message routines
 */

pixelFormat = function() {
    //Util.Debug(">> pixelFormat");
    var arr;
    arr = [0];     // msg-type
    arr.push8(0);  // padding
    arr.push8(0);  // padding
    arr.push8(0);  // padding

    arr.push8(fb_Bpp * 8); // bits-per-pixel
    arr.push8(fb_depth * 8); // depth
    arr.push8(0);  // little-endian
    arr.push8(conf.true_color ? 1 : 0);  // true-color

    arr.push16(255);  // red-max
    arr.push16(255);  // green-max
    arr.push16(255);  // blue-max
    arr.push8(0);     // red-shift
    arr.push8(8);     // green-shift
    arr.push8(16);    // blue-shift

    arr.push8(0);     // padding
    arr.push8(0);     // padding
    arr.push8(0);     // padding
    //Util.Debug("<< pixelFormat");
    return arr;
};

clientEncodings = function() {
    //Util.Debug(">> clientEncodings");
    var arr, i, encList = [];

    for (i=0; i<encodings.length; i += 1) {
        if ((encodings[i][0] === "Cursor") &&
            (! conf.local_cursor)) {
            Util.Debug("Skipping Cursor pseudo-encoding");
        } else {
            //Util.Debug("Adding encoding: " + encodings[i][0]);
            encList.push(encodings[i][1]);
        }
    }

    arr = [2];     // msg-type
    arr.push8(0);  // padding

    arr.push16(encList.length); // encoding count
    for (i=0; i < encList.length; i += 1) {
        arr.push32(encList[i]);
    }
    //Util.Debug("<< clientEncodings: " + arr);
    return arr;
};

fbUpdateRequest = function(incremental, x, y, xw, yw) {
    //Util.Debug(">> fbUpdateRequest");
    if (!x) { x = 0; }
    if (!y) { y = 0; }
    if (!xw) { xw = fb_width; }
    if (!yw) { yw = fb_height; }
    var arr;
    arr = [3];  // msg-type
    arr.push8(incremental);
    arr.push16(x);
    arr.push16(y);
    arr.push16(xw);
    arr.push16(yw);
    //Util.Debug("<< fbUpdateRequest");
    return arr;
};

keyEvent = function(keysym, down) {
    //Util.Debug(">> keyEvent, keysym: " + keysym + ", down: " + down);
    var arr;
    arr = [4];  // msg-type
    arr.push8(down);
    arr.push16(0);
    arr.push32(keysym);
    //Util.Debug("<< keyEvent");
    return arr;
};

pointerEvent = function(x, y) {
    //Util.Debug(">> pointerEvent, x,y: " + x + "," + y +
    //           " , mask: " + mouse_buttonMask);
    var arr;
    arr = [5];  // msg-type
    arr.push8(mouse_buttonMask);
    arr.push16(x);
    arr.push16(y);
    //Util.Debug("<< pointerEvent");
    return arr;
};

clientCutText = function(text) {
    //Util.Debug(">> clientCutText");
    var arr, i, n;
    arr = [6];     // msg-type
    arr.push8(0);  // padding
    arr.push8(0);  // padding
    arr.push8(0);  // padding
    arr.push32(text.length);
    n = text.length;
    for (i=0; i < n; i+=1) {
        arr.push(text.charCodeAt(i));
    }
    //Util.Debug("<< clientCutText:" + arr);
    return arr;
};



//
// Public API interface functions
//

that.connect = function(host, port, password) {
    //Util.Debug(">> connect");

    rfb_host       = host;
    rfb_port       = port;
    rfb_password   = (password !== undefined)   ? password : "";

    if ((!rfb_host) || (!rfb_port)) {
        updateState('failed', "Must set host and port");
        return;
    }

    updateState('connect');
    //Util.Debug("<< connect");

};

that.disconnect = function() {
    //Util.Debug(">> disconnect");
    updateState('disconnect', 'Disconnecting');
    //Util.Debug("<< disconnect");
};

that.force_disconnect = function() {
    //Util.Debug(">> disconnect");
    updateState('disconnected', 'Disconnected');
    //Util.Debug("<< disconnect");
};

that.sendPassword = function(passwd) {
    rfb_password = passwd;
    rfb_state = "Authentication";
    setTimeout(init_msg, 1);
};

that.sendCtrlAltDel = function() {
    if (rfb_state !== "normal") { return false; }
    Util.Info("Sending Ctrl-Alt-Del");
    var arr = [];
    arr = arr.concat(keyEvent(0xFFE3, 1)); // Control
    arr = arr.concat(keyEvent(0xFFE9, 1)); // Alt
    arr = arr.concat(keyEvent(0xFFFF, 1)); // Delete
    arr = arr.concat(keyEvent(0xFFFF, 0)); // Delete
    arr = arr.concat(keyEvent(0xFFE9, 0)); // Alt
    arr = arr.concat(keyEvent(0xFFE3, 0)); // Control
    arr = arr.concat(fbUpdateRequest(1));
    send_array(arr);
};

// Send a key press. If 'down' is not specified then send a down key
// followed by an up key.
that.sendKey = function(code, down) {
    if (rfb_state !== "normal") { return false; }
    var arr = [];
    if (typeof down !== 'undefined') {
        Util.Info("Sending key code (" + (down ? "down" : "up") + "): " + code);
        arr = arr.concat(keyEvent(code, down ? 1 : 0));
    } else {
        Util.Info("Sending key code (down + up): " + code);
        arr = arr.concat(keyEvent(code, 1));
        arr = arr.concat(keyEvent(code, 0));
    }
    arr = arr.concat(fbUpdateRequest(1));
    send_array(arr);
};

that.clipboardPasteFrom = function(text) {
    if (rfb_state !== "normal") { return; }
    //Util.Debug(">> clipboardPasteFrom: " + text.substr(0,40) + "...");
    send_array(clientCutText(text));
    //Util.Debug("<< clipboardPasteFrom");
};

that.testMode = function(override_send_array) {
    // Overridable internal functions for testing
    test_mode = true;
    send_array = override_send_array;
    that.recv_message = recv_message;  // Expose it

    checkEvents = function () { /* Stub Out */ };
    that.connect = function(host, port, password) {
            rfb_host = host;
            rfb_port = port;
            rfb_password = password;
            updateState('ProtocolVersion', "Starting VNC handshake");
        };
};


return constructor();  // Return the public API interface

}  // End of RFB()
