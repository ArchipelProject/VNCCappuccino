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

noVNC_logo      = nil;
INCLUDE_URI     = "/Frameworks/VNCCappuccino/Resources/";

Websock_native   = YES;

@import "Resources/util.js";
@import "Resources/input.js";
@import "Resources/base64.js";
@import "Resources/des.js";
@import "Resources/display.js";
@import "Resources/websock.js"
@import "Resources/rfb.js";

Util.init_logging("none");


@import "TNVNCView.j";

/*! @mainpage
    VNCCappuccino is distributed under the @ref license "AGPL".

    @htmlonly <pre>@endhtmlonly
    @htmlinclude README
    @htmlonly </pre>@endhtmlonly

    @page license License
    @htmlonly <pre>@endhtmlonly
    @htmlinclude LICENSE
    @htmlonly </pre>@endhtmlonly

    @defgroup vnccappuccino VNCCappuccino
*/
